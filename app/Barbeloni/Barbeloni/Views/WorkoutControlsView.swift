//
//  WorkoutControlsView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//


import SwiftUI
import Charts

struct WorkoutControlsView: View {
    @ObservedObject var sessionManager: WorkoutSessionManager
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack {
            if case .idle = sessionManager.currentState {
                // Start workout button
                Button(action: {
                    Task {
                        await sessionManager.startWorkout()
                    }
                }) {
                    Text("Start Workout")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                // End workout button
                Button(action: {
                    showingConfirmation = true
                }) {
                    Text("End Workout")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .alert("End Workout", isPresented: $showingConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("End Workout", role: .destructive) {
                        Task {
                            await sessionManager.endWorkout()
                        }
                    }
                } message: {
                    Text("Are you sure you want to end this workout? This action cannot be undone.")
                }
            }
        }
    }
}