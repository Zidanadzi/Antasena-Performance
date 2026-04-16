#include <EEPROM.h>
#include <SoftwareSerial.h>

// --- DAFTAR ISI FUNGSI (Untuk Arduinodroid) ---
void handleRpmInterrupt();
void loadConfig();
float calculateMedianRpm();
int getKillTime(float rpm);
void handleBluetooth();
void parseConfig(String data);

// --- KONFIGURASI PIN ---
const int qsPin = 2;            
const int rpmPin = 3;           
const int relayPin = 10;        
const int rxPin = 9;            
const int txPin = 8;            

SoftwareSerial btSerial(rxPin, txPin); 

// --- SIGNAL PROCESSING ---
volatile unsigned long lastMicros = 0;
volatile unsigned long intervals[3] = {0,0,0}; 
volatile int intervalIdx = 0;
unsigned long lastRpmUpdate = 0;

// --- KALMAN ---
float rpmFiltered = 0;
float p_kalman = 1.0;
float k_gain = 0;

struct Config {
  float minRpm;
  int k3k, k6k, k9k, k12k;
  float rpmDivider;     
  float shiftRpm;
  bool kalmanOn;
  float q_kalman;
  float r_kalman;
  int magicNumber;
};

Config conf;

void setup() {
  Serial.begin(9600);
  btSerial.begin(9600); 
  
  pinMode(rpmPin, INPUT_PULLUP);
  pinMode(qsPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, LOW); 

  attachInterrupt(digitalPinToInterrupt(rpmPin), handleRpmInterrupt, FALLING);
  
  loadConfig();
  
  btSerial.println("STATUS:CONNECTED");
  Serial.println("STATUS:CONNECTED");
}

void loop() {
  unsigned long now = millis();

  if (now - lastRpmUpdate >= 30) {
    float rawRpm = calculateMedianRpm();
    
    if (conf.kalmanOn) {
      p_kalman = p_kalman + conf.q_kalman;
      k_gain = p_kalman / (p_kalman + conf.r_kalman);
      rpmFiltered = rpmFiltered + k_gain * (rawRpm - rpmFiltered);
      p_kalman = (1 - k_gain) * p_kalman;
    } else {
      rpmFiltered = rawRpm; 
    }

    if (micros() - lastMicros > 250000) {
      rpmFiltered = 0;
      for(int i=0; i<3; i++) intervals[i] = 0;
    }

    btSerial.print("RPM:");
    btSerial.println((int)rpmFiltered);
    Serial.print("RPM:");
    Serial.println((int)rpmFiltered);

    if (rpmFiltered >= conf.shiftRpm && conf.shiftRpm > 0) {
      btSerial.println("SHIFT!");
    }

    lastRpmUpdate = now;
  }

  if (digitalRead(qsPin) == LOW) {
    if (rpmFiltered >= conf.minRpm) {
      int timeToCut = getKillTime(rpmFiltered);
      digitalWrite(relayPin, HIGH); 
      delay(timeToCut);
      digitalWrite(relayPin, LOW);  
      btSerial.print("QS_EVENT:");
      btSerial.println(timeToCut);
      delay(400); 
    }
  }

  if (btSerial.available() > 0) {
    handleBluetooth();
  }
}

// --- DEFINISI FUNGSI ---

void handleRpmInterrupt() {
  unsigned long m = micros();
  unsigned long duration = m - lastMicros;
  if (duration > 200) {
    intervals[intervalIdx] = duration;
    intervalIdx = (intervalIdx + 1) % 3;
    lastMicros = m;
  }
}

float calculateMedianRpm() {
  unsigned long sorted[3];
  for (int i = 0; i < 3; i++) sorted[i] = intervals[i];

  if (sorted[0] > sorted[1]) { unsigned long t = sorted[0]; sorted[0] = sorted[1]; sorted[1] = t; }
  if (sorted[1] > sorted[2]) { unsigned long t = sorted[1]; sorted[1] = sorted[2]; sorted[2] = t; }
  if (sorted[0] > sorted[1]) { unsigned long t = sorted[0]; sorted[0] = sorted[1]; sorted[1] = t; }

  unsigned long medianInterval = sorted[1];
  if (medianInterval == 0) return 0;
  return (60000000.0 / (float)medianInterval) / conf.rpmDivider;
}

int getKillTime(float rpm) {
  if (rpm < 6000) return conf.k3k;
  if (rpm < 9000) return conf.k6k;
  if (rpm < 11500) return conf.k9k;
  return conf.k12k;
}

void handleBluetooth() {
  String cmd = btSerial.readStringUntil('\n');
  if (cmd.startsWith("SET_ALL:")) {
    parseConfig(cmd.substring(8));
  }
}

void parseConfig(String data) {
  int comma[10];
  int found = 0;
  for (int i = 0; i < (int)data.length() && found < 10; i++) {
    if (data[i] == ',') {
      comma[found] = i;
      found++;
    }
  }

  if (found >= 9) {
    conf.minRpm = data.substring(0, comma[0]).toFloat();
    conf.k3k = data.substring(comma[0]+1, comma[1]).toInt();
    conf.k6k = data.substring(comma[1]+1, comma[2]).toInt();
    conf.k9k = data.substring(comma[2]+1, comma[3]).toInt();
    conf.k12k = data.substring(comma[3]+1, comma[4]).toInt();
    conf.rpmDivider = data.substring(comma[4]+1, comma[5]).toFloat();
    conf.shiftRpm = data.substring(comma[5]+1, comma[6]).toFloat();
    conf.kalmanOn = data.substring(comma[6]+1, comma[7]).toInt();
    conf.q_kalman = data.substring(comma[7]+1, comma[8]).toFloat();
    conf.r_kalman = data.substring(comma[8]+1).toFloat();
    
    conf.magicNumber = 777;
    EEPROM.put(0, conf);
    btSerial.println("SUCCESS_SAVE");
  }
}

void loadConfig() {
  EEPROM.get(0, conf);
  if (conf.magicNumber != 777) {
    conf.minRpm = 3000;
    conf.k3k = 70; conf.k6k = 65; conf.k9k = 75; conf.k12k = 80;
    conf.rpmDivider = 1.15;
    conf.shiftRpm = 11500;
    conf.kalmanOn = false;
    conf.q_kalman = 0.05;
    conf.r_kalman = 20.0;
    conf.magicNumber = 777;
    EEPROM.put(0, conf);
  }
}
