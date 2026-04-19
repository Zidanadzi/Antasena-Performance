/* 
 * ANTASENA PERFORMANCE - V12 RADIANT CONNECT
 * Strategi: Non-Blocking Serial + Lockdown 70% + Divider 5.83
 * Hasil: Koneksi Instans, RPM 1500 Stabil, No Lag.
 * Perbaikan: Menghapus delay readStringUntil yang membuat aplikasi seolah "macet".
 */

#include <SoftwareSerial.h>
#include <EEPROM.h>

#define PIN_SENSOR_QS 2  
#define PIN_PULSER    3  
#define BT_RX         8   
#define BT_TX         9   
#define PIN_KILL_OUT  10 

SoftwareSerial bt(BT_RX, BT_TX);

// Forward Declarations
void handleSync(char* data);
void loadSettings();
void rpmISR();

struct UserSettings {
  int minRpmActive;
  float rpmCalibration;
  float rpmDivider;
  int tableRpm[4];
  int tableKill[4];
  unsigned long magic;
};

UserSettings config;
const unsigned long EEPROM_MAGIC = 0xABCD1234;

// Buffer penampung 9 data waktu (micros)
volatile unsigned long lastPulseTime = 0;
volatile unsigned long lockoutTime = 0; 
volatile unsigned long intervalBuffer[9] = {0,0,0,0,0,0,0,0,0};
volatile int intIdx = 0;

float filteredRpm = 0;
unsigned long lastSend = 0;
bool lastSensorState = HIGH;

// Penampung Bluetooth Non-Blocking (Pencegah Hang)
char serialBuf[128];
int serialPos = 0;

// --- ISR: STRICT LOCKOUT 70% (Menghancurkan Pulse Doubling) ---
void rpmISR() {
  unsigned long now = micros();
  // Filter Fisik: Lewati jika dalam masa lockout agresif (70% durasi sebelumnya)
  if (now > lockoutTime) {
    unsigned long interval = now - lastPulseTime;
    
    // Safety Debounce (350us)
    if (interval > 350) { 
      intervalBuffer[intIdx] = interval;
      intIdx = (intIdx + 1) % 9;
      lastPulseTime = now;
      
      // Lockout 70%
      lockoutTime = now + (interval * 0.70); 
    }
  }
}

void loadSettings() {
  EEPROM.get(0, config);
  config.rpmDivider = 5.83; // KEMBALI KE 5.83 Agar RPM Dashboard 1500 Kembali Akurat
  if (config.magic != EEPROM_MAGIC) {
    config.minRpmActive = 3000;
    config.rpmCalibration = 1.0;
    config.tableRpm[0]=3000; config.tableRpm[1]=6000;
    config.tableRpm[2]=9000; config.tableRpm[3]=12000;
    config.tableKill[0]=80; config.tableKill[1]=70; 
    config.tableKill[2]=60; config.tableKill[3]=55;
    config.magic = EEPROM_MAGIC;
    EEPROM.put(0, config);
  }
}

void setup() {
  loadSettings();
  pinMode(PIN_PULSER, INPUT_PULLUP);
  pinMode(PIN_SENSOR_QS, INPUT_PULLUP);
  pinMode(PIN_KILL_OUT, OUTPUT);
  digitalWrite(PIN_KILL_OUT, LOW);
  bt.begin(38400); 
  attachInterrupt(digitalPinToInterrupt(PIN_PULSER), rpmISR, FALLING);
}

void loop() {
  unsigned long now = micros();
  unsigned long snapIntervals[9];
  unsigned long snapLast;

  // Mirroring data dari ISR secara aman
  noInterrupts();
  for(int i=0; i<9; i++) snapIntervals[i] = intervalBuffer[i];
  snapLast = lastPulseTime;
  interrupts();

  float currentRpm = 0;

  // Timeout jika mesin berhenti
  if (now - snapLast > 450000) {
      currentRpm = 0;
      noInterrupts();
      for(int i=0; i<9; i++) intervalBuffer[i] = 0;
      interrupts();
  } else {
      // --- SUPREME MEDIAN FILTERING ---
      unsigned long sorted[9];
      int count = 0;
      for(int i=0; i<9; i++) {
          if(snapIntervals[i] > 0) sorted[count++] = snapIntervals[i];
      }

      if (count >= 5) {
          for(int i=0; i<count-1; i++) {
              for(int j=i+1; j<count; j++) {
                  if(sorted[i] > sorted[j]) {
                      unsigned long t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t;
                  }
              }
          }
          unsigned long medianInterval = sorted[count / 2];
          if (medianInterval > 0) {
              // 10291595.0 = (60,000,000 / 5.83)
              currentRpm = 10291595.0 / (float)medianInterval; 
          }
      }
  }

  // --- FINAL SMOOTHING (HYSTERESIS) ---
  if (currentRpm > 100) {
      if (filteredRpm < 100) filteredRpm = currentRpm;
      else {
          float sFactor = (filteredRpm < 3200) ? 0.94 : 0.40;
          filteredRpm = (filteredRpm * sFactor) + (currentRpm * (1.0 - sFactor));
      }
  } else {
      filteredRpm = 0;
  }

  // Quick Shifter Sensor
  bool sensorOn = (digitalRead(PIN_SENSOR_QS) == LOW);
  if (sensorOn && !lastSensorState) {
      if ((int)filteredRpm >= config.minRpmActive) {
          int kTime = config.tableKill[0];
          int r = (int)filteredRpm;
          if (r >= config.tableRpm[3])      kTime = config.tableKill[3];
          else if (r >= config.tableRpm[2]) kTime = config.tableKill[2];
          else if (r >= config.tableRpm[1]) kTime = config.tableKill[1];
          
          digitalWrite(PIN_KILL_OUT, HIGH);
          delay(kTime);
          digitalWrite(PIN_KILL_OUT, LOW);
          bt.print("QS_EVENT:"); bt.println(kTime);
          delay(420); 
      }
  }
  lastSensorState = sensorOn;

  // Kirim data ke aplikasi (115ms)
  if (millis() - lastSend > 115) {
    lastSend = millis();
    bt.print("RPM:");
    bt.println((int)(filteredRpm * config.rpmCalibration));
  }

  // --- NON-BLOCKING SERIAL: Tidak membuat loop berhenti ---
  while (bt.available()) {
    char c = bt.read();
    if (c == '\n' || c == '\r') {
      serialBuf[serialPos] = '\0';
      if (serialPos > 0 && serialBuf[0] == 'S') handleSync(serialBuf);
      serialPos = 0;
    } else if (serialPos < 127) {
      serialBuf[serialPos++] = c;
    }
  }
}

void handleSync(char* data) {
  char* p = strtok(data+1, ",");
  int i = 0;
  while (p != NULL && i < 11) {
    if (i == 0)      config.minRpmActive = atoi(p);
    else if (i == 1) config.rpmCalibration = atof(p);
    else if (i == 3) config.tableRpm[0] = atoi(p);
    else if (i == 4) config.tableKill[0] = atoi(p);
    p = strtok(NULL, ","); i++;
  }
  config.rpmDivider = 5.83; 
  EEPROM.put(0, config);
  bt.println("OK:V12_CONNECT_READY");
}
