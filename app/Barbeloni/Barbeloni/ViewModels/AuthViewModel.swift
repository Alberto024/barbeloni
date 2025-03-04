import Combine
import Foundation

class AuthViewModel: ObservableObject {
    // Form fields
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""

    // UI state
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    // Service
    private let authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthenticationService) {
        self.authService = authService

        // Listen for auth state changes
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

    // Form validation
    var isSignInFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    var isSignUpFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
            && password == confirmPassword && !displayName.isEmpty
    }

    // Authentication methods
    func signIn() async {
        guard isSignInFormValid else {
            errorMessage = "Please enter a valid email and password"
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

    func signUp() async {
        guard isSignUpFormValid else {
            errorMessage = "Please check your form details"
            return
        }

        await MainActor.run { isLoading = true }

        do {
            try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
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

    func resetForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
    }
}
