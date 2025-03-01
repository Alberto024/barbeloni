//
//  BluetoothManager.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/25/25.
//

import Combine
import CoreBluetooth
import SwiftUI

struct SensorTimepoint {
    let velocity: [Float]
    let acceleration: [Float]
    let timestamp: UInt32
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

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
    private let vbtServiceUUID = CBUUID(string: "832546eb-9a15-42e8-b250-7d2b66aa9ad5")
    private let dataCharacteristicUUID = CBUUID(string: "bf6af529-becb-4509-8258-b144d38c6715")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // --- Scan for and Connect to the VBT Device ---
    func startScanning() {
        if centralManager.state == .poweredOn {
            isScanning = true
            statusMessage = "Scanning..."
            centralManager.scanForPeripherals(withServices: [vbtServiceUUID], options: nil)
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

        //        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
        //            if serviceUUIDs.contains(vbtServiceUUID) {
        //                statusMessage = "Device Found (by UUID)"
        //                stopScanning()
        //                connect(to: peripheral)
        //                return;
        //            }
        //        }

        if peripheral.name == vbtDeviceName {
            statusMessage = "Device Found"
            stopScanning()  // Stop scanning once the device is found.
            connect(to: peripheral)
            return
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.isConnected = true
        self.statusMessage = "Connected"
        self.peripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([vbtServiceUUID])
    }

    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        self.statusMessage =
            "Connection Failed: \(error?.localizedDescription ?? "Unknown Error")"
        print(self.statusMessage)
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
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

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
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
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
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
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print("Error reading characteristic value: \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else { return }
        let dataSize = MemoryLayout<SensorTimepoint>.size
        guard data.count == dataSize else {
            print(
                "ERROR: Unexpected data size. Got \(data.count) bytes, expected \(dataSize) bytes.")
            return
        }
        data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            if let timepointData = rawBufferPointer.baseAddress?.assumingMemoryBound(
                to: SensorTimepoint.self
            ).pointee {
                let sensorTimepoint = SensorTimepoint(
                    velocity: Array(timepointData.velocity),
                    acceleration: Array(timepointData.acceleration),
                    timestamp: timepointData.timestamp
                )
                DispatchQueue.main.async {
                    self.sensorTimepoint = sensorTimepoint  // Update on the main thread
                }
            }
        }
    }

    // Added to handle notification state changes
    func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print("Error changing notification state: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            print("Notifications STARTED on \(characteristic.uuid)")
        } else {
            print("Notifications STOPPED on \(characteristic.uuid).  Disconnecting.")
        }
    }
}
