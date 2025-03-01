//
//  WorkoutRowView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import SwiftUI

struct WorkoutRowView: View {
    let workout: WorkoutData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(workout.startTime))
                .font(.headline)
            
            HStack {
                Text("\(workout.sets.count) sets")
                
                if let endTime = workout.endTime {
                    Text("•")
                    Text(formattedDuration(from: workout.startTime, to: endTime))
                } else {
                    Text("• In progress")
                        .foregroundColor(.green)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(from startDate: Date, to endDate: Date) -> String {
        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}
