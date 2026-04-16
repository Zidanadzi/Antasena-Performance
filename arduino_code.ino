#include <EEPROM.h>
#include <SoftwareSerial.h>

// --- KONFIGURASI PIN BARU ---
const int qsPin = 2;            // Sensor Shifter (D2)
const int rpmPin = 3;           // Pulser (D3 - Interrupt)
const int relayPin = 10;        // Mosfet Relay (D10)
const int rxPin = 9;            // Bluetooth RX (D9)
const int txPin = 8;            // Bluetooth TX (D8)

// Inisialisasi Bluetooth SoftwareSerial
SoftwareSerial btSerial(rxPin, txPin); 

// --- SIGNAL PROCESSING (9 SAMPLES MEDIAN) ---
volatile unsigned long lastMicros = 0;
volatile unsigned long intervals[9] = {0,0,0,0,0,0,0,0,0}; 
volatile int intervalIdx = 0;
unsigned long lastRpmUpdate = 0;

// --- KALMAN FILTER VARIABLES ---
float rpmFiltered = 0;
float p_kalman = 1.0;
float k_gain = 0;

// --- CONFIGURATION STRUCTURE (EEPROM) ---
struct Config {
  float minRpm;
  int k3k, k6k, k9k, k12k;
  float rpmDivider;     // Default 11.66
  float shiftRpm;
  bool kalmanOn;
  float q_kalman;
  float r_kalman;
  int magicNumber;
};

Config conf;

void setup() {
  // Serial Monitor (USB) tetap bisa digunakan untuk debug
  Serial.begin(9600);
  
  // Bluetooth HC-05 (D8, D9)
  btSerial.begin(9600); 
  
  pinMode(rpmPin, INPUT_PULLUP);
  pinMode(qsPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  digitalWrite(relayPin, LOW); // Normal: Pengapian Nyala

  // Menggunakan Interrupt pada Pin D3 (Interrupt 1)
  attachInterrupt(digitalPinToInterrupt(rpmPin), handleRpmInterrupt, FALLING);
  
  loadConfig();
  
  btSerial.println("STATUS:CONNECTED");
  Serial.println("STATUS:CONNECTED");
}

void loop() {
  unsigned long now = millis();

  // 1. HITUNG & STREAMING RPM (Setiap 50ms)
  if (now - lastRpmUpdate >= 50) {
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
      for(int i=0; i<9; i++) intervals[i] = 0;
    }

    // Kirim Data ke Bluetooth (Aplikasi HP)
    btSerial.print("RPM:");
    btSerial.println((int)rpmFiltered);

    // Debug ke USB (Serial Monitor)
    Serial.print("RPM:");
    Serial.println((int)rpmFiltered);

    if (rpmFiltered >= conf.shiftRpm && conf.shiftRpm > 0) {
      btSerial.println("SHIFT!");
      Serial.println("SHIFT!");
    }

    lastRpmUpdate = now;
  }

  // 2. LOGIKA QUICK SHIFTER (D2 Sensor)
  if (digitalRead(qsPin) == LOW) {
    if (rpmFiltered >= conf.minRpm) {
      int timeToCut = getKillTime(rpmFiltered);
      
      digitalWrite(relayPin, HIGH); // Putus Pengapian
      delay(timeToCut);
      digitalWrite(relayPin, LOW);  // Sambung Kembali
      
      btSerial.print("QS_EVENT:");
      btSerial.println(timeToCut);
      
      delay(400); // Debounce
    }
  }

  // 3. TERIMA SETTING DARI BLUETOOTH
  if (btSerial.available() > 0) {
    handleBluetooth();
  }
}

void handleRpmInterrupt() {
  unsigned long m = micros();
  unsigned long duration = m - lastMicros;
  
  // Noise Filter untuk RPM tinggi (14.000 RPM)
  if (duration > 200) {
    intervals[intervalIdx] = duration;
    intervalIdx = (intervalIdx + 1) % 9;
    lastMicros = m;
  }
}

float calculateMedianRpm() {
  unsigned long sorted[9];
  for (int i = 0; i < 9; i++) sorted[i] = intervals[i];

  for (int i = 0; i < 8; i++) {
    for (int j = i + 1; j < 9; j++) {
      if (sorted[i] > sorted[j]) {
        unsigned long temp = sorted[i];
        sorted[i] = sorted[j];
        sorted[j] = temp;
      }
    }
  }

  unsigned long medianInterval = sorted[4];
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
  for (int i = 0; i < data.length() && found < 10; i++) {
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
    conf.rpmDivider = 11.66;
    conf.shiftRpm = 11500;
    conf.kalmanOn = true;
    conf.q_kalman = 0.05;
    conf.r_kalman = 20.0;
    conf.magicNumber = 777;
    EEPROM.put(0, conf);
  }
}
