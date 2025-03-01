//
//  BarbeloniApp.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import SwiftUI
import Firebase

@main
struct BarbeloniApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainCoordinatorView()
        }
    }
}
