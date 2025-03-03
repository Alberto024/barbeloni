//
//  WorkoutDetailView.swift
//  Barbeloni
//

import SwiftUI

struct WorkoutDetailView: View {
    let workout: WorkoutData
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutService = WorkoutDataService()
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header information
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(workout.startTime))
                        .font(.headline)

                    if let endTime = workout.endTime {
                        Text(
                            "Duration: \(formattedDuration(from: workout.startTime, to: endTime))"
                        )
                        .font(.subheadline)
                    } else {
                        Text("Status: In Progress")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }

                    if let notes = workout.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .font(.body)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.gray))
                .cornerRadius(10)

                // Sets data
                Text("Sets")
                    .font(.title2)
                    .padding(.top)

                if workout.sets.isEmpty {
                    Text("No sets recorded for this workout")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(workout.sets) { set in
                        SetCardView(set: set)
                    }
                }

                // Delete Workout Button
                Button(
                    role: .destructive,
                    action: {
                        showingDeleteConfirmation = true
                    }
                ) {
                    Label("Delete Workout", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.gray))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
                .disabled(isDeleting)
                .padding(.top, 24)
            }
            .padding()
            .overlay {
                if isDeleting {
                    ProgressView("Deleting...")
                        .padding()
                        .background(Color(.gray))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
            }
        }
        .navigationTitle("Workout Details")
        .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text(
                "Are you sure you want to delete this workout? This action cannot be undone."
            )
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDuration(from startDate: Date, to endDate: Date)
        -> String
    {
        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes) min \(seconds) sec"
    }

    private func deleteWorkout() {
        guard let workoutId = workout.id else {
            errorMessage = "Could not find workout ID"
            showingErrorAlert = true
            return
        }

        isDeleting = true

        Task {
            do {
                try await workoutService.deleteWorkout(workoutId: workoutId)

                // Return to the workout list screen
                await MainActor.run {
                    isDeleting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage =
                        "Failed to delete workout: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct SetCardView: View {
    let set: SetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(set.exerciseType)
                    .font(.headline)
                Spacer()
                Text("\(set.weight, specifier: "%.1f") kg")
                    .font(.subheadline)
            }

            Text("Reps: \(set.reps.count)")
                .font(.subheadline)

            // Time info
            Text("Time: \(formattedTime(set.startTime))")
                .font(.caption)
                .foregroundColor(.secondary)

            // Add visualization if needed
            if !set.rawAccelerationVectors.isEmpty {
                Text(
                    "Data collected: \(set.rawAccelerationVectors.count) points"
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.gray))
        .cornerRadius(8)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
