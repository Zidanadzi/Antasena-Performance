#include <EEPROM.h>
#include <SoftwareSerial.h>

// Daftar fungsi agar Arduinodroid lancar
void handleRpmInterrupt();
void loadConfig();
float getRpm();
int getKillTime(float rpm);
void handleBluetooth();
void parseSettings(String data);

const int qsPin = 2;            
const int rpmPin = 3;           
const int relayPin = 10;        
const int rxPin = 9;            
const int txPin = 8;            

SoftwareSerial btSerial(rxPin, txPin); 

// MEDIAN 5: STABIL DAN CEPAT
volatile unsigned long lastMicros = 0;
volatile unsigned long intervals[5] = {0,0,0,0,0}; 
volatile int intervalIdx = 0;
unsigned long lastRpmUpdate = 0;

struct Config {
  float minRpm;
  float rpmDivider;
  int tableRpm[4];
  int tableKill[4];
  int magicNumber;
};

Config conf;
float smoothedRpm = 0;

void setup() {
  Serial.begin(9600);
  btSerial.begin(9600); 
  
  pinMode(rpmPin, INPUT_PULLUP);
  pinMode(qsPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, LOW); 

  attachInterrupt(digitalPinToInterrupt(rpmPin), handleRpmInterrupt, FALLING);
  
  loadConfig();
  
  delay(1000); 
  btSerial.println("STATUS:READY");
}

void loop() {
  unsigned long now = millis();

  // 1. BROADCAST RPM (SETIAP 100ms - Rekomendasi Stabil)
  static unsigned long lastSend = 0;
  if (now - lastSend >= 100) {
    float raw = getRpm();
    
    // Auto-smooth sederhana di sisi arduino
    smoothedRpm = (smoothedRpm * 0.5) + (raw * 0.5);
    
    // Gabungkan blok yang anda sarankan
    btSerial.print("RPM:");
    btSerial.print((int)(smoothedRpm * conf.rpmDivider));
    btSerial.println(); 
    
    // Debug ke USB
    Serial.print("RPM_CAL:");
    Serial.println((int)(smoothedRpm * conf.rpmDivider));
    
    lastSend = now;
  }

  // 2. LOGIKA QUICK SHIFTER
  if (digitalRead(qsPin) == LOW) {
    float currentRpm = smoothedRpm * conf.rpmDivider;
    if (currentRpm >= conf.minRpm) {
      int timeToCut = getKillTime(currentRpm);
      digitalWrite(relayPin, HIGH); 
      delay(timeToCut);
      digitalWrite(relayPin, LOW);  
      
      btSerial.print("QS_EVENT:");
      btSerial.println(timeToCut);
      
      delay(400); 
    }
  }

  // 3. TERIMA PENGATURAN (Sesuai Protocol App Flutter)
  if (btSerial.available()) {
    String data = btSerial.readStringUntil('\n');
    data.trim();
    if (data.length() > 0) {
      if (data.startsWith("S")) {
        parseSettings(data);
      }
    }
  }
}

void handleRpmInterrupt() {
  unsigned long m = micros();
  unsigned long duration = m - lastMicros;
  if (duration > 300) { // Anti noise sampai 14.000+ RPM
    intervals[intervalIdx] = duration;
    intervalIdx = (intervalIdx + 1) % 5;
    lastMicros = m;
  }
}

float getRpm() {
  unsigned long sorted[5];
  
  // Ambil data dengan aman dari interrupt
  uint8_t oldSREG = SREG;
  cli();
  for (int i = 0; i < 5; i++) sorted[i] = intervals[i];
  SREG = oldSREG;

  // Sorting Median
  for (int i = 0; i < 4; i++) {
    for (int j = i + 1; j < 5; j++) {
      if (sorted[i] > sorted[j]) {
        unsigned long t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t;
      }
    }
  }
  
  // Jika mesin mati > 0.4 detik (2500 RPM min)
  if (micros() - lastMicros > 400000) return 0;

  unsigned long med = sorted[2]; 
  if (med == 0) return 0;
  
  // Hitung RPM RAW (Hz base)
  return (60000000.0 / (float)med); 
}

int getKillTime(float rpm) {
  // Ambil dari tabel yang dikirimkan aplikasi
  if (rpm < (float)conf.tableRpm[1]) return conf.tableKill[0];
  if (rpm < (float)conf.tableRpm[2]) return conf.tableKill[1];
  if (rpm < (float)conf.tableRpm[3]) return conf.tableKill[2];
  return conf.tableKill[3];
}

void parseSettings(String data) {
  // Protocol: S[minRpmActive],[rpmCalibration],[tableRpm0],[tableKill0],[tableRpm1],[tableKill1],[tableRpm2],[tableKill2],[tableRpm3],[tableKill3]
  
  int commaIndex[10];
  int count = 0;
  for (int i = 0; i < (int)data.length() && count < 10; i++) {
    if (data[i] == ',') {
      commaIndex[count++] = i;
    }
  }

  if (count >= 9) {
    conf.minRpm = data.substring(1, commaIndex[0]).toFloat();
    conf.rpmDivider = data.substring(commaIndex[0] + 1, commaIndex[1]).toFloat();
    
    conf.tableRpm[0] = data.substring(commaIndex[1] + 1, commaIndex[2]).toInt();
    conf.tableKill[0] = data.substring(commaIndex[2] + 1, commaIndex[3]).toInt();
    
    conf.tableRpm[1] = data.substring(commaIndex[3] + 1, commaIndex[4]).toInt();
    conf.tableKill[1] = data.substring(commaIndex[4] + 1, commaIndex[5]).toInt();
    
    conf.tableRpm[2] = data.substring(commaIndex[5] + 1, commaIndex[6]).toInt();
    conf.tableKill[2] = data.substring(commaIndex[6] + 1, commaIndex[7]).toInt();
    
    conf.tableRpm[3] = data.substring(commaIndex[7] + 1, commaIndex[8]).toInt();
    conf.tableKill[3] = data.substring(commaIndex[8] + 1).toInt();
    
    conf.magicNumber = 1337;
    EEPROM.put(0, conf);
    btSerial.println("SUCCESS_SAVE");
  } else {
    btSerial.println("ERROR_PARSING");
  }
}

void loadConfig() {
  EEPROM.get(0, conf);
  if (conf.magicNumber != 1337) { 
    conf.minRpm = 3000;
    conf.rpmDivider = 1.15;
    
    conf.tableRpm[0] = 6000;  conf.tableKill[0] = 70;
    conf.tableRpm[1] = 9000;  conf.tableKill[1] = 65;
    conf.tableRpm[2] = 11500; conf.tableKill[2] = 75;
    conf.tableRpm[3] = 12000; conf.tableKill[3] = 80;
    
    conf.magicNumber = 1337;
    EEPROM.put(0, conf);
  }
}
