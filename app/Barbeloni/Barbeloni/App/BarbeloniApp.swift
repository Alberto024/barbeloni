//
//  BarbeloniApp.swift
//  Barbeloni
//
//  Created by Alberto Nava on 2/28/25.
//

import Firebase
import SwiftUI

@main
struct BarbeloniApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SimpleMainView()
        }
    }
}
