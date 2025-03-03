//
//  HomeView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authService: AuthenticationService

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome, \(authService.user?.displayName ?? "User")!")
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "You are signed in with: \(authService.user?.email ?? "Unknown email")"
                )

                Spacer()

                Button(action: {
                    try? authService.signOut()
                }) {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}
