import SwiftUI

// Main authentication view that shows either sign in or sign up
struct AuthenticationView: View {
    @StateObject private var viewModel: AuthenticationViewModel
    @State private var authMode: AuthMode = .signIn

    // Dependency injection for the view model
    init(authService: AuthenticationService) {
        _viewModel = StateObject(
            wrappedValue: AuthenticationViewModel(authService: authService))
    }

    enum AuthMode {
        case signIn
        case signUp
    }

    var body: some View {
        VStack(spacing: 20) {
            // App logo or header
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text(authMode == .signIn ? "Sign In" : "Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Display error message if any
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }

            // Auth form
            VStack(spacing: 15) {
                // Email field
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                    #endif
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                // Password field
                SecureField("Password", text: $viewModel.password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                // Confirm password field (sign up only)
                if authMode == .signUp {
                    SecureField(
                        "Confirm Password", text: $viewModel.confirmPassword
                    )
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                    // Display name field (sign up only)
                    TextField("Display Name", text: $viewModel.displayName)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                // Sign in/up button
                Button(action: {
                    Task {
                        if authMode == .signIn {
                            await viewModel.signIn()
                        } else {
                            await viewModel.signUp()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.vertical, 10)
                    } else {
                        Text(authMode == .signIn ? "Sign In" : "Sign Up")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(
                    authMode == .signIn
                        ? (viewModel.isSignInFormValid
                            ? Color.blue : Color.gray)
                        : (viewModel.isSignUpFormValid
                            ? Color.blue : Color.gray)
                )
                .cornerRadius(8)
                .disabled(
                    authMode == .signIn
                        ? !viewModel.isSignInFormValid
                        : !viewModel.isSignUpFormValid
                )
                .disabled(viewModel.isLoading)

                // Toggle between sign in and sign up
                Button(action: {
                    viewModel.resetForm()
                    authMode = authMode == .signIn ? .signUp : .signIn
                }) {
                    Text(
                        authMode == .signIn
                            ? "Need an account? Sign Up"
                            : "Already have an account? Sign In"
                    )
                    .foregroundColor(.blue)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
        }
        .padding()
        .frame(maxWidth: 400)
    }
}

// Preview for development
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService()
        AuthenticationView(authService: authService)
    }
}
