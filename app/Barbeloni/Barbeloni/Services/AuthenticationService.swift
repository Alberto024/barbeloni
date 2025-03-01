import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

// Error types specific to our authentication process
enum AuthError: Error {
    case signInFailed
    case signUpFailed
    case signOutFailed
    case userNotFound
    case userDataCreationFailed
}

// This service handles all Firebase authentication operations
class AuthenticationService: ObservableObject {
    // Published properties that the UI can observe
    @Published var user: User?
    @Published var authStateDidChange = PassthroughSubject<User?, Error>()
    
    // Firebase references
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    // Make this internal so AppCoordinator can access it
    var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up a listener for authentication state changes
        setupAuthStateListener()
    }
    
    // MARK: - Firebase Auth Listener
    
    private func setupAuthStateListener() {
        // Listen for auth state changes from Firebase
        auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            // If we have a Firebase user, fetch their data from Firestore
            if let firebaseUser = firebaseUser {
                Task {
                    do {
                        let user = try await self.fetchUserData(for: firebaseUser.uid)
                        
                        // Update on the main thread since we're changing published properties
                        await MainActor.run {
                            self.user = user
                            self.authStateDidChange.send(user)
                        }
                    } catch {
                        print("Error fetching user data: \(error.localizedDescription)")
                        await MainActor.run {
                            self.user = nil
                            self.authStateDidChange.send(completion: .failure(error))
                        }
                    }
                }
            } else {
                // No user is signed in
                self.user = nil
                self.authStateDidChange.send(nil)
            }
        }
    }
    
    // MARK: - User Data Management
    
    /// Fetches user data from Firestore based on the user ID
    func fetchUserData(for userId: String) async throws -> User {
        let docRef = db.collection("users").document(userId)
        
        do {
            // Try to get the document
            let document = try await docRef.getDocument()
            
            // If the document exists, try to decode it as a User
            if document.exists {
                if let user = try? document.data(as: User.self) {
                    return user
                }
            }
            
            // If we get here, either the document doesn't exist or couldn't be decoded
            throw AuthError.userNotFound
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Saves user data to Firestore
    func saveUserData(_ user: User, userId: String) async throws {
        let docRef = db.collection("users").document(userId)
        
        do {
            // Save the user data to Firestore
            var userData = user
            userData.id = userId // Ensure the ID matches the Firebase Auth UID
            try docRef.setData(from: userData)
        } catch {
            print("Error saving user data: \(error.localizedDescription)")
            throw AuthError.userDataCreationFailed
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Signs in a user with email and password
    func signIn(email: String, password: String) async throws {
        do {
            // Attempt to sign in with Firebase Auth
            let authResult = try await auth.signIn(withEmail: email, password: password)
            
            // Update the last login time in Firestore
            let userId = authResult.user.uid
            // Since authResult.user.uid is a String (not optional), we can use it directly
            let docRef = db.collection("users").document(userId)
            try await docRef.updateData(["last_login_at": Date()])
        } catch {
            print("Sign in failed: \(error.localizedDescription)")
            throw AuthError.signInFailed
        }
    }
    
    /// Creates a new user account and saves their data to Firestore
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        do {
            // Create the user with Firebase Auth
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // Create a user document in Firestore
            let newUser = User.createNew(email: email, name: displayName)
            try await saveUserData(newUser, userId: userId)
        } catch {
            print("Sign up failed: \(error.localizedDescription)")
            throw AuthError.signUpFailed
        }
    }
    
    /// Signs out the current user
    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            print("Sign out failed: \(error.localizedDescription)")
            throw AuthError.signOutFailed
        }
    }
    
    /// Checks if a user is currently signed in
    var isUserSignedIn: Bool {
        return auth.currentUser != nil
    }
}
