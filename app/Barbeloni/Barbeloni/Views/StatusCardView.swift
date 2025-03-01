//
//  StatusCardView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//


import SwiftUI
import Charts

struct StatusCardView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var sessionManager: WorkoutSessionManager
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: bluetoothManager.isConnected ? "bluetooth.connected" : "bluetooth.slash")
                    .font(.title2)
                    .foregroundColor(bluetoothManager.isConnected ? .blue : .red)
                
                Text(bluetoothManager.statusMessage)
                    .font(.headline)
                
                Spacer()
                
                if !bluetoothManager.isConnected {
                    Button(action: {
                        bluetoothManager.startScanning()
                    }) {
                        Text("Connect")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: {
                        bluetoothManager.disconnect()
                    }) {
                        Text("Disconnect")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            
            if case .workoutActive = sessionManager.currentState {
                Divider()
                
                HStack {
                    Label("\(sessionManager.setCount) Sets", systemImage: "list.bullet")
                    Spacer()
                    Label("\(sessionManager.repCount) Total Reps", systemImage: "figure.strengthtraining.traditional")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.green))
        .cornerRadius(12)
    }
}