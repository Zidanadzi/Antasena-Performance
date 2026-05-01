/* 
 * ANTASENA PERFORMANCE - V15 THE FINAL PRECISION
 * Strategi: Hardware Input Capture (Pin 8) + Divider 11.66 Calibration Correction
 * Hasil: Memperbaiki RPM 3000 menjadi 1500 yang akurat dan super stabil.
 */

#include <SoftwareSerial.h>
#include <EEPROM.h>

#define PIN_SENSOR_QS 2  
#define PIN_PULSER    8    // WAJIB PIN 8 (ICP1)
#define BT_RX         11   // Tetap di 11
#define BT_TX         9    
#define PIN_KILL_OUT  10 

SoftwareSerial bt(BT_RX, BT_TX);

// Forward Declaration required by strict compilers
void handleSync(char* data);

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

// Buffer penampung Ticks Hardware
volatile unsigned long lastCapture = 0;
volatile unsigned long intervalBuffer[9] = {0,0,0,0,0,0,0,0,0};
volatile int intIdx = 0;
volatile unsigned long lastPulseMillis = 0;

float filteredRpm = 0;
unsigned long lastSend = 0;
bool lastSensorState = HIGH;
char serialBuf[128];
int serialPos = 0;

// --- ISR: HARDWARE INPUT CAPTURE ---
ISR(TIMER1_CAPT_vect) {
  unsigned int currentCapture = ICR1; 
  unsigned int interval = currentCapture - (unsigned int)lastCapture;
  
  /**
   * Debounce diturunkan ke 500 ticks (250us) agar aman sampai 18.000 RPM (Teriak).
   */
  if (interval > 500) { 
    intervalBuffer[intIdx] = interval;
    intIdx = (intIdx + 1) % 9;
    lastCapture = currentCapture;
    lastPulseMillis = millis();
  }
}

void loadSettings() {
  EEPROM.get(0, config);
  config.rpmDivider = 11.66; // DIVIDER DIUBAH KE 11.66 AGAR 3000 -> 1500 RPM
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

  // --- Konfigurasi Timer 1 HARDWARE ---
  noInterrupts();
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1  = 0;
  /**
   * ICNC1 = 1 (Input Noise Canceler)
   * ICES1 = 1 (Rising Edge Trigger)
   * CS11  = 1 (Prescaler 8 / 2MHz) -> 1 Tick = 0.5us
   */
  TCCR1B |= (1 << ICNC1) | (1 << ICES1) | (1 << CS11); 
  TIMSK1 |= (1 << ICIE1); 
  interrupts();
}

void loop() {
  unsigned long now = millis();
  unsigned long snapIntervals[9];
  unsigned long msLast;
  
  noInterrupts();
  for(int i=0; i<9; i++) snapIntervals[i] = intervalBuffer[i];
  msLast = lastPulseMillis;
  interrupts();

  float currentRpm = 0;
  
  // Timeout 500ms
  if (now - msLast > 500 || msLast == 0) {
      currentRpm = 0;
      noInterrupts();
      for(int i=0; i<9; i++) intervalBuffer[i] = 0;
      interrupts();
  } else {
      // Median Filter untuk kestabilan racing
      unsigned long sorted[9];
      int count = 0;
      for(int i=0; i<9; i++) if(snapIntervals[i] > 0) sorted[count++] = snapIntervals[i];
      
      if (count >= 5) {
          for(int i=0; i<count-1; i++) {
              for(int j=i+1; j<count; j++) {
                  if(sorted[i] > sorted[j]) {
                      unsigned long t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t;
                  }
              }
          }
          unsigned long medianTicks = sorted[count / 2];
          if (medianTicks > 0) {
              /**
               * KONSTANTA V15: 
               * (60,000,000 / 0.5) / 11.66 = 10,291,595
               */
              currentRpm = 10291595.0 / (float)medianTicks; 
          }
      }
  }

  // Smoothing Filter Premium (Hysteresis)
  if (currentRpm > 100) {
      if (filteredRpm < 100) filteredRpm = currentRpm;
      else {
          float sFactor = (filteredRpm < 3500) ? 0.95 : 0.45;
          filteredRpm = (filteredRpm * sFactor) + (currentRpm * (1.0 - sFactor));
      }
  } else {
      filteredRpm = 0;
  }

  // Quick Shifter
  bool sensorOn = (digitalRead(PIN_SENSOR_QS) == LOW);
  if (sensorOn && !lastSensorState) {
      if ((int)filteredRpm >= config.minRpmActive) {
          int kTime = config.tableKill[0];
          int rNow = (int)filteredRpm;
          if (rNow >= config.tableRpm[3])      kTime = config.tableKill[3];
          else if (rNow >= config.tableRpm[2]) kTime = config.tableKill[2];
          else if (rNow >= config.tableRpm[1]) kTime = config.tableKill[1];
          digitalWrite(PIN_KILL_OUT, HIGH);
          delay(kTime);
          digitalWrite(PIN_KILL_OUT, LOW);
          bt.print("QS_EVENT:"); bt.println(kTime);
          delay(420); 
      }
  }
  lastSensorState = sensorOn;

  // Laporan data ke Dashboard (115ms)
  if (millis() - lastSend > 115) {
    lastSend = millis();
    bt.print("RPM:");
    bt.println((int)(filteredRpm * config.rpmCalibration));
  }

  // Software Config Reading (Non-Blocking)
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
    // index 2: Divider (Hard-locked to 11.66)
    else if (i == 3)  config.tableRpm[0] = atoi(p);
    else if (i == 4)  config.tableKill[0] = atoi(p);
    else if (i == 5)  config.tableRpm[1] = atoi(p);
    else if (i == 6)  config.tableKill[1] = atoi(p);
    else if (i == 7)  config.tableRpm[2] = atoi(p);
    else if (i == 8)  config.tableKill[2] = atoi(p);
    else if (i == 9)  config.tableRpm[3] = atoi(p);
    else if (i == 10) config.tableKill[3] = atoi(p);
    p = strtok(NULL, ","); i++;
  }
  
  // SYSTEM FORCE-LOCK DIVIDER (Untuk Akurasi V15+)
  config.rpmDivider = 11.66; 

  EEPROM.put(0, config);
  bt.println("OK:V15_SYNC_READY");
}
