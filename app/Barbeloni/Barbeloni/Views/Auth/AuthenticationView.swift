import SwiftUI

struct AuthenticationView: View {
    @StateObject private var viewModel: AuthViewModel
    @State private var isSignUp = false

    init(authService: AuthenticationService) {
        _viewModel = StateObject(
            wrappedValue: AuthViewModel(authService: authService))
    }

    var body: some View {
        VStack(spacing: 20) {
            // App logo
            Image(systemName: "figure.strengthtraining.traditional")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Show error message if any
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                    .multilineTextAlignment(.center)
            }

            // Auth form
            VStack(spacing: 15) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                    #endif
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                SecureField("Password", text: $viewModel.password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                if isSignUp {
                    SecureField(
                        "Confirm Password", text: $viewModel.confirmPassword
                    )
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)

                    TextField("Display Name", text: $viewModel.displayName)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }

                // Sign in/up button
                Button(action: {
                    Task {
                        if isSignUp {
                            await viewModel.signUp()
                        } else {
                            await viewModel.signIn()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.vertical, 10)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .background(
                    isSignUp
                        ? (viewModel.isSignUpFormValid
                            ? Color.blue : Color.gray)
                        : (viewModel.isSignInFormValid
                            ? Color.blue : Color.gray)
                )
                .cornerRadius(8)
                .disabled(
                    isSignUp
                        ? !viewModel.isSignUpFormValid
                        : !viewModel.isSignInFormValid
                )
                .disabled(viewModel.isLoading)

                // Toggle between sign in and sign up
                Button(action: {
                    viewModel.resetForm()
                    isSignUp.toggle()
                }) {
                    Text(
                        isSignUp
                            ? "Already have an account? Sign In"
                            : "Need an account? Sign Up"
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
