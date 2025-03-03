//
//  SimpleMainView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 3/2/25.
//

import SwiftUI

struct SimpleMainView: View {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var bluetoothManager = BluetoothManager()

    var body: some View {
        Group {
            if authService.isUserSignedIn {
                MainTabView(
                    authService: authService, bluetoothManager: bluetoothManager
                )
            } else {
                AuthenticationView(authService: authService)
            }
        }
    }
}

struct MainTabView: View {
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var bluetoothManager: BluetoothManager
    @StateObject private var workoutViewModel = WorkoutViewModel()

    var body: some View {
        TabView {
            // History Tab
            NavigationStack {
                WorkoutListView(viewModel: workoutViewModel)
            }
            .tabItem {
                Label("History", systemImage: "list.bullet")
            }

            // Workout Tab
            NavigationStack {
                SimplifiedWorkoutView(bluetoothManager: bluetoothManager)
            }
            .tabItem {
                Label(
                    "Workout",
                    systemImage: "figure.strengthtraining.traditional")
            }

            // Settings Tab
            NavigationStack {
                SimplifiedSettingsView(authService: authService)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

struct WorkoutListView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        List {
            if viewModel.workouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "dumbbell",
                    description: Text(
                        "Start your first workout to begin tracking your progress"
                    )
                )
            } else {
                ForEach(viewModel.workouts) { workout in
                    NavigationLink(
                        destination: WorkoutDetailView(workout: workout)
                    ) {
                        WorkoutRowView(workout: workout)
                    }
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

struct SimplifiedSettingsView: View {
    @ObservedObject var authService: AuthenticationService
    @State private var showingLogoutConfirmation = false

    var body: some View {
        List {
            Section(header: Text("Account")) {
                if let user = authService.user {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Name", value: user.displayName)
                }

                Button(action: {
                    showingLogoutConfirmation = true
                }) {
                    Label(
                        "Sign Out",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                    .foregroundColor(.red)
                }
            }

            Section(header: Text("About")) {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .navigationTitle("Settings")
        .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                do {
                    try authService.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}
