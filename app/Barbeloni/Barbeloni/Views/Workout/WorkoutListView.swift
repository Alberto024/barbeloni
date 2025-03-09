import SwiftUI

struct WorkoutListView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var showingDeleteConfirmation = false
    @State private var workoutToDelete: WorkoutData?

    var body: some View {
        Group {
            if viewModel.workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "dumbbell",
                    description: Text(
                        "Start your first workout to begin tracking your progress"
                    )
                )
            } else {
                List {
                    ForEach(viewModel.workouts) { workout in
                        NavigationLink(
                            destination: WorkoutDetailView(
                                workout: workout,
                                viewModel: viewModel
                            )
                        ) {
                            WorkoutRowView(workout: workout)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                workoutToDelete = workout
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .alert(
                    "Delete Workout", isPresented: $showingDeleteConfirmation
                ) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        if let workout = workoutToDelete {
                            Task {
                                await viewModel.deleteWorkout(
                                    workoutId: workout.id ?? "")
                            }
                        }
                    }
                } message: {
                    Text(
                        "Are you sure you want to delete this workout? This action cannot be undone and will remove all associated sets and reps."
                    )
                }
            }
        }
        .navigationTitle("Workout History")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await viewModel.loadWorkouts()
        }
        .task {
            await viewModel.loadWorkouts()
        }
    }
}

struct WorkoutRowView: View {
    let workout: WorkoutData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(workout.startTime))
                .font(.headline)

            HStack {
                Text("\(workout.sets.count) sets")

                if let endTime = workout.endTime {
                    Text("•")
                    Text(
                        formattedDuration(from: workout.startTime, to: endTime))
                } else {
                    Text("• In progress")
                        .foregroundColor(.green)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
        return "\(minutes) min"
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutData
    @ObservedObject var viewModel: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

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
                .background(Color.secondary.opacity(0.1))
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
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("Delete Workout", systemImage: "trash")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .navigationTitle("Workout Details")
        .alert("Delete Workout", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await viewModel.deleteWorkout(
                        workoutId: workout.id ?? "")
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(
                "Are you sure you want to delete this workout? This action cannot be undone and will remove all associated sets and reps."
            )
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

            Text("Time: \(formattedTime(set.startTime))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
