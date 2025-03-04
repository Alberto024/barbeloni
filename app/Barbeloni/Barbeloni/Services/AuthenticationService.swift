import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

// Error types specific to authentication
enum AuthError: Error {
    case signInFailed
    case signUpFailed
    case signOutFailed
    case userNotFound
    case userDataCreationFailed
}

class AuthenticationService: ObservableObject {
    // Published properties for UI binding
    @Published var user: User?
    @Published var authStateDidChange = PassthroughSubject<User?, Error>()

    // Firebase references
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    var cancellables = Set<AnyCancellable>()

    init() {
        setupAuthStateListener()
    }

    // MARK: - Auth State Management

    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }

            if let firebaseUser = firebaseUser {
                Task {
                    do {
                        let user = try await self.fetchUserData(
                            for: firebaseUser.uid)

                        await MainActor.run {
                            self.user = user
                            self.authStateDidChange.send(user)
                        }
                    } catch {
                        await MainActor.run {
                            self.user = nil
                            self.authStateDidChange.send(
                                completion: .failure(error))
                        }
                    }
                }
            } else {
                // No user signed in
                self.user = nil
                self.authStateDidChange.send(nil)
            }
        }
    }

    // MARK: - User Data Management

    /// Fetches user data from Firestore
    func fetchUserData(for userId: String) async throws -> User {
        let docRef = firestore.collection("users").document(userId)

        let document = try await docRef.getDocument()

        if document.exists, let user = try? document.data(as: User.self) {
            return user
        }

        throw AuthError.userNotFound
    }

    /// Saves user data to Firestore
    func saveUserData(_ user: User, userId: String) async throws {
        let docRef = firestore.collection("users").document(userId)

        var userData = user
        userData.id = userId  // Ensure the ID matches the Firebase Auth UID
        try docRef.setData(from: userData)
    }

    // MARK: - Authentication Methods

    /// Signs in a user with email and password
    func signIn(email: String, password: String) async throws {
        do {
            let authResult = try await auth.signIn(
                withEmail: email, password: password)

            // Update last login time
            let userId = authResult.user.uid
            let docRef = firestore.collection("users").document(userId)
            try await docRef.updateData(["lastLoginAt": Date()])
        } catch {
            throw AuthError.signInFailed
        }
    }

    /// Creates a new user account
    func signUp(email: String, password: String, displayName: String? = nil)
        async throws
    {
        do {
            let authResult = try await auth.createUser(
                withEmail: email, password: password)
            let userId = authResult.user.uid

            // Create a user document in Firestore
            let newUser = User.createNew(email: email, name: displayName)
            try await saveUserData(newUser, userId: userId)
        } catch {
            throw AuthError.signUpFailed
        }
    }

    /// Signs out the current user
    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            throw AuthError.signOutFailed
        }
    }

    /// Checks if a user is signed in
    var isUserSignedIn: Bool {
        return auth.currentUser != nil
    }
}
