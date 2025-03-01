//
//  LiveDataView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//


import SwiftUI
import Charts

// Live data visualization
struct LiveDataView: View {
    @ObservedObject var sessionManager: WorkoutSessionManager
    @State private var showingVelocity = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Live Sensor Data")
                    .font(.headline)
                
                Spacer()
                
                Picker("Data Type", selection: $showingVelocity) {
                    Text("Velocity").tag(true)
                    Text("Acceleration").tag(false)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            
            // Chart for visualization
            if sessionManager.currentSetData.count > 1 {
                Chart {
                    // Display the last 100 data points for performance
                    let dataPoints = sessionManager.currentSetData.suffix(100)
                    let values = showingVelocity ?
                        dataPoints.map { calculateMagnitude($0.velocity) } :
                        dataPoints.map { calculateMagnitude($0.acceleration) }
                    
                    ForEach(values.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Time", index),
                            y: .value(showingVelocity ? "Velocity" : "Acceleration", values[index])
                        )
                        .foregroundStyle(showingVelocity ? Color.blue : Color.red)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: 0...(showingVelocity ? 2.5 : 15))
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel { /* Empty to hide labels */ }
                        AxisGridLine()
                    }
                }
            } else {
                Text("Waiting for data...")
                    .foregroundColor(.secondary)
                    .frame(height: 160)
            }
        }
        .padding()
        .background(Color(.gray))
        .cornerRadius(12)
    }
    
    // Calculate vector magnitude
    private func calculateMagnitude(_ vector: [Float]) -> Float {
        guard vector.count >= 3 else { return 0 }
        return sqrt(vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2])
    }
}
