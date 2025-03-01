//
//  SettingsView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//


import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Account")) {
                    if let user = coordinator.authService.user {
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Name", value: user.displayName)
                    }
                    
                    Button(action: {
                        showingLogoutConfirmation = true
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("App Settings")) {
                    NavigationLink(destination: Text("Bluetooth Settings")) {
                        Label("Bluetooth", systemImage: "bluetooth")
                    }
                    
                    NavigationLink(destination: Text("Units Settings")) {
                        Label("Units", systemImage: "ruler")
                    }
                }
                
                Section(header: Text("About")) {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                // Use .navigation instead of .navigationBarLeading for cross-platform
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        coordinator.navigateTo(.workoutHistory)
                    }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    do {
                        try coordinator.authService.signOut()
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}