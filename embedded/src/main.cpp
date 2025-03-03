#include <Adafruit_BNO08x.h>
#include <Adafruit_Sensor.h>
#include <Arduino.h>
#include <Wire.h>
#include <NimBLEDevice.h>

#define DEVICE_NAME "Barbeloni"
#define SERVICE_UUID "832546eb-9a15-42e8-b250-7d2b66aa9ad5"
#define DATA_CHAR_UUID "bf6af529-becb-4509-8258-b144d38c6715"

// Sampling rate period in milliseconds
const float BNO085_SAMPLERATE_PERIOD_MS = 10.0;

// Initialize the BNO085 for SPI communication
#define BNO08X_CS 10
#define BNO08X_INT 9
#define BNO08X_RESET 5

Adafruit_BNO08x bno(BNO08X_RESET);

// Variables for storing tilt-corrected acceleration and velocity
float avgacc[3] = {0, 0, 0};
float vel[3] = {0, 0, 0};

struct TimepointData
{
  float velocity[3];
  float acceleration[3];
  uint32_t timestamp;
};

const float avgrate = 0.0001; // Slowly compute average acceleration
const float leakage = 0.004;  // Adjust leakage as needed

uint32_t lastLogTime = 0;

NimBLEServer *pServer = NULL;
NimBLECharacteristic *pDataCharacteristic = NULL;
volatile bool deviceConnected = false;

class MyServerCallbacks : public NimBLEServerCallbacks
{
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override
  {
    deviceConnected = true;
    Serial.println("Client connected");
    Serial.printf("Client address: %s\n", connInfo.getAddress().toString().c_str());
  }

  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo, int reason) override
  {
    deviceConnected = false;
    Serial.println("Client disconnected");
    NimBLEDevice::startAdvertising();
    Serial.println("Advertising restarted");
  }
} serverCallbacks;

bool startBluetooth()
{
  NimBLEDevice::init(DEVICE_NAME);
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(&serverCallbacks);

  // Create the service
  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  // Create characteristics
  pDataCharacteristic = pService->createCharacteristic(
      DATA_CHAR_UUID,
      NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  // Start the service
  pService->start();

  // Start advertising
  NimBLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->setName(DEVICE_NAME);
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->enableScanResponse(true);
  pAdvertising->start();
  Serial.println("Bluetooth initialized and advertising");
  return true;
}

bool configureSensor()
{
  if (!bno.begin_SPI(BNO08X_CS, BNO08X_INT))
  {
    Serial.println("Failed to find BNO08x chip");
    return false;
  }

  if (!bno.enableReport(SH2_ROTATION_VECTOR, BNO085_SAMPLERATE_PERIOD_MS * 1000))
  {
    Serial.println("Could not enable rotation vector");
    return false;
  }

  if (!bno.enableReport(SH2_LINEAR_ACCELERATION, BNO085_SAMPLERATE_PERIOD_MS * 1000))
  {
    Serial.println("Could not enable linear acceleration");
    return false;
  }

  if (!startBluetooth())
  {
    Serial.println("Failed to start Bluetooth");
    return false;
  }

  return true;
}

void setup()
{
  Serial.begin(115200);
  while (!Serial)
    delay(100);

  if (!configureSensor())
  {
    Serial.println("Sensor configuration failed");
    while (1)
      ;
  }
  delay(500);
}

void loop()
{
  sh2_SensorValue_t sensorValue;

  // Variables to store the latest quaternion and linear acceleration data with timestamps
  static float qw = 1.0, qx = 0.0, qy = 0.0, qz = 0.0; // Quaternion components
  static bool newQuatData = false;

  static float la_x = 0.0, la_y = 0.0, la_z = 0.0; // Linear acceleration components
  static bool newAccelData = false;

  // Read all available sensor events
  while (bno.getSensorEvent(&sensorValue))
  {
    if (sensorValue.sensorId == SH2_ROTATION_VECTOR)
    {
      // Update quaternion components and timestamp
      qw = sensorValue.un.rotationVector.real;
      qx = -sensorValue.un.rotationVector.i; // Flip x-axis
      qy = -sensorValue.un.rotationVector.j; // Flip y-axis
      qz = -sensorValue.un.rotationVector.k; // Flip z-axis
      newQuatData = true;
    }
    else if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION)
    {
      // Update linear acceleration components and timestamp
      la_x = sensorValue.un.linearAcceleration.x;
      la_y = sensorValue.un.linearAcceleration.y;
      la_z = sensorValue.un.linearAcceleration.z;
      newAccelData = true;
    }
    if (newQuatData && newAccelData)
    {
      break;
    }
  }

  if (newQuatData && newAccelData)
  {
    // Process synchronized data
    float acc[3];

    // Apply tilt correction
    acc[0] = (1 - 2 * (qy * qy + qz * qz)) * la_x + (2 * (qx * qy + qw * qz)) * la_y + (2 * (qx * qz - qw * qy)) * la_z;
    acc[1] = (2 * (qx * qy - qw * qz)) * la_x + (1 - 2 * (qx * qx + qz * qz)) * la_y + (2 * (qy * qz + qw * qx)) * la_z;
    acc[2] = (2 * (qx * qz + qw * qy)) * la_x + (2 * (qy * qz - qw * qx)) * la_y + (1 - 2 * (qx * qx + qy * qy)) * la_z;

    // Integrate velocity using corrected acceleration
    for (int n = 0; n < 3; n++)
    {
      avgacc[n] = avgrate * acc[n] + (1 - avgrate) * avgacc[n];
      vel[n] += BNO085_SAMPLERATE_PERIOD_MS / 1000.0 * (acc[n] - avgacc[n]) - leakage * vel[n];
    }

    TimepointData dataToSend;
    memcpy(dataToSend.velocity, vel, sizeof(vel));     // Copy velocity
    memcpy(dataToSend.acceleration, acc, sizeof(acc)); // Copy acceleration
    dataToSend.timestamp = millis();                   // Capture the timestamp

    // Set the characteristic values (convert float to byte array)
    pDataCharacteristic->setValue((uint8_t *)&dataToSend, sizeof(dataToSend));
    pDataCharacteristic->notify();

    // Every 5 seconds log data to serial
    if (millis() - lastLogTime > 5000)
    {
      lastLogTime = millis();
      Serial.println("Sizeof dataToSend: ");
      Serial.println(sizeof(dataToSend));
      Serial.println("Data that is being sent: ");
      Serial.println(&dataToSend);
      Serial.print("Timestamp: ");
      Serial.print(dataToSend.timestamp);
      Serial.print(", Velocity: ");
      Serial.print(dataToSend.velocity[0]);
      Serial.print(", ");
      Serial.print(dataToSend.velocity[1]);
      Serial.print(", ");
      Serial.print(dataToSend.velocity[2]);
      Serial.print(" m/s, Acceleration: ");
      Serial.print(dataToSend.acceleration[0]);
      Serial.print(", ");
      Serial.print(dataToSend.acceleration[1]);
      Serial.print(", ");
      Serial.print(dataToSend.acceleration[2]);
      Serial.println(" m/s^2");
    }

    newQuatData = false;
    newAccelData = false;
  }
}
