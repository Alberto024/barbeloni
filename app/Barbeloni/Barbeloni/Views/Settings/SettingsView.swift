import SwiftUI

struct SettingsView: View {
    @ObservedObject var authService: AuthenticationService
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("Account")) {
                if let user = authService.user {
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Name", value: user.displayName)
                }
                
                Button(action: {
                    showingLogoutConfirmation = true
                }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("About")) {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("App", value: "Barbeloni")
            }
        }
        .navigationTitle("Settings")
        .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                do {
                    try authService.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}
