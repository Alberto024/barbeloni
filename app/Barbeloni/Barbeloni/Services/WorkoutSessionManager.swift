// WorkoutSessionManager.swift
import Combine
import Foundation

enum WorkoutState {
    case idle
    case workoutActive(workoutId: String)
    case setActive(
        workoutId: String, setId: String, exerciseType: String, weight: Float)
}

class WorkoutSessionManager: ObservableObject {
    // Published properties for UI binding
    @Published var currentState: WorkoutState = .idle
    @Published var isRecording = false
    @Published var currentSetData: [SensorTimepoint] = []
    @Published var errorMessage: String?

    // Workout metadata
    @Published var exerciseType: String = ""
    @Published var weight: Float = 0

    // Statistics
    @Published var setCount: Int = 0
    @Published var repCount: Int = 0

    // Services
    private let workoutDataService = WorkoutDataService()
    private let bluetoothManager: BluetoothManager

    // Subscriptions
    private var cancellables = Set<AnyCancellable>()

    // Rep detection
    private var isInRep = false
    private var repStartIndex = 0
    private let velocityThreshold: Float = 0.1
    private let accelerationThreshold: Float = 0.5

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager

        // Subscribe to sensor data updates
        bluetoothManager.$sensorTimepoint
            .compactMap { $0 }
            .sink { [weak self] timepoint in
                self?.processSensorData(timepoint)
            }
            .store(in: &cancellables)

        // Monitor connection status
        bluetoothManager.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.stopRecordingIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Workout Management

    func startWorkout() async {
        guard bluetoothManager.isConnected else {
            await MainActor.run {
                errorMessage = "Bluetooth device not connected"
            }
            return
        }

        do {
            let workoutId = try await workoutDataService.createWorkout()
            await MainActor.run {
                currentState = .workoutActive(workoutId: workoutId)
                setCount = 0
                repCount = 0
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to start workout: \(error.localizedDescription)"
            }
        }
    }

