//
//  WorkoutSessionManager.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import Foundation
import Combine
import SwiftUI

enum WorkoutSessionState {
    case idle
    case workoutActive(workoutId: String)
    case setActive(workoutId: String, setId: String, exerciseType: String, weight: Float)
}

class WorkoutSessionManager: ObservableObject {
    // Published properties for UI binding
    @Published var currentState: WorkoutSessionState = .idle
    @Published var isRecording = false
    @Published var currentSetData: [SensorTimepoint] = []
    @Published var errorMessage: String?
    
    // Set metadata
    @Published var exerciseType: String = ""
    @Published var weight: Float = 0
    
    // Workout statistics
    @Published var setCount: Int = 0
    @Published var repCount: Int = 0
    
    // Services
    private let workoutDataService = WorkoutDataService()
    private let bluetoothManager: BluetoothManager
    
    // Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Timestamps
    private var setStartTime: Date?
    private var lastRepEndTime: Date?
    
    // For rep detection algorithm
    private var isInRep = false
    private var repStartIndex = 0
    private var velocityThreshold: Float = 0.1  // m/s - minimum velocity to consider a rep started
    private var accelerationThreshold: Float = 0.5  // m/s² - minimum acceleration to consider a rep started
    
    // Current workout and set IDs
    private var currentWorkoutId: String?
    private var currentSetId: String?
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Subscribe to sensor data updates
        bluetoothManager.$sensorTimepoint
            .compactMap { $0 }  // Filter out nil values
            .sink { [weak self] timepoint in
                self?.processSensorData(timepoint)
            }
            .store(in: &cancellables)
            
        // Subscribe to connection status
        bluetoothManager.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    // Reset recording if disconnected
                    self?.stopRecordingIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Workout Management
    
