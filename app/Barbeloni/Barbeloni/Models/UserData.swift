//
//  UserData.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import FirebaseFirestore
import Foundation

// This model represents a user in our application
struct User: Identifiable, Codable {
    // Use @DocumentID to map the Firestore document ID to the id property
    @DocumentID var id: String?

    let email: String
    var displayName: String
    var photoURL: String?
    var createdAt: Date
    var lastLoginAt: Date

    // Add any additional user properties you need
    
    var height: Float?
    var weight: Float?
    var birthDate: Date?
    var gender: String?

    // Custom coding keys if you want the field names in Firestore to be different
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

// You can extend the User model with additional functionality if needed
extension User {
    // Example: A static method to create a new user from Firebase Auth data
    static func createNew(email: String, name: String? = nil) -> User {
        let now = Date()
        return User(
            email: email,
            displayName: name ?? email.components(separatedBy: "@").first ?? "User",
            createdAt: now,
            lastLoginAt: now
        )
    }
}
