//
//  SettingsView.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import SwiftUI
import CommonCrypto

struct SettingsView: View {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("resultsCount") var resultsCount: Int = 10
    @AppStorage("countryCode") var countryCode: String = "US"
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject var countryStore = CountryStore()
    @EnvironmentObject var authManager: AuthManager
    
    // State variable to control the display of the sign-out confirmation alert
    @State private var showSignOutAlert = false

    var body: some View {
        Form {
            Section(header: Text("User Authentication")) {
                if let token = authManager.userToken {
                    if let name = authManager.userDisplayName {
                        Text("Signed In: \(name)")
                    } else {
                        // If display name isn't fetched yet, show partial token or a placeholder
                        Text("Signed In: \(token.prefix(10))...")
                    }
                    // Update the Sign Out button to show the confirmation alert
                    Button("Sign Out") {
                        showSignOutAlert = true
                    }
                    .foregroundColor(.red) // Optional: Make the sign-out button red to indicate caution
                } else {
                    Button("Sign In with Google") {
                        authManager.startSignInFlow()
                    }
                }
            }
            
            Section(header: Text("API Key")) {
                TextField("Enter API Key", text: $apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            Section(header: Text("Results Count")) {
                Picker("Results Count", selection: $resultsCount) {
                    ForEach(1...100, id: \.self) { count in
                        Text("\(count)")
                    }
                }
            }
            
            Section(header: Text("Country Code")) {
                Menu {
                    ForEach(countryStore.countries) { country in
                        Button(country.name) {
                            countryCode = country.code
                        }
                    }
                } label: {
                    HStack {
                        Text("Selected: \(countryCode)")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Save button removed as changes are autosaved via @AppStorage
        }
        .navigationTitle("Settings")
        // Attach the alert to the Form or any parent view
        .alert(isPresented: $showSignOutAlert) {
            Alert(
                title: Text("Confirm Sign Out"),
                message: Text("Are you sure you want to sign out?"),
                primaryButton: .destructive(Text("Yes")) {
                    authManager.signOut()
                },
                secondaryButton: .cancel(Text("No"))
            )
        }
    }
}
