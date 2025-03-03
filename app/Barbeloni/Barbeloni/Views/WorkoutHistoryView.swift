//
//  WorkoutHistoryView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 3/1/25.
//

import FirebaseAuth
import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject var coordinator: AppCoordinator
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.workouts.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 20) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Workouts Yet")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(
                            "Start your first workout to begin tracking your progress."
                        )
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                        Button(action: {
                            coordinator.navigateTo(.activeWorkout)
                        }) {
                            Text("Start a Workout")
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    }
                    .padding(.vertical, 40)
                } else {
                    List {
                        ForEach(viewModel.workouts) { workout in
                            NavigationLink(
                                destination: WorkoutDetailView(workout: workout)
                            ) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                    }
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                        }
                    }
                    #if os(iOS)
                        .listStyle(.insetGrouped)
                    #endif
                }
            }
            .navigationTitle("Workout History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        coordinator.navigateTo(.activeWorkout)
                    }) {
                        Label("New Workout", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        coordinator.navigateTo(.settings)
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .refreshable {
                await viewModel.loadWorkouts()
            }
        }
        .task {
            await viewModel.loadWorkouts()
        }
    }
}
