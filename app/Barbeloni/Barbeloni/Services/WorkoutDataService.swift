//
//  WorkoutDataService.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

class WorkoutDataService: ObservableObject {
    private let firestore = Firestore.firestore()
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Creating Data

    /// Creates a new workout for the current user
    func createWorkout(startTime: Date = Date(), notes: String? = nil)
        async throws -> String
    {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        // Create a new workout document
        let workoutRef = firestore.collection("users").document(userId)
            .collection(
                "workouts"
            ).document()

        let workout = WorkoutData(
            id: workoutRef.documentID,
            userId: userId,
            startTime: startTime,
            endTime: nil,
            sets: [],
            notes: notes
        )

        try workoutRef.setData(from: workout)
        return workoutRef.documentID
    }

    /// Adds a set to an existing workout
    func addSet(to workoutId: String, exerciseType: String, weight: Float)
        async throws -> String
    {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        // Create a new set document in the workout's sets subcollection
        let setRef = firestore.collection("users").document(userId)
            .collection("workouts").document(workoutId)
            .collection("sets").document()

        let now = Date()
        let newSet = SetData(
            id: setRef.documentID,
            userId: userId,
            startTime: now,
            endTime: now,
            exerciseType: exerciseType,
            weight: weight,
            reps: [],
            velocityX: [],
            velocityY: [],
            velocityZ: [],
            accelerationX: [],
            accelerationY: [],
            accelerationZ: [],
            timestamps: []
        )

        try setRef.setData(from: newSet)
        return setRef.documentID
    }

    /// Update a set with raw sensor data
    func updateSetData(
        workoutId: String,
        setId: String,
        endTime: Date,
        rawAccelerationVectors: [[Float]],
        rawVelocityVectors: [[Float]],
        rawTimestamps: [UInt32]
    ) async throws {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        let setRef = firestore.collection("users").document(userId)
            .collection("workouts").document(workoutId)
            .collection("sets").document(setId)

        // Convert 2D arrays to separate arrays for each axis
        var velocityX: [Float] = []
        var velocityY: [Float] = []
        var velocityZ: [Float] = []

        for vector in rawVelocityVectors {
            if vector.count >= 3 {
                velocityX.append(vector[0])
                velocityY.append(vector[1])
                velocityZ.append(vector[2])
            }
        }

        var accelerationX: [Float] = []
        var accelerationY: [Float] = []
        var accelerationZ: [Float] = []

        for vector in rawAccelerationVectors {
            if vector.count >= 3 {
                accelerationX.append(vector[0])
                accelerationY.append(vector[1])
                accelerationZ.append(vector[2])
            }
        }

        // Update the set with the simplified data structure
        let updateData: [String: Any] = [
            "endTime": endTime,
            "velocityX": velocityX,
            "velocityY": velocityY,
            "velocityZ": velocityZ,
            "accelerationX": accelerationX,
            "accelerationY": accelerationY,
            "accelerationZ": accelerationZ,
            "timestamps": rawTimestamps,
        ]

        try await setRef.updateData(updateData)
    }
    /// Adds a rep to an existing set
    func addRep(
        to setId: String, workoutId: String, peakAcceleration: [Float],
        peakVelocity: [Float], peakForce: Float, peakPower: Float
    ) async throws -> String {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        // Create a new rep document in the set's reps subcollection
        let repRef = firestore.collection("users").document(userId)
            .collection("workouts").document(workoutId)
            .collection("sets").document(setId)
            .collection("reps").document()

        let now = Date()
        let newRep = RepData(
            id: repRef.documentID,
            userId: userId,
            startTime: now,
            endTime: now,
            peakAcceleration: peakAcceleration,
            peakVelocity: peakVelocity,
            peakForce: peakForce,
            peakPower: peakPower
        )

        try repRef.setData(from: newRep)
        return repRef.documentID
    }

    // MARK: - Reading Data

    /// Fetches all workouts for the current user
    func fetchWorkouts() async throws -> [WorkoutData] {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        let snapshot = try await firestore.collection("users").document(userId)
            .collection("workouts")
            .order(by: "startTime", descending: true)
            .getDocuments()

        var workouts = [WorkoutData]()
        for document in snapshot.documents {
            let workout = try document.data(as: WorkoutData.self)
            workouts.append(workout)
        }

        return workouts
    }

    /// Fetches a complete workout with all sets and reps
    func fetchCompleteWorkout(workoutId: String) async throws -> WorkoutData {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        // 1. Fetch the workout document
        let workoutDoc = try await firestore.collection("users").document(
            userId
        )
        .collection("workouts").document(workoutId)
        .getDocument()

        var workout = try workoutDoc.data(as: WorkoutData.self)

        // 2. Fetch all sets for this workout
        let setsSnapshot = try await workoutDoc.reference.collection("sets")
            .order(by: "startTime")
            .getDocuments()

        var sets = [SetData]()
        for setDoc in setsSnapshot.documents {
            var set = try setDoc.data(as: SetData.self)

            // 3. Fetch all reps for this set
            let repsSnapshot = try await setDoc.reference.collection("reps")
                .order(by: "startTime")
                .getDocuments()

            var reps = [RepData]()
            for repDoc in repsSnapshot.documents {
                let rep = try repDoc.data(as: RepData.self)
                reps.append(rep)
            }

            // Add reps to the set
            set.reps = reps
            sets.append(set)
        }

        // Add sets to the workout
        workout.sets = sets
        return workout
    }

    // MARK: - Updating Data

    /// Updates a workout with new data
    func updateWorkout(
        workoutId: String, endTime: Date? = nil, notes: String? = nil
    ) async throws {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        let workoutRef = firestore.collection("users").document(userId)
            .collection("workouts").document(workoutId)

        var updateData: [String: Any] = [:]
        if let endTime = endTime {
            updateData["endTime"] = endTime
        }
        if let notes = notes {
            updateData["notes"] = notes
        }

        if !updateData.isEmpty {
            try await workoutRef.updateData(updateData)
        }
    }

    // MARK: - Deleting Data

    /// Deletes a workout and all its associated sets and reps
    func deleteWorkout(workoutId: String) async throws {
        guard let userId = userId else {
            throw FirestoreError.userNotAuthenticated
        }

        let workoutRef = firestore.collection("users").document(userId)
            .collection("workouts").document(workoutId)

        // Fetch all sets to delete their subcollections first
        let setsSnapshot = try await workoutRef.collection("sets")
            .getDocuments()

        for setDoc in setsSnapshot.documents {
            // Delete all reps in the set
            let repsSnapshot = try await setDoc.reference.collection("reps")
                .getDocuments()
            for repDoc in repsSnapshot.documents {
                try await repDoc.reference.delete()
            }

            // Delete the set
            try await setDoc.reference.delete()
        }

        // Finally delete the workout
        try await workoutRef.delete()
    }
}

enum FirestoreError: Error {
    case userNotAuthenticated
    case documentNotFound
    case failedToSaveDocument
    case failedToFetchDocuments
}
