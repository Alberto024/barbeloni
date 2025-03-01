//
//  FitnessData.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/26/25.
//

import FirebaseFirestore
import Foundation

struct RepData: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let startTime: Date
    let endTime: Date
    let peakAcceleration: [Float]
    let peakVelocity: [Float]
    let peakForce: Float
    let peakPower: Float
}

struct SetData: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let startTime: Date
    var endTime: Date
    let exerciseType: String
    let weight: Float
    var reps: [RepData] = []

    var rawAccelerationVectors: [[Float]]
    var rawVelocityVectors: [[Float]]
    var rawTimestamps: [UInt32]
}

struct WorkoutData: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let startTime: Date
    var endTime: Date?
    var sets: [SetData] = []
    var notes: String?
}
