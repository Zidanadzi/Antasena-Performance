#include <SoftwareSerial.h>

// --- TAMBAHKAN PROTOTYPE FUNGSI DI SINI (SOLUSI ERROR UNDECLARED) ---
void rpmPulse();
void executeKill();
void parseSettings(String data);

// PIN CONFIGURATION
const int PIN_SHIFT_SENSOR = 2; // Sensor Quick Shifter
const int PIN_PULSER = 3;       // Sinyal RPM (Pulser/Koil)
const int PIN_KILL_OUT = 10;    // Output ke Relay/Coil Kill
SoftwareSerial btSerial(8, 9);  // Bluetooth: 8=RX(ke TX BT), 9=TX(ke RX BT)

// CALIBRATION & FILTERING
float rpmDivider = 11.66; // Adjustable via App
const int DEBOUNCE_RPM = 350;     // Proteksi noise (us)
float smoothedRpm = 0;
float smoothingFactor = 0.85;     // 0.85 = Sangat Halus (Smooth)

// SETTINGS (Default)
int minRpmActive = 3000;
float rpmCalibration = 1.0;
int tableRpm[4] = {3000, 6000, 9000, 12000};
int tableKill[4] = {90, 80, 70, 60}; 

// VOLATILE VARIABLES FOR INTERRUPT
volatile unsigned long lastPulseTime = 0;
volatile unsigned long pulseInterval = 0;

void setup() {
  sei(); // Pastikan interupsi global aktif
  delay(3000); // Tunggu Bluetooth Warming-up
  
  btSerial.begin(9600);
  
  pinMode(PIN_PULSER, INPUT_PULLUP);
  pinMode(PIN_SHIFT_SENSOR, INPUT_PULLUP);
  pinMode(PIN_KILL_OUT, OUTPUT);
  digitalWrite(PIN_KILL_OUT, LOW);
  
  // Interrupt pada Pin 3 (Pulser)
  attachInterrupt(digitalPinToInterrupt(PIN_PULSER), rpmPulse, FALLING);
}

void loop() {
  // 1. HITUNG RPM (TANPA MEMLOKIR INTERUPSI)
  unsigned long now = micros();
  unsigned long currentInterval;
  
  // Copy data dari variabel volatile secara cepat
  currentInterval = pulseInterval;

  float rawRpm = 0;
  if (now - lastPulseTime > 300000) { // Jika mesin mati / di bawah 200 RPM
    rawRpm = 0;
  } else if (currentInterval > 0) {
    rawRpm = (60000000.0 / currentInterval) / rpmDivider;
  }

  // 2. FILTERING (EMA - Exponential Moving Average)
  // Menjadikan jarum smooth tanpa Median Filter yang berat
  smoothedRpm = (smoothedRpm * smoothingFactor) + (rawRpm * (1.0 - smoothingFactor));

  // 3. LOGIKA QUICK SHIFTER
  if (digitalRead(PIN_SHIFT_SENSOR) == LOW) {
    if ((int)smoothedRpm >= minRpmActive) {
      executeKill();
    }
  }

  // 4. TERIMA SETTING DARI APLIKASI (Non-Blocking)
  if (btSerial.available() > 0) {
    static String inputString = "";
    char inChar = (char)btSerial.read();
    if (inChar == '\n' || inChar == '\r') {
      if (inputString.startsWith("S")) {
        parseSettings(inputString);
      }
      inputString = "";
    } else {
      inputString += inChar;
    }
  }

  // 5. KIRIM DATA KE HP (SETIAP 100ms)
  static unsigned long lastSend = 0;
  if (millis() - lastSend > 100) {
    btSerial.print("RPM:");
    btSerial.println((int)(smoothedRpm * rpmCalibration));
    lastSend = millis();
  }
}

// FUNGSI INTERRUPT RPM (Sangat Cepat)
void rpmPulse() {
  unsigned long now = micros();
  unsigned long interval = now - lastPulseTime;
  if (interval > DEBOUNCE_RPM) {
    pulseInterval = interval;
    lastPulseTime = now;
  }
}

// FUNGSI EKSEKUSI POTONG MESIN (KILL)
void executeKill() {
  int killTime = tableKill[0]; // Default
  int rpmNow = (int)smoothedRpm;

  // Cek tabel untuk durasi kill berdasarkan RPM
  if (rpmNow >= tableRpm[3]) killTime = tableKill[3];
  else if (rpmNow >= tableRpm[2]) killTime = tableKill[2];
  else if (rpmNow >= tableRpm[1]) killTime = tableKill[1];

  if (killTime > 0) {
    digitalWrite(PIN_KILL_OUT, HIGH);
    delay(killTime); 
    digitalWrite(PIN_KILL_OUT, LOW);
    
    // Kirim notifikasi ke HP bahwa QS aktif
    btSerial.print("QS_EVENT:");
    btSerial.println(killTime);
    
    delay(300); // Proteksi agar tidak double-kill (debounce sensor kopling)
  }
}

// FUNGSI PARSING DATA SETTING DARI HP
void parseSettings(String data) {
  data.remove(0, 1); // Buang huruf 'S'
  char str[120];
  data.toCharArray(str, 120);
  int count = 0;
  char* ptr = strtok(str, ",");
  while (ptr != NULL && count < 11) {
    if (count == 0) minRpmActive = atoi(ptr);
    else if (count == 1) rpmCalibration = atof(ptr);
    else if (count == 2) rpmDivider = atof(ptr);
    else if (count == 3) tableRpm[0] = atoi(ptr);
    else if (count == 4) tableKill[0] = atoi(ptr);
    else if (count == 5) tableRpm[1] = atoi(ptr);
    else if (count == 6) tableKill[1] = atoi(ptr);
    else if (count == 7) tableRpm[2] = atoi(ptr);
    else if (count == 8) tableKill[2] = atoi(ptr);
    else if (count == 9) tableRpm[3] = atoi(ptr);
    else if (count == 10) tableKill[3] = atoi(ptr);
    ptr = strtok(NULL, ",");
    count++;
  }
}

