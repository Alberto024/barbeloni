import Combine
import CoreBluetooth
import SwiftUI

// Simplified sensor data structure to match C struct memory layout
struct SensorTimepoint {
    var velocity: (Float, Float, Float)
    var acceleration: (Float, Float, Float)
    var timestamp: UInt32

    // Helper to calculate magnitude of a vector component
    func velocityMagnitude() -> Float {
        return sqrt(
            velocity.0 * velocity.0 + velocity.1 * velocity.1 + velocity.2
                * velocity.2)
    }

    func accelerationMagnitude() -> Float {
        return sqrt(
            acceleration.0 * acceleration.0 + acceleration.1 * acceleration.1
                + acceleration.2 * acceleration.2)
    }
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate,
    CBPeripheralDelegate
{
    // Published properties for UI binding
    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"
    @Published var sensorTimepoint: SensorTimepoint?
    @Published var isScanning = false

    // Core Bluetooth objects
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?

    // Device identifiers
    private let deviceName: String = "Barbeloni"
    private let serviceUUID = CBUUID(
        string: "832546eb-9a15-42e8-b250-7d2b66aa9ad5")
    private let dataCharacteristicUUID = CBUUID(
        string: "bf6af529-becb-4509-8258-b144d38c6715")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public Methods

    func startScanning() {
        if centralManager.state == .poweredOn {
            isScanning = true
            statusMessage = "Scanning..."
            centralManager.scanForPeripherals(
                withServices: [serviceUUID], options: nil)
        } else {
            statusMessage = "Bluetooth Not Ready"
        }
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
        statusMessage = "Scan Stopped"
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            isConnected = false
            statusMessage = "Bluetooth Off"
        case .unauthorized:
            statusMessage = "Bluetooth Unauthorized"
        case .unsupported:
            statusMessage = "Bluetooth Unsupported"
        default:
            statusMessage = "Bluetooth Unavailable"
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        if peripheral.name == deviceName {
            statusMessage = "Device Found"
            stopScanning()
            self.peripheral = peripheral
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(
        _ central: CBCentralManager, didConnect peripheral: CBPeripheral
    ) {
        isConnected = true
        statusMessage = "Connected"
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        isConnected = false
        statusMessage = "Disconnected"
        self.peripheral = nil
        dataCharacteristic = nil
        startScanning()  // Restart scanning to reconnect
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverServices error: Error?
    ) {
        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics(
                    [dataCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == dataCharacteristicUUID {
                dataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        guard let data = characteristic.value, error == nil else { return }

        // Handle 28-byte complete data struct
        if data.count == 28 {
            data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
                guard let baseAddress = rawBufferPointer.baseAddress else {
                    return
                }

                // Extract velocity (first 12 bytes)
                let velocityPointer = baseAddress.assumingMemoryBound(
                    to: Float.self)
                let velocity: (Float, Float, Float) = (
                    velocityPointer[0], velocityPointer[1], velocityPointer[2]
                )

                // Extract acceleration (next 12 bytes)
                let accelerationPointer = (baseAddress + 12)
                    .assumingMemoryBound(to: Float.self)
                let acceleration: (Float, Float, Float) = (
                    accelerationPointer[0], accelerationPointer[1],
                    accelerationPointer[2]
                )

                // Extract timestamp (last 4 bytes)
                let timestampPointer = (baseAddress + 24).assumingMemoryBound(
                    to: UInt32.self)
                let timestamp = timestampPointer.pointee

                DispatchQueue.main.async {
                    self.sensorTimepoint = SensorTimepoint(
                        velocity: velocity,
                        acceleration: acceleration,
                        timestamp: timestamp
                    )
                }
            }
        }
    }
}
