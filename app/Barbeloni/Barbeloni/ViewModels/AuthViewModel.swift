//
//  AuthViewModel.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import Combine
import Foundation

// Authentication view model to handle UI state for login and signup
class AuthenticationViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    // Reference to the authentication service
    private let authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthenticationService) {
        self.authService = authService

        // Listen for authentication state changes from the service
        authService.authStateDidChange
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { user in
                self.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Form Validation

    var isSignInFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    var isSignUpFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6 && password == confirmPassword
            && !displayName.isEmpty
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    func signIn() async {
        guard isSignInFormValid else {
            errorMessage = "Please enter a valid email and password (at least 6 characters)"
            return
        }

        await MainActor.run { isLoading = true }

        do {
            try await authService.signIn(email: email, password: password)
            await MainActor.run {
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    /// Create a new account with email and password
    func signUp() async {
        guard isSignUpFormValid else {
            errorMessage = "Please check your form details"
            return
        }

        await MainActor.run { isLoading = true }

        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
            await MainActor.run {
                isLoading = false
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Sign up failed: \(error.localizedDescription)"
            }
        }
    }

    /// Sign out the current user
    func signOut() {
        do {
            try authService.signOut()
            // Reset form fields after signing out
            email = ""
            password = ""
            confirmPassword = ""
            displayName = ""
            errorMessage = nil
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    /// Reset the form and error state
    func resetForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
    }
}
