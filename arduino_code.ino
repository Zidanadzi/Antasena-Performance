/*
 * ANTASENA PERFORMANCE - UNIVERSAL ARDUINO CODE
 * Compatible with:
 * 1. Antasena Web Dashboard (HM-10 / BLE)
 * 2. Serial Bluetooth Terminal (HC-05 / Classic)
 * 
 * Hardware: Arduino Nano, Relay Sanyi 80A, Optocoupler, Proximity Sensor
 */

#include <SoftwareSerial.h>

// --- 1. FUNCTION PROTOTYPES ---
void processCommand(String cmd);
void executeQuickShift();
void rpmInterrupt();
void sensorInterrupt();

// --- 2. PIN CONFIGURATION ---
#define BT_RX 8
#define BT_TX 9
#define SENSOR_PIN 2
#define RPM_PIN 3    
#define RELAY_PIN 10 
#define LED_PIN 13   

SoftwareSerial ble(BT_RX, BT_TX);

// --- 3. CONTROL VARIABLES ---
volatile unsigned long lastRpmMicros = 0;
volatile float currentRpm = 0;
volatile bool shiftRequested = false;
unsigned long lastTelemetriTime = 0;
unsigned long lastShiftTime = 0;
const int shiftLockout = 500; 

// RPM Filtering
const int numReadings = 5;
float readings[numReadings];
int readIndex = 0;
float total = 0;

// 4-Table Performance Settings
int tableRpm[4]  = {4000, 6000, 8000, 10000}; 
int tableKill[4] = {95, 85, 75, 65}; 

void setup() {
  // Use 9600 for HC-05 / HM-10 default
  ble.begin(9600); 
  
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  pinMode(LED_PIN, OUTPUT);
  
  pinMode(SENSOR_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(SENSOR_PIN), sensorInterrupt, FALLING);
  
  pinMode(RPM_PIN, INPUT_PULLUP); 
  attachInterrupt(digitalPinToInterrupt(RPM_PIN), rpmInterrupt, FALLING);

  for (int i = 0; i < numReadings; i++) readings[i] = 0;
}

void loop() {
  // A. RECEIVE COMMANDS (Format: T1R4000, T1K95, etc.)
  if (ble.available() > 0) {
    String command = ble.readStringUntil('\n');
    command.trim();
    if (command.length() > 0) {
      processCommand(command);
      // Visual feedback for command received
      digitalWrite(LED_PIN, HIGH); delay(50); digitalWrite(LED_PIN, LOW);
    }
  }

  // B. QUICKSHIFT LOGIC
  if (shiftRequested) {
    if (millis() - lastShiftTime > shiftLockout) {
      executeQuickShift();
      lastShiftTime = millis();
    }
    shiftRequested = false;
  }

  // C. SEND TELEMETRY (Format: RPM,KillTime,MinRPM)
  if (millis() - lastTelemetriTime > 150) {
    // This format is compatible with the Web Dashboard
    ble.print((int)currentRpm);
    ble.print(",");
    ble.print(tableKill[0]); 
    ble.print(",");
    ble.println(tableRpm[0]); 

    lastTelemetriTime = millis();
    
    // Reset RPM if no pulses for 0.5s
    if (micros() - lastRpmMicros > 500000) currentRpm = 0;
  }

  // D. DIAGNOSTIC LED
  if (currentRpm > 500) {
    digitalWrite(LED_PIN, (millis() / 100) % 2); 
  } else {
    digitalWrite(LED_PIN, LOW);
  }
}

void executeQuickShift() {
  int activeKillTime = 0;

  // Select Kill Time based on current RPM
  if (currentRpm >= tableRpm[3])      activeKillTime = tableKill[3];
  else if (currentRpm >= tableRpm[2]) activeKillTime = tableKill[2];
  else if (currentRpm >= tableRpm[1]) activeKillTime = tableKill[1];
  else if (currentRpm >= tableRpm[0]) activeKillTime = tableKill[0];

  if (activeKillTime > 0) {
    digitalWrite(RELAY_PIN, HIGH); // Cut Ignition
    delay(activeKillTime);
    digitalWrite(RELAY_PIN, LOW);  // Restore Ignition
  }
}

void processCommand(String cmd) {
  int tableIdx = -1;
  if (cmd.startsWith("T1")) tableIdx = 0;
  else if (cmd.startsWith("T2")) tableIdx = 1;
  else if (cmd.startsWith("T3")) tableIdx = 2;
  else if (cmd.startsWith("T4")) tableIdx = 3;

  if (tableIdx != -1) {
    if (cmd.indexOf("R") > 0) {
      tableRpm[tableIdx] = cmd.substring(cmd.indexOf("R") + 1).toInt();
    } else if (cmd.indexOf("K") > 0) {
      tableKill[tableIdx] = cmd.substring(cmd.indexOf("K") + 1).toInt();
    }
  }
}

void rpmInterrupt() {
  unsigned long currentMicros = micros();
  unsigned long duration = currentMicros - lastRpmMicros;
  
  if (duration > 4000) { // Noise Filter
    float rawRpm = 60000000.0 / duration;
    
    // Moving Average Filter
    total = total - readings[readIndex];
    readings[readIndex] = rawRpm;
    total = total + readings[readIndex];
    readIndex = (readIndex + 1) % numReadings;
    
    currentRpm = total / numReadings;
    lastRpmMicros = currentMicros;
  }
}

void sensorInterrupt() {
  if (currentRpm > tableRpm[0]) shiftRequested = true;
}
