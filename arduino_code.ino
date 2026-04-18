#include <SoftwareSerial.h>
#include <EEPROM.h>

// --- PROTOTYPE FUNGSI ---
void rpmPulse();
void executeKill();
void parseSettings(String data);
void saveSettings();
void loadSettings();

// SETTINGS STRUCT (Untuk EEPROM)
struct UserSettings {
  int minRpmActive;
  float rpmCalibration;
  float rpmDivider;
  int tableRpm[4];
  int tableKill[4];
  uint32_t magic; // Penanda bahwa EEPROM sudah pernah diisi
};

UserSettings config;
const uint32_t EEPROM_MAGIC = 0xABCD1234;

// 1. PIN CONFIGURATION
const int PIN_SHIFT_SENSOR = 2; // Sensor Quick Shifter (Proximity)
const int PIN_PULSER = 3;       // Sinyal RPM (Pulser/Koil)
const int PIN_KILL_OUT = 10;    // Output ke Relay/Coil Kill
SoftwareSerial btSerial(9, 8);  // Bluetooth: 9=RX, 8=TX

// 2. DATA FILTERING & CALIBRATION
const int DEBOUNCE_RPM = 350;     // Noise protection (us)
float smoothedRpm = 0;
float smoothingFactor = 0.85;     // Smoothness factor

// 4. VOLATILE VARIABLES FOR RPM INTERRUPT
volatile unsigned long lastPulseTime = 0;
volatile unsigned long pulseInterval = 0;

void setup() {
  sei(); // Aktifkan global interrupt
  
  loadSettings(); // Ambil data dari EEPROM (Jika ada)
  
  delay(3000); // Tunggu Bluetooth siap
  btSerial.begin(9600);
  
  pinMode(PIN_PULSER, INPUT_PULLUP);
  pinMode(PIN_SHIFT_SENSOR, INPUT_PULLUP);
  pinMode(PIN_KILL_OUT, OUTPUT);
  digitalWrite(PIN_KILL_OUT, LOW);
  
  // Interrupt pada Pin 3 (Pulser)
  attachInterrupt(digitalPinToInterrupt(PIN_PULSER), rpmPulse, FALLING);
}

void loop() {
  unsigned long now = micros();
  unsigned long currentInterval = pulseInterval;

  // 1. PENGHITUNGAN RPM
  float rawRpm = 0;
  if (now - lastPulseTime > 300000) { 
    rawRpm = 0;
  } else if (currentInterval > 0) {
    rawRpm = (60000000.0 / currentInterval) / config.rpmDivider;
  }

  // 2. FILTERING RPM (EMA)
  smoothedRpm = (smoothedRpm * smoothingFactor) + (rawRpm * (1.0 - smoothingFactor));

  // 3. LOGIKA QUICK SHIFTER
  if (digitalRead(PIN_SHIFT_SENSOR) == LOW) {
    if ((int)smoothedRpm >= config.minRpmActive) {
      executeKill();
    }
  }

  // 4. TERIMA DATA SETTING DARI APLIKASI
  if (btSerial.available() > 0) {
    static String inputString = "";
    char inChar = (char)btSerial.read();
    if (inChar == '\n' || inChar == '\r') {
      if (inputString.startsWith("S")) {
        parseSettings(inputString);
        saveSettings(); // Simpan ke EEPROM setelah perubahan
        btSerial.println("OK:SYNCED_MODULE");
      }
      inputString = "";
    } else {
      inputString += inChar;
    }
  }

  // 5. KIRIM RPM KE DASHBOARD (SETIAP 100ms)
  static unsigned long lastSend = 0;
  if (millis() - lastSend > 100) {
    btSerial.print("RPM:");
    btSerial.println((int)(smoothedRpm * config.rpmCalibration));
    lastSend = millis();
  }
}

// 6. FUNGSI INTERRUPT RPM
void rpmPulse() {
  unsigned long now = micros();
  unsigned long interval = now - lastPulseTime;
  if (interval > DEBOUNCE_RPM) {
    pulseInterval = interval;
    lastPulseTime = now;
  }
}

// 7. FUNGSI EKSEKUSI POTONG MESIN (KILL)
void executeKill() {
  int killTime = config.tableKill[0];
  int rpmNow = (int)smoothedRpm;

  if (rpmNow >= config.tableRpm[3]) killTime = config.tableKill[3];
  else if (rpmNow >= config.tableRpm[2]) killTime = config.tableKill[2];
  else if (rpmNow >= config.tableRpm[1]) killTime = config.tableKill[1];

  if (killTime > 0) {
    digitalWrite(PIN_KILL_OUT, HIGH); 
    delay(killTime); 
    digitalWrite(PIN_KILL_OUT, LOW);  
    
    // Kirim notifikasi ke HP
    btSerial.print("QS_EVENT:");
    btSerial.println(killTime);
    
    delay(300); // Proteksi double-kill
  }
}

// 8. FUNGSI PARSING DATA SETTING (11 PARAMETER)
void parseSettings(String data) {
  data.remove(0, 1); // Buang huruf 'S'
  char str[120];
  data.toCharArray(str, 120);
  int count = 0;
  char* ptr = strtok(str, ",");
  while (ptr != NULL && count < 11) {
    if (count == 0) config.minRpmActive = atoi(ptr);
    else if (count == 1) config.rpmCalibration = atof(ptr);
    else if (count == 2) config.rpmDivider = atof(ptr);
    else if (count == 3) config.tableRpm[0] = atoi(ptr);
    else if (count == 4) config.tableKill[0] = atoi(ptr);
    else if (count == 5) config.tableRpm[1] = atoi(ptr);
    else if (count == 6) config.tableKill[1] = atoi(ptr);
    else if (count == 7) config.tableRpm[2] = atoi(ptr);
    else if (count == 8) config.tableKill[2] = atoi(ptr);
    else if (count == 9) config.tableRpm[3] = atoi(ptr);
    else if (count == 10) config.tableKill[3] = atoi(ptr);
    ptr = strtok(NULL, ",");
    count++;
  }
}

void saveSettings() {
  config.magic = EEPROM_MAGIC;
  EEPROM.put(0, config);
}

void loadSettings() {
  EEPROM.get(0, config);
  // Jika belum ada data (Magic tidak cocok), pakai default
  if (config.magic != EEPROM_MAGIC) {
    config.minRpmActive = 3000;
    config.rpmCalibration = 1.0;
    config.rpmDivider = 11.66;
    int rpmDefs[4] = {3000, 6000, 9000, 12000};
    int killDefs[4] = {90, 80, 70, 60};
    for(int i=0; i<4; i++) {
      config.tableRpm[i] = rpmDefs[i];
      config.tableKill[i] = killDefs[i];
    }
  }
}
