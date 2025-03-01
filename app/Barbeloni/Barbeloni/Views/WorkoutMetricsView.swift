//
//  WorkoutMetricsView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//


import SwiftUI
import Charts

struct WorkoutMetricsView: View {
    @ObservedObject var sessionManager: WorkoutSessionManager
    
    var body: some View {
        VStack(spacing: 8) {
            if case .setActive(_, _, let exerciseType, let weight) = sessionManager.currentState {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Exercise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(exerciseType)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(weight, specifier: "%.1f") kg")
                            .font(.headline)
                    }
                }
                
                if sessionManager.isRecording {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Data Points")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sessionManager.currentSetData.count)")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Reps Detected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(sessionManager.repCount)")
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.green))
        .cornerRadius(12)
    }
}