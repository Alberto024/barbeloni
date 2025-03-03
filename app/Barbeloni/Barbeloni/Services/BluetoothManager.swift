//
//  BluetoothManager.swift - Updated for correct data structure
//  Barbeloni
//

import Combine
import CoreBluetooth
import SwiftUI

// Update the SensorTimepoint to match the C struct memory layout
struct SensorTimepoint {
    // Use tuples for fixed-size arrays to match C memory layout
    var velocity: (Float, Float, Float)
    var acceleration: (Float, Float, Float)
    var timestamp: UInt32

    // Convenience initializer to construct from arrays
    init(velocity: [Float], acceleration: [Float], timestamp: UInt32) {
        self.velocity = (
            velocity.count > 0 ? velocity[0] : 0,
            velocity.count > 1 ? velocity[1] : 0,
            velocity.count > 2 ? velocity[2] : 0
        )
        self.acceleration = (
            acceleration.count > 0 ? acceleration[0] : 0,
            acceleration.count > 1 ? acceleration[1] : 0,
            acceleration.count > 2 ? acceleration[2] : 0
        )
        self.timestamp = timestamp
    }

    // Direct initializer with tuples
    init(
        velocity: (Float, Float, Float), acceleration: (Float, Float, Float),
        timestamp: UInt32
    ) {
        self.velocity = velocity
        self.acceleration = acceleration
        self.timestamp = timestamp
    }
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate,
    CBPeripheralDelegate
{

    // --- Published Properties (for SwiftUI) ---
    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"
    @Published var sensorTimepoint: SensorTimepoint?
    @Published var isScanning = false

    // --- Core Bluetooth Objects ---
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?

    private let vbtDeviceName: String = "Barbeloni"
    private let vbtServiceUUID = CBUUID(
        string: "832546eb-9a15-42e8-b250-7d2b66aa9ad5")
    private let dataCharacteristicUUID = CBUUID(
        string: "bf6af529-becb-4509-8258-b144d38c6715")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // --- Scan for and Connect to the VBT Device ---
    func startScanning() {
        if centralManager.state == .poweredOn {
            isScanning = true
            statusMessage = "Scanning..."
            centralManager.scanForPeripherals(
                withServices: [vbtServiceUUID], options: nil)
        } else {
            statusMessage = "Bluetooth Not Ready"
        }
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
        statusMessage = "Scan Stopped"
    }

    func connect(to peripheral: CBPeripheral) {
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // --- CBCentralManagerDelegate Methods ---

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        print("Discovered \(peripheral.name ?? "Unknown Device")")
        print("Peripheral Identifier: \(peripheral.identifier)")
        print("Advertisement Data: \(advertisementData)")

        if peripheral.name == vbtDeviceName {
            statusMessage = "Device Found"
            stopScanning()  // Stop scanning once the device is found.
            connect(to: peripheral)
            return
        }
    }

    func centralManager(
        _ central: CBCentralManager, didConnect peripheral: CBPeripheral
    ) {
        self.isConnected = true
        self.statusMessage = "Connected"
        self.peripheral = peripheral
        peripheral.delegate = self

        // Request larger MTU if available (iOS 9+)
        if #available(iOS 9.0, *) {
            print(
                "Maximum write value length: \(peripheral.maximumWriteValueLength(for: .withoutResponse))"
            )
            print(
                "Maximum write value length with response: \(peripheral.maximumWriteValueLength(for: .withResponse))"
            )
        }

        peripheral.discoverServices([vbtServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        self.statusMessage =
            "Connection Failed: \(error?.localizedDescription ?? "Unknown Error")"
        print(self.statusMessage)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        print("Disconnecting...")
        self.isConnected = false
        self.statusMessage = "Disconnected"
        self.peripheral = nil  // Clear the peripheral reference
        dataCharacteristic = nil
        print("... Disconnected")
        startScanning()
    }

    // --- CBPeripheralDelegate Methods ---

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverServices error: Error?
    ) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        for service in services {
            print("Service found: \(service.uuid)")
            if service.uuid == vbtServiceUUID {
                peripheral.discoverCharacteristics(
                    [dataCharacteristicUUID],
                    for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        if let error = error {
            print(
                "Error discovering characteristics: \(error.localizedDescription)"
            )
            return
        }

        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Characteristic found: \(characteristic.uuid)")

            // Subscribe to notifications for our characteristics
            if characteristic.uuid == dataCharacteristicUUID {
                dataCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print(
                "Error reading characteristic value: \(error.localizedDescription)"
            )
            return
        }

        guard let data = characteristic.value else { return }

        // Print received data size for debugging
        print("Received data size: \(data.count) bytes")

        // For handling the 28-byte complete struct from ESP32
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

                let timepoint = SensorTimepoint(
                    velocity: velocity,
                    acceleration: acceleration,
                    timestamp: timestamp
                )

                DispatchQueue.main.async {
                    self.sensorTimepoint = timepoint
                }
            }
        }
        // For handling the 12-byte partial data (just velocity)
        else if data.count == 12 {
            data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
                guard
                    let velocityPointer = rawBufferPointer.bindMemory(
                        to: Float.self
                    ).baseAddress
                else { return }
                let velocity: (Float, Float, Float) = (
                    velocityPointer[0], velocityPointer[1], velocityPointer[2]
                )

                // Create or update with new velocity
                var newTimepoint =
                    self.sensorTimepoint
                    ?? SensorTimepoint(
                        velocity: (0, 0, 0),
                        acceleration: (0, 0, 0),
                        timestamp: UInt32(Date().timeIntervalSince1970)
                    )

                newTimepoint.velocity = velocity

                DispatchQueue.main.async {
                    self.sensorTimepoint = newTimepoint
                }
            }
        }
        // For any other data size, log but don't try to parse
        else {
            print("Unexpected data size: \(data.count) bytes. Cannot parse.")
        }
    }

    // Added to handle notification state changes
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print(
                "Error changing notification state: \(error.localizedDescription)"
            )
            return
        }

        if characteristic.isNotifying {
            print("Notifications STARTED on \(characteristic.uuid)")
        } else {
            print(
                "Notifications STOPPED on \(characteristic.uuid).  Disconnecting."
            )
        }
    }
}
