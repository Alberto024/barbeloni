//
//  LiveDataView.swift
//  Barbeloni
//

import Charts
import SwiftUI

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
                    let values =
                        showingVelocity
                        ? dataPoints.map {
                            calculateMagnitude(
                                ($0.velocity.0, $0.velocity.1, $0.velocity.2))
                        }
                        : dataPoints.map {
                            calculateMagnitude(
                                (
                                    $0.acceleration.0, $0.acceleration.1,
                                    $0.acceleration.2
                                ))
                        }

                    ForEach(values.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Time", index),
                            y: .value(
                                showingVelocity ? "Velocity" : "Acceleration",
                                values[index])
                        )
                        .foregroundStyle(
                            showingVelocity ? Color.blue : Color.red)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: 0...(showingVelocity ? 2.5 : 15))
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel { /* Empty to hide labels */  }
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

    // Calculate vector magnitude from tuple
    private func calculateMagnitude(_ vector: (Float, Float, Float)) -> Float {
        return sqrt(
            vector.0 * vector.0 + vector.1 * vector.1 + vector.2 * vector.2)
    }
}
