//
//  ContentView.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthenticationService()

    var body: some View {
        Group {
            if authService.isUserSignedIn {
                HomeView(authService: authService)
            } else {
                AuthenticationView(authService: authService)
            }
        }
    }
}