    /// Start a new workout session
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
                currentWorkoutId = workoutId
                currentState = .workoutActive(workoutId: workoutId)
                setCount = 0
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to start workout: \(error.localizedDescription)"
            }
        }
    }
    
    /// End the current workout
    func endWorkout() async {
        guard case .workoutActive(let workoutId) = currentState else {
            if case .setActive = currentState {
                // If a set is active, end it first
                await endSet()
            }
            return
        }
        
        do {
            try await workoutDataService.updateWorkout(workoutId: workoutId, endTime: Date())
            await MainActor.run {
                currentWorkoutId = nil
                currentState = .idle
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to end workout: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Set Management
    
    /// Start a new set with the given exercise type and weight
    func startSet(exerciseType: String, weight: Float) async {
        // Ensure we're in a workout
        guard case .workoutActive(let workoutId) = currentState else {
            await MainActor.run {
                errorMessage = "No active workout"
            }
            return
        }
        
        // Ensure the device is connected
        guard bluetoothManager.isConnected else {
            await MainActor.run {
                errorMessage = "Bluetooth device not connected"
            }
            return
        }
        
        do {
            let setId = try await workoutDataService.addSet(to: workoutId, exerciseType: exerciseType, weight: weight)
            
            await MainActor.run {
                // Update state
                currentSetId = setId
                self.exerciseType = exerciseType
                self.weight = weight
                currentState = .setActive(workoutId: workoutId, setId: setId, exerciseType: exerciseType, weight: weight)
                
                // Reset data collection
                currentSetData = []
                repCount = 0
                isInRep = false
                
                // Start recording
                isRecording = true
                setStartTime = Date()
                setCount += 1
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to start set: \(error.localizedDescription)"
            }
        }
    }
    
    /// End the current set and save data to Firestore
    func endSet() async {
        // Stop recording first
        await MainActor.run {
            stopRecordingIfNeeded()
        }
        
        // Ensure we have an active set
        guard case .setActive(let workoutId, let setId, _, _) = currentState,
              !currentSetData.isEmpty else {
            await MainActor.run {
                currentState = .workoutActive(workoutId: currentWorkoutId ?? "")
            }
            return
        }
        
        // Process the collected data
        let (accelerationVectors, velocityVectors, timestamps) = processSetData()
        
        do {
            // Update the set data in Firestore
            try await workoutDataService.updateSetData(
                workoutId: workoutId,
                setId: setId,
                endTime: Date(),
                rawAccelerationVectors: accelerationVectors,
                rawVelocityVectors: velocityVectors,
                rawTimestamps: timestamps
            )
            
            await MainActor.run {
                currentSetId = nil
                currentState = .workoutActive(workoutId: workoutId)
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save set data: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Data Processing
    
    /// Process incoming sensor data
    private func processSensorData(_ timepoint: SensorTimepoint) {
        guard isRecording else { return }
        
        // Add data point to our collection
        currentSetData.append(timepoint)
        
        // Detect reps in real-time
        detectRep(at: currentSetData.count - 1)
    }
    
    /// Detect if a rep has occurred
    private func detectRep(at index: Int) {
        guard currentSetData.count > index else { return }
        
        let timepoint = currentSetData[index]
        
        // Calculate magnitude of velocity vector
        let velocityMagnitude = calculateMagnitude(timepoint.velocity)
        let accelerationMagnitude = calculateMagnitude(timepoint.acceleration)
        
        // Simple rep detection: Look for movement starting (crossing threshold)
        if !isInRep && velocityMagnitude > velocityThreshold && accelerationMagnitude > accelerationThreshold {
            // Start of a rep
            isInRep = true
            repStartIndex = index
        }
        // Look for movement ending (dropping below threshold)
        else if isInRep && velocityMagnitude < velocityThreshold {
            // End of a rep
            isInRep = false
            
            // Ensure the rep lasted long enough to be counted (not just noise)
            if index - repStartIndex > 5 { // Arbitrary minimum number of data points
                processCompletedRep(startIndex: repStartIndex, endIndex: index)
            }
        }
    }
    
    /// Process a completed rep and save to Firestore
    private func processCompletedRep(startIndex: Int, endIndex: Int) {
        // Calculate peak metrics for this rep
        var peakVelocity: [Float] = [0, 0, 0]
        var peakAcceleration: [Float] = [0, 0, 0]
        var peakVelocityMagnitude: Float = 0
        var peakAccelerationMagnitude: Float = 0
        
        for i in startIndex...endIndex {
            let timepoint = currentSetData[i]
            
            let velocityMag = calculateMagnitude(timepoint.velocity)
            if velocityMag > peakVelocityMagnitude {
                peakVelocityMagnitude = velocityMag
                peakVelocity = timepoint.velocity
            }
            
            let accelMag = calculateMagnitude(timepoint.acceleration)
            if accelMag > peakAccelerationMagnitude {
                peakAccelerationMagnitude = accelMag
                peakAcceleration = timepoint.acceleration
            }
        }
        
        // Calculate force and power (simplified)
        // Force = mass × acceleration
        let peakForce = weight * peakAccelerationMagnitude
        
        // Power = force × velocity
        let peakPower = peakForce * peakVelocityMagnitude
        
        // Save rep data to Firestore asynchronously
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
                        lastRepEndTime = Date()
                    }
                } catch {
                    print("Failed to save rep: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Process all the set data at the end of a set
    private func processSetData() -> (accelerationVectors: [[Float]], velocityVectors: [[Float]], timestamps: [UInt32]) {
        var accelerationVectors: [[Float]] = []
        var velocityVectors: [[Float]] = []
        var timestamps: [UInt32] = []
        
        for timepoint in currentSetData {
            accelerationVectors.append(timepoint.acceleration)
            velocityVectors.append(timepoint.velocity)
            timestamps.append(timepoint.timestamp)
        }
        
        return (accelerationVectors, velocityVectors, timestamps)
    }
    
    // MARK: - Helper Methods
    
    /// Stop recording if currently recording
    private func stopRecordingIfNeeded() {
        if isRecording {
            isRecording = false
            isInRep = false
        }
    }
    
    /// Calculate the magnitude of a vector
    private func calculateMagnitude(_ vector: [Float]) -> Float {
        guard vector.count >= 3 else { return 0 }
        return sqrt(vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2])
    }
}
