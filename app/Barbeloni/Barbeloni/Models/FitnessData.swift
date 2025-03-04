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

    // Simplified data structure - separate arrays for each axis
    var velocityX: [Float]
    var velocityY: [Float]
    var velocityZ: [Float]
    var accelerationX: [Float]
    var accelerationY: [Float]
    var accelerationZ: [Float]
    var timestamps: [UInt32]

    // Convert to vector format when needed
    var rawVelocityVectors: [[Float]] {
        var vectors: [[Float]] = []
        for index
            in 0..<min(velocityX.count, min(velocityY.count, velocityZ.count))
        {
            vectors.append([
                velocityX[index], velocityY[index], velocityZ[index],
            ])
        }
        return vectors
    }

    var rawAccelerationVectors: [[Float]] {
        var vectors: [[Float]] = []
        for index
            in 0..<min(
                accelerationX.count,
                min(accelerationY.count, accelerationZ.count))
        {
            vectors.append([
                accelerationX[index], accelerationY[index],
                accelerationZ[index],
            ])
        }
        return vectors
    }
}

struct WorkoutData: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let startTime: Date
    var endTime: Date?
    var sets: [SetData] = []
    var notes: String?

    // Computed properties for statistics
    var totalReps: Int {
        sets.reduce(0) { $0 + $1.reps.count }
    }

    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "In Progress" }

        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}
