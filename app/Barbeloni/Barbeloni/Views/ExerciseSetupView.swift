//
//  ExerciseSetupView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import SwiftUI

struct ExerciseSetupView: View {
    @Binding var exerciseType: String
    @Binding var weight: Float
    let exerciseTypes: [String]
    var onStartSet: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Set Up Your Exercise")
                .font(.headline)

            // Simple dropdown using Picker
            HStack {
                Text("Exercise:")
                    .frame(width: 80, alignment: .leading)

                Picker("Select Exercise", selection: $exerciseType) {
                    Text("Select an exercise").tag("")
                    ForEach(exerciseTypes, id: \.self) { exercise in
                        Text(exercise).tag(exercise)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Weight input
            HStack {
                Text("Weight:")
                    .frame(width: 80, alignment: .leading)

                HStack {
                    Button(action: {
                        weight = max(0, weight - 2.5)
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)

                    TextField(
                        "Weight", value: $weight, formatter: NumberFormatter()
                    )
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.center)
                    .frame(width: 60)

                    Text("kg")
                        .foregroundColor(.secondary)

                    Button(action: {
                        weight += 2.5
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.gray))
                .cornerRadius(8)
            }

            // Start set button
            Button(action: onStartSet) {
                Text("Start Set")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(exerciseType.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(exerciseType.isEmpty)
        }
        .padding()
        .background(Color(.gray).opacity(0.5))
        .cornerRadius(12)
    }
}
