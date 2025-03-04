import SwiftUI

struct ContentView: View {
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
            // Workout Tab
            NavigationStack {
                ActiveWorkoutView(bluetoothManager: bluetoothManager)
            }
            .tabItem {
                Label(
                    "Workout",
                    systemImage: "figure.strengthtraining.traditional")
            }

            // History Tab
            NavigationStack {
                WorkoutListView(viewModel: workoutViewModel)
            }
            .tabItem {
                Label("History", systemImage: "list.bullet")
            }

            // Settings Tab
            NavigationStack {
                SettingsView(authService: authService)
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
