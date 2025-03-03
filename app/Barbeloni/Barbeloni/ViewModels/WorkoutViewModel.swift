//
//  WorkoutViewModel.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import Combine
import Foundation

class WorkoutViewModel: ObservableObject {
    private let workoutService = WorkoutDataService()

    @Published var workouts: [WorkoutData] = []
    @Published var currentWorkout: WorkoutData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Workouts

    /// Loads all workouts for the current user
    func loadWorkouts() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let fetchedWorkouts = try await workoutService.fetchWorkouts()
            await MainActor.run {
                self.workouts = fetchedWorkouts
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to load workouts: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Creates a new workout and makes it the current workout
    func startNewWorkout(notes: String? = nil) async {
        await MainActor.run { isLoading = true }

        do {
            let workoutId = try await workoutService.createWorkout(notes: notes)
            // Load the complete workout to get its ID
            let workout = try await workoutService.fetchCompleteWorkout(
                workoutId: workoutId)

            await MainActor.run {
                currentWorkout = workout
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to start workout: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// End the current workout
    func endCurrentWorkout() async {
        guard let workout = currentWorkout, let workoutId = workout.id else {
            await MainActor.run {
                errorMessage = "No active workout to end"
            }
            return
        }

        await MainActor.run { isLoading = true }

        do {
            try await workoutService.updateWorkout(
                workoutId: workoutId, endTime: Date())
            // Refresh workouts list
            await loadWorkouts()

            await MainActor.run {
                currentWorkout = nil
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to end workout: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}
