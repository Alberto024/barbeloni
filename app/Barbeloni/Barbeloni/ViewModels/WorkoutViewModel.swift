import Foundation

class WorkoutViewModel: ObservableObject {
    private let workoutService = WorkoutDataService()

    @Published var workouts: [WorkoutData] = []
    @Published var currentWorkout: WorkoutData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Workout Management

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

    /// Loads a specific workout with all its details
    func loadWorkoutDetails(workoutId: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let workout = try await workoutService.fetchCompleteWorkout(
                workoutId: workoutId)
            await MainActor.run {
                self.currentWorkout = workout
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to load workout details: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    /// Deletes a workout
    func deleteWorkout(workoutId: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            try await workoutService.deleteWorkout(workoutId: workoutId)
            await loadWorkouts()  // Refresh the list
            await MainActor.run {
                isLoading = false
            }
            return true
        } catch {
            await MainActor.run {
                errorMessage =
                    "Failed to delete workout: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
}
