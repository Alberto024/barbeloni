import SwiftUI
import FirebaseAuth

enum AppScreen {
    case login
    case workoutHistory
    case activeWorkout
    case settings
}

class AppCoordinator: ObservableObject {
    @Published var currentScreen: AppScreen = .login
    @Published var authService = AuthenticationService()
    
    init() {
        // Set up auth state listener to handle screen transitions
        authService.authStateDidChange
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    print("Auth state change error: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] user in
                self?.handleAuthChange(user: user)
            }
            .store(in: &authService.cancellables)
    }
    
    private func handleAuthChange(user: User?) {
        // If user is logged in, go to workout history, otherwise to login
        if user != nil {
            self.currentScreen = .workoutHistory
        } else {
            self.currentScreen = .login
        }
    }
    
    // Navigation functions
    func navigateTo(_ screen: AppScreen) {
        currentScreen = screen
    }
}
