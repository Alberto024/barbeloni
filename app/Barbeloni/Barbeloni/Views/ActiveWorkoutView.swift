//
//  WorkoutView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import Charts
import SwiftUI

// Main view for active workout session with simple dropdown
struct ActiveWorkoutView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var sessionManager: WorkoutSessionManager

    @State private var exerciseType = ""
    @State private var weight: Float = 20.0

    // Exercise type options
    let exerciseTypes = [
        "Squat", "Bench Press", "Deadlift", "Shoulder Press", "Row",
    ]

    init() {
        let bluetoothManager = BluetoothManager()
        _bluetoothManager = StateObject(wrappedValue: bluetoothManager)
        _sessionManager = StateObject(
            wrappedValue: WorkoutSessionManager(
                bluetoothManager: bluetoothManager))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Status card
                StatusCardView(
                    bluetoothManager: bluetoothManager,
                    sessionManager: sessionManager)

                // Current workout metrics
                if case .workoutActive = sessionManager.currentState {
                    WorkoutMetricsView(sessionManager: sessionManager)
                }

                // Exercise data input section (when no set is active)
                if case .workoutActive = sessionManager.currentState,
                    !sessionManager.isRecording
                {
                    ExerciseSetupView(
                        exerciseType: $exerciseType,
                        weight: $weight,
                        exerciseTypes: exerciseTypes,
                        onStartSet: {
                            Task {
                                await sessionManager.startSet(
                                    exerciseType: exerciseType, weight: weight)
                            }
                        }
                    )
                }

                // Live data visualization (when recording)
                if sessionManager.isRecording,
                    !sessionManager.currentSetData.isEmpty
                {
                    LiveDataView(sessionManager: sessionManager)

                    // End set button
                    Button(action: {
                        Task {
                            await sessionManager.endSet()
                        }
                    }) {
                        Text("End Set")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Workout control buttons
                WorkoutControlsView(sessionManager: sessionManager)
            }
            .padding()
            .navigationTitle("Active Workout")
            .alert(
                "Error",
                isPresented: .constant(sessionManager.errorMessage != nil),
                actions: {
                    Button("OK") {
                        sessionManager.errorMessage = nil
                    }
                },
                message: {
                    if let error = sessionManager.errorMessage {
                        Text(error)
                    }
                })
        }
    }
}