    func endWorkout() async {
        // Handle ending a set if one is active
        if case .setActive = currentState {
            await endSet()
        }

        // Get the workout ID if available
        guard case .workoutActive(let workoutId) = currentState else {
            return
        }

        do {
            try await workoutDataService.updateWorkout(
                workoutId: workoutId, endTime: Date())
            await MainActor.run {
                currentState = .idle
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to end workout: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Set Management

    func startSet(exerciseType: String, weight: Float) async {
        // Ensure we're in a workout
        guard case .workoutActive(let workoutId) = currentState else {
            await MainActor.run {
                errorMessage = "No active workout"
            }
            return
        }

        // Ensure device is connected
        guard bluetoothManager.isConnected else {
            await MainActor.run {
                errorMessage = "Bluetooth device not connected"
            }
            return
        }

        do {
            let setId = try await workoutDataService.addSet(
                to: workoutId, exerciseType: exerciseType, weight: weight)

            await MainActor.run {
                self.exerciseType = exerciseType
                self.weight = weight
                currentState = .setActive(
                    workoutId: workoutId,
                    setId: setId,
                    exerciseType: exerciseType,
                    weight: weight
                )

                // Reset data collection
                currentSetData = []
                isInRep = false

                // Start recording
                isRecording = true
                setCount += 1
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to start set: \(error.localizedDescription)"
            }
        }
    }

    func endSet() async {
        await MainActor.run {
            stopRecordingIfNeeded()
        }

        // Ensure we have an active set
        guard case .setActive(let workoutId, let setId, _, _) = currentState,
            !currentSetData.isEmpty
        else {
            await MainActor.run {
                if case .workoutActive(let workoutId) = currentState {
                    currentState = .workoutActive(workoutId: workoutId)
                } else {
                    currentState = .idle
                }
            }
            return
        }

        // Process data for storage
        var velocityX: [Float] = []
        var velocityY: [Float] = []
        var velocityZ: [Float] = []
        var accelerationX: [Float] = []
        var accelerationY: [Float] = []
        var accelerationZ: [Float] = []
        var timestamps: [UInt32] = []

        for point in currentSetData {
            velocityX.append(point.velocity.0)
            velocityY.append(point.velocity.1)
            velocityZ.append(point.velocity.2)
            accelerationX.append(point.acceleration.0)
            accelerationY.append(point.acceleration.1)
            accelerationZ.append(point.acceleration.2)
            timestamps.append(point.timestamp)
        }

        do {
            // Convert to 2D arrays for the service
            let velocityVectors = zip(zip(velocityX, velocityY), velocityZ).map
            {
                [Float($0.0.0), Float($0.0.1), Float($0.1)]
            }
            let accelerationVectors = zip(
                zip(accelerationX, accelerationY), accelerationZ
            ).map {
                [Float($0.0.0), Float($0.0.1), Float($0.1)]
            }

            try await workoutDataService.updateSetData(
                workoutId: workoutId,
                setId: setId,
                endTime: Date(),
                rawAccelerationVectors: accelerationVectors,
                rawVelocityVectors: velocityVectors,
                rawTimestamps: timestamps
            )

            await MainActor.run {
                currentState = .workoutActive(workoutId: workoutId)
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to save set data: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Data Processing

    private func processSensorData(_ timepoint: SensorTimepoint) {
        guard isRecording else { return }

        // Add data point to our collection
        currentSetData.append(timepoint)

        // Detect reps in real-time
        detectRep(at: currentSetData.count - 1)
    }

    private func detectRep(at index: Int) {
        guard currentSetData.count > index else { return }

        let timepoint = currentSetData[index]
        let velocityMagnitude = timepoint.velocityMagnitude()
        let accelerationMagnitude = timepoint.accelerationMagnitude()

        // Simple rep detection algorithm
        if !isInRep && velocityMagnitude > velocityThreshold
            && accelerationMagnitude > accelerationThreshold
        {
            // Start of a rep
            isInRep = true
            repStartIndex = index
        } else if isInRep && velocityMagnitude < velocityThreshold {
            // End of a rep
            isInRep = false

            // Ensure the rep lasted long enough to be counted (not just noise)
            if index - repStartIndex > 5 {
                processCompletedRep(startIndex: repStartIndex, endIndex: index)
            }
        }
    }

    private func processCompletedRep(startIndex: Int, endIndex: Int) {
        // Find peak values during the rep
        var peakVelocity: [Float] = [0, 0, 0]
        var peakAcceleration: [Float] = [0, 0, 0]
        var peakVelocityMagnitude: Float = 0
        var peakAccelerationMagnitude: Float = 0

        for index in startIndex...endIndex {
            let timepoint = currentSetData[index]

            let velocityArr = [
                timepoint.velocity.0,
                timepoint.velocity.1,
                timepoint.velocity.2,
            ]
            let velocityMag = timepoint.velocityMagnitude()
            if velocityMag > peakVelocityMagnitude {
                peakVelocityMagnitude = velocityMag
                peakVelocity = velocityArr
            }

            let accelArr = [
                timepoint.acceleration.0,
                timepoint.acceleration.1,
                timepoint.acceleration.2,
            ]
            let accelMag = timepoint.accelerationMagnitude()
            if accelMag > peakAccelerationMagnitude {
                peakAccelerationMagnitude = accelMag
                peakAcceleration = accelArr
            }
        }

        // Calculate force and power (simplified)
        let peakForce = weight * peakAccelerationMagnitude
        let peakPower = peakForce * peakVelocityMagnitude

        // Save rep data
        Task {
            if case .setActive(let workoutId, let setId, _, _) = currentState {
                do {
                    _ = try await workoutDataService.addRep(
                        to: setId,
                        workoutId: workoutId,
                        peakAcceleration: peakAcceleration,
                        peakVelocity: peakVelocity,
                        peakForce: peakForce,
                        peakPower: peakPower
                    )

                    await MainActor.run {
                        repCount += 1
                    }
                } catch {
                    print("Failed to save rep: \(error.localizedDescription)")
                }
            }
        }
    }

    private func stopRecordingIfNeeded() {
        if isRecording {
            isRecording = false
            isInRep = false
        }
    }
}
