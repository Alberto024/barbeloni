//
//  ContentView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/25/25.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var bluetoothManager = BluetoothManager()
    
    var body: some View {
        VStack {
            Text("Status: \(bluetoothManager.statusMessage)")
            Text(
                String(
                    format: "Velocity: x=%.2f, y=%.2f, z=%.2f", bluetoothManager.velocity[0],
                    bluetoothManager.velocity[1], bluetoothManager.velocity[2]))
            Text(String(format: "Power: %.2f", bluetoothManager.power))
            Text(String(format: "Work: %.2f", bluetoothManager.work))

            Button(action: {
                if bluetoothManager.isConnected {
                    bluetoothManager.disconnect()
                } else {
                    bluetoothManager.startScanning()
                }
            }) {
                Text(bluetoothManager.isConnected ? "Disconnect" : "Connect")
            }.padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
