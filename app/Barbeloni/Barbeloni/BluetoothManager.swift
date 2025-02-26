//
//  BluetoothManager.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/25/25.
//

import Combine
import CoreBluetooth
import SwiftUI

let vbtDeviceName: String = "Barbeloni"
let vbtServiceUUID = CBUUID(string: "832546eb-9a15-42e8-b250-7d2b66aa9ad5")
let velocityCharacteristicUUID = CBUUID(string: "bf6af529-becb-4509-8258-b144d38c6715")
let powerCharacteristicUUID = CBUUID(string: "7e2421b5-09b6-4e66-acc3-1982f6092a91")
let workCharacteristicUUID = CBUUID(string: "49519866-e762-4dfb-8223-7c7d060f3619")

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // --- Published Properties (for SwiftUI) ---
    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"
    @Published var velocity: [Float] = [0.0, 0.0, 0.0]
    @Published var power: Float = 0.0
    @Published var work: Float = 0.0

    // --- Core Bluetooth Objects ---
    private var centralManager: CBCentralManager!
    private var vbtPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // --- Scan for and Connect to the VBT Device ---
    func startScanning() {
        if centralManager.state == .poweredOn {
            statusMessage = "Scanning..."
            centralManager.scanForPeripherals(withServices: [vbtServiceUUID], options: nil)
        } else {
            statusMessage = "Bluetooth Not Ready"
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        statusMessage = "Scan Stopped"
    }

    func connect(to peripheral: CBPeripheral) {
        vbtPeripheral = peripheral
        vbtPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        if let peripheral = vbtPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // --- CBCentralManagerDelegate Methods ---

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.statusMessage = "Bluetooth On"
            case .poweredOff:
                self.statusMessage = "Bluetooth Off"
            case .unauthorized:
                self.statusMessage = "Bluetooth Unauthorized"
            case .unsupported:
                self.statusMessage = "Bluetooth Unsupported"
            case .resetting:
                self.statusMessage = "Bluetooth Resetting"
            default:
                self.statusMessage = "Bluetooth Unknown State"
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        print("Discovered \(peripheral.name ?? "Unknown Device")")
        print("Peripheral Identifier: \(peripheral.identifier)")
        print("Advertisement Data: \(advertisementData)")

        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            if serviceUUIDs.contains(vbtServiceUUID) {
                statusMessage = "Device Found (by UUID)"
                stopScanning()
                connect(to: peripheral)
                return;
            }
        }
        
        if peripheral.name == vbtDeviceName {  // Replace with your device name
            statusMessage = "Device Found"
            stopScanning()  // Stop scanning once the device is found.
            connect(to: peripheral)
            return;
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.statusMessage = "Connected"
            peripheral.discoverServices([vbtServiceUUID])
        }
    }

    func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        DispatchQueue.main.async {
            self.statusMessage =
                "Connection Failed: \(error?.localizedDescription ?? "Unknown Error")"
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        print("Disconnecting...")
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusMessage = "Disconnected"
            self.vbtPeripheral = nil  // Clear the peripheral reference
            print("... Disconnected")
        }
    }

    // --- CBPeripheralDelegate Methods ---

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            print("Service found: \(service.uuid)")
            if service.uuid == vbtServiceUUID {
                peripheral.discoverCharacteristics(
                    [velocityCharacteristicUUID, powerCharacteristicUUID, workCharacteristicUUID],
                    for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            print("Characteristic found: \(characteristic.uuid)")

            // Subscribe to notifications for our characteristics
            if characteristic.uuid == velocityCharacteristicUUID
                || characteristic.uuid == powerCharacteristicUUID
                || characteristic.uuid == workCharacteristicUUID
            {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }
        DispatchQueue.main.async {
            if characteristic.uuid == velocityCharacteristicUUID {
                let velocityData = [Float](unsafeUninitializedCapacity: 3) { (buffer, count) in
                    _ = data.copyBytes(to: buffer)
                    count = 3
                }
                self.velocity = velocityData

            } else if characteristic.uuid == powerCharacteristicUUID {
                self.power = data.withUnsafeBytes { $0.load(as: Float.self) }

            } else if characteristic.uuid == workCharacteristicUUID {
                self.work = data.withUnsafeBytes { $0.load(as: Float.self) }
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
            print("Notification STARTED on \(characteristic.uuid)")
        } else {
            print("Notification STOPPED on \(characteristic.uuid).  Disconnecting.")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
}
