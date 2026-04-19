/* 
 * ANTASENA PERFORMANCE - ULTRA STABLE VERSION
 * Fitur: Bi-Directional Glitch Filter (Anti-Drop & Anti-Spike)
 * Racing Kill Time: 70, 65, 60, 55 ms
 * Baud Rate: 38400 | Divider: 11.66
 */

#include <SoftwareSerial.h>
#include <EEPROM.h>

#define PIN_SENSOR_QS 2  
#define PIN_PULSER    3  
#define BT_RX         8   
#define BT_TX         9   
#define PIN_KILL_OUT  10 

SoftwareSerial bt(BT_RX, BT_TX);

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

volatile unsigned long pulseInterval = 0;
volatile unsigned long lastPulseTime = 0;
float filteredRpm = 0;
unsigned long lastSend = 0;
bool lastSensorState = HIGH;

void rpmISR() {
  unsigned long now = micros();
  unsigned long interval = now - lastPulseTime;
  if (interval > 368) { 
    pulseInterval = interval;
    lastPulseTime = now;
  }
}

void loadSettings() {
  EEPROM.get(0, config);
  if (config.magic != EEPROM_MAGIC) {
    config.minRpmActive = 3000;
    config.rpmCalibration = 1.0;
    config.rpmDivider = 11.66; 
    config.tableRpm[0]=3000; config.tableRpm[1]=6000;
    config.tableRpm[2]=9000; config.tableRpm[3]=12000;
    config.tableKill[0]=70; config.tableKill[1]=65; 
    config.tableKill[2]=60; config.tableKill[3]=55;
    config.magic = EEPROM_MAGIC;
    EEPROM.put(0, config);
  }
}

void handleSync(String data) {
  data.remove(0, 1);
  char str[128];
  data.toCharArray(str, 128);
  int i = 0;
  char* p = strtok(str, ",");
  while (p != NULL && i < 11) {
    if (i == 0)      config.minRpmActive   = atoi(p);
    else if (i == 1) config.rpmCalibration = atof(p);
    else if (i == 2) config.rpmDivider     = atof(p);
    else if (i == 3) config.tableRpm[0]    = atoi(p);
    else if (i == 4) config.tableKill[0]   = atoi(p);
    else if (i == 5) config.tableRpm[1]    = atoi(p);
    else if (i == 6) config.tableKill[1]   = atoi(p);
    else if (i == 7) config.tableRpm[2]    = atoi(p);
    else if (i == 8) config.tableKill[2]   = atoi(p);
    else if (i == 9) config.tableRpm[3]    = atoi(p);
    else if (i == 10) config.tableKill[3]   = atoi(p);
    p = strtok(NULL, ",");
    i++;
  }
  if (config.rpmDivider <= 0) config.rpmDivider = 11.66;
  EEPROM.put(0, config);
  bt.println("OK:SYNCED_MODULE");
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
  noInterrupts();
  unsigned long snapInt = pulseInterval;
  unsigned long snapLast = lastPulseTime;
  interrupts();

  float rawRpm = 0;
  if (now - snapLast > 450000) {
      rawRpm = 0;
  } else if (snapInt > 0) {
    rawRpm = (60000000.0 / snapInt) / config.rpmDivider;
  }

  // --- ULTRA STABLE FILTER (Bi-Directional) ---
  if (rawRpm > 0) {
      if (filteredRpm > 500) {
          // 1. Abaikan anjlok > 40% (Missing Tooth)
          if (rawRpm < (filteredRpm * 0.6)) {
              rawRpm = filteredRpm;
          }
          // 2. Abaikan lonjakan > 50% (Ignition Noise)
          else if (rawRpm > (filteredRpm * 1.5)) {
              rawRpm = filteredRpm;
          }
      }
      // Smoothing Arduino (Faktor 0.8)
      filteredRpm = (filteredRpm * 0.8) + (rawRpm * 0.2); 
  } else {
      filteredRpm = 0; 
  }

  bool currentState = digitalRead(PIN_SENSOR_QS);
  if (currentState == LOW && lastSensorState == HIGH) {
      if ((int)filteredRpm >= config.minRpmActive) {
          int kTime = config.tableKill[0];
          if ((int)filteredRpm >= config.tableRpm[3])      kTime = config.tableKill[3];
          else if ((int)filteredRpm >= config.tableRpm[2]) kTime = config.tableKill[2];
          else if ((int)filteredRpm >= config.tableRpm[1]) kTime = config.tableKill[1];
          
          digitalWrite(PIN_KILL_OUT, HIGH);
          delay(kTime);
          digitalWrite(PIN_KILL_OUT, LOW);
          bt.print("QS_EVENT:"); bt.println(kTime);
          delay(400); 
      }
  }
  lastSensorState = currentState;

  if (millis() - lastSend > 130) {
    lastSend = millis();
    int out = (int)(filteredRpm * config.rpmCalibration);
    bt.print("RPM:");
    bt.println(out < 0 ? 0 : out);
  }

  if (bt.available()) {
    String in = bt.readStringUntil('\n');
    in.trim();
    if (in.startsWith("S")) handleSync(in);
  }
}
