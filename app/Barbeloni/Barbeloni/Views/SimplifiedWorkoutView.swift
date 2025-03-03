//
//  SimplifiedWorkoutView.swift
//  Barbeloni
//

import Charts
import SwiftUI

struct SimplifiedWorkoutView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @StateObject private var sessionManager: WorkoutSessionManager

    @State private var exerciseType = ""
    @State private var weight: Float = 20.0
    @State private var isWorkoutActive = false
    @State private var showExerciseSetup = false
    @State private var showingEndWorkoutConfirmation = false

    // Exercise type options
    let exerciseTypes = [
        "Squat", "Bench Press", "Deadlift", "Shoulder Press", "Row",
    ]

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        _sessionManager = StateObject(
            wrappedValue: WorkoutSessionManager(
                bluetoothManager: bluetoothManager))
    }

    var body: some View {
        VStack {
            // Connection status card
            connectionStatusCard

            if isWorkoutActive {
                // Active workout view
                VStack(spacing: 20) {
                    // Current workout stats
                    workoutStatsCard

                    // Exercise data input or live data view
                    if sessionManager.isRecording {
                        LiveDataView(sessionManager: sessionManager)

                        Button("End Set") {
                            Task {
                                await sessionManager.endSet()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    } else {
                        if showExerciseSetup {
                            exerciseSetupCard
                        } else {
                            Button("New Set") {
                                showExerciseSetup = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }

                    Spacer()

                    // End workout button
                    Button("End Workout") {
                        showingEndWorkoutConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .padding(.bottom, 16)
                }
                .padding()
                .alert(
                    "End Workout", isPresented: $showingEndWorkoutConfirmation
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("End Workout", role: .destructive) {
                        Task {
                            await sessionManager.endWorkout()
                            isWorkoutActive = false
                        }
                    }
                } message: {
                    Text(
                        "Are you sure you want to end this workout? This action cannot be undone."
                    )
                }

            } else {
                // Start workout view
                VStack {
                    Spacer()

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding()

                    Text("Ready to start a workout?")
                        .font(.title2)
                        .padding()

                    Button("Start Workout") {
                        Task {
                            await sessionManager.startWorkout()
                            isWorkoutActive = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!bluetoothManager.isConnected)

                    if !bluetoothManager.isConnected {
                        Text("Connect your device first")
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    Spacer()
                }
            }
        }
        .navigationTitle("Workout")
        .alert(isPresented: .constant(sessionManager.errorMessage != nil)) {
            Alert(
                title: Text("Error"),
                message: Text(
                    sessionManager.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK")) {
                    sessionManager.errorMessage = nil
                }
            )
        }
    }

    // MARK: - View Components

    private var connectionStatusCard: some View {
        HStack {
            Image(
                systemName: bluetoothManager.isConnected
                    ? "bluetooth.connected" : "bluetooth.slash"
            )
            .foregroundColor(bluetoothManager.isConnected ? .blue : .red)

            Text(bluetoothManager.statusMessage)
                .font(.subheadline)

            Spacer()

            Button(bluetoothManager.isConnected ? "Disconnect" : "Connect") {
                if bluetoothManager.isConnected {
                    bluetoothManager.disconnect()
                } else {
                    bluetoothManager.startScanning()
                }
            }
            .buttonStyle(.borderless)
            .foregroundColor(bluetoothManager.isConnected ? .gray : .blue)
        }
        .padding()
        .background(Color(.gray))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var workoutStatsCard: some View {
        VStack(spacing: 8) {
            if case .setActive(_, _, let exerciseType, let weight) =
                sessionManager.currentState
            {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Exercise")
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
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(sessionManager.setCount)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Total Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(sessionManager.repCount)")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color(.gray))
        .cornerRadius(10)
    }

    private var exerciseSetupCard: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Exercise")
                .font(.headline)

            Picker("Exercise", selection: $exerciseType) {
                Text("Select Exercise").tag("")
                ForEach(exerciseTypes, id: \.self) { exercise in
                    Text(exercise).tag(exercise)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Text("Weight (kg):")

                Stepper(
                    "\(weight, specifier: "%.1f")", value: $weight, in: 0...500,
                    step: 2.5)
            }

            HStack {
                Button("Cancel") {
                    showExerciseSetup = false
                }
                .buttonStyle(.bordered)

                Button("Start Set") {
                    Task {
                        await sessionManager.startSet(
                            exerciseType: exerciseType, weight: weight)
                        showExerciseSetup = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(exerciseType.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.gray))
        .cornerRadius(10)
    }
}
