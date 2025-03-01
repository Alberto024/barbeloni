//
//  MainCoordinatorView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 3/1/25.
//


import SwiftUI
import FirebaseAuth

struct MainCoordinatorView: View {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some View {
        ZStack {
            switch coordinator.currentScreen {
            case .login:
                AuthenticationView(authService: coordinator.authService)
            case .workoutHistory:
                WorkoutHistoryView(coordinator: coordinator)
            case .activeWorkout:
                ActiveWorkoutView()
                    .environmentObject(coordinator)
            case .settings:
                SettingsView(coordinator: coordinator)
            }
        }
    }
}
