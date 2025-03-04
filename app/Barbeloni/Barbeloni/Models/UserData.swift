import FirebaseFirestore
import Foundation

struct User: Identifiable, Codable {
    @DocumentID var id: String?

    let email: String
    var displayName: String
    var photoURL: String?
    var createdAt: Date
    var lastLoginAt: Date

    // Optional user profile data
    var height: Float?
    var weight: Float?
    var birthDate: Date?
    var gender: String?

    // Custom coding keys for Firestore field names
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case photoURL = "photo_url"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case height
        case weight
        case birthDate = "birth_date"
        case gender
    }
}

// Extension for utility methods
extension User {
    // Create a new user from authentication data
    static func createNew(email: String, name: String? = nil) -> User {
        let now = Date()
        return User(
            email: email,
            displayName: name ?? email.components(separatedBy: "@").first
                ?? "User",
            createdAt: now,
            lastLoginAt: now
        )
    }
}
