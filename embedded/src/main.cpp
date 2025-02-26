#include <Adafruit_BNO08x.h>
#include <Adafruit_Sensor.h>
#include <Arduino.h>
#include <Wire.h>
#include <NimBLEDevice.h>

#define DEVICE_NAME "Barbeloni"
#define SERVICE_UUID "832546eb-9a15-42e8-b250-7d2b66aa9ad5"
#define VELOCITY_CHAR_UUID "bf6af529-becb-4509-8258-b144d38c6715"
#define POWER_CHAR_UUID "7e2421b5-09b6-4e66-acc3-1982f6092a91"
#define WORK_CHAR_UUID "49519866-e762-4dfb-8223-7c7d060f3619"

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
float pos[3] = {0, 0, 0};
float force[3] = {0, 0, 0};
float power[3] = {0, 0, 0};
float totalPower = 0.0;
float totalWork = 0.0;

const float avgrate = 0.0001;  // Slowly compute average acceleration
const float leakage = 0.004;   // Adjust leakage as needed
const float gravity = 9.80665; // Gravity in m/s^2
const float mass = 20.0;       // Mass in kg

NimBLEServer *pServer = NULL;
NimBLECharacteristic *pVelocityCharacteristic = NULL;
NimBLECharacteristic *pPowerCharacteristic = NULL;
NimBLECharacteristic *pWorkCharacteristic = NULL;
bool deviceConnected = false;

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
    // pServer->startAdvertising();
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
  pVelocityCharacteristic = pService->createCharacteristic(
      VELOCITY_CHAR_UUID,
      NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  pPowerCharacteristic = pService->createCharacteristic(
      POWER_CHAR_UUID,
      NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  pWorkCharacteristic = pService->createCharacteristic(
      WORK_CHAR_UUID,
      NIMBLE_PROPERTY::READ |
          NIMBLE_PROPERTY::NOTIFY);

  pVelocityCharacteristic->setValue((uint8_t *)vel, sizeof(vel));
  pPowerCharacteristic->setValue((uint8_t *)&totalPower, sizeof(totalPower));
  pWorkCharacteristic->setValue((uint8_t *)&totalWork, sizeof(totalWork));

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
      force[n] = mass * acc[n];
      power[n] = force[n] * vel[n];
    }
    totalPower = power[0] + power[1] + power[2];
    totalWork += totalPower * BNO085_SAMPLERATE_PERIOD_MS / 1000.0;

    // Set the characteristic values (convert float to byte array)
    pVelocityCharacteristic->setValue((uint8_t *)vel, sizeof(vel));
    pPowerCharacteristic->setValue((uint8_t *)&totalPower, sizeof(totalPower));
    pWorkCharacteristic->setValue((uint8_t *)&totalWork, sizeof(totalWork));

    // Notify
    pVelocityCharacteristic->notify();
    pPowerCharacteristic->notify();
    pWorkCharacteristic->notify();

    newQuatData = false;
    newAccelData = false;
  }
}
