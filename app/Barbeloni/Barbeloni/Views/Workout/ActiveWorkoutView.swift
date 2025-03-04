import Charts
import SwiftUI

struct ActiveWorkoutView: View {
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
        VStack(spacing: 16) {
            // Connection status
            connectionStatusView

            if case .idle = sessionManager.currentState {
                // Start workout view
                startWorkoutView
            } else {
                // Active workout view
                activeWorkoutContent
            }
        }
        .padding()
        .navigationTitle("Workout")
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
            }
        )
        .alert("End Workout", isPresented: $showingEndWorkoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Workout", role: .destructive) {
                Task {
                    await sessionManager.endWorkout()
                }
            }
        } message: {
            Text(
                "Are you sure you want to end this workout? This action cannot be undone."
            )
        }
    }

    // MARK: - View Components

    private var connectionStatusView: some View {
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
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }

    private var startWorkoutView: some View {
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

    private var activeWorkoutContent: some View {
        VStack(spacing: 20) {
            // Workout stats
            workoutStatsView

            // Exercise setup or live data view
            if sessionManager.isRecording {
                liveDataView

                Button("End Set") {
                    Task {
                        await sessionManager.endSet()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                if showExerciseSetup {
                    exerciseSetupView
                } else {
                    Button("Start New Set") {
                        showExerciseSetup = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()

            // End workout button
            Button("End Workout") {
                showingEndWorkoutConfirmation = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }

    private var workoutStatsView: some View {
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
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }

    private var exerciseSetupView: some View {
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
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }

    private var liveDataView: some View {
        VStack(spacing: 12) {
            Text("Live Sensor Data")
                .font(.headline)

            if sessionManager.currentSetData.count > 1 {
                Chart {
                    // Use all data points in the dataset
                    ForEach(sessionManager.currentSetData.indices, id: \.self) {
                        index in
                        LineMark(
                            x: .value("Time", index),
                            y: .value(
                                "Velocity",
                                sessionManager.currentSetData[index]
                                    .velocityMagnitude())
                        )
                        .foregroundStyle(Color.blue)
                    }
                }
                .frame(height: 160)
                .chartYScale(domain: 0...2.5)
                // No fixed width specified, so it will adapt to the container

                Text(
                    "Total data points: \(sessionManager.currentSetData.count)"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                Text("Waiting for data...")
                    .foregroundColor(.secondary)
                    .frame(height: 160)
            }

            Text("Reps detected: \(sessionManager.repCount)")
                .font(.subheadline)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}
