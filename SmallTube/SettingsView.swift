import SwiftUI
import CommonCrypto

struct SettingsView: View {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("resultsCount") var resultsCount: Int = 10
    @AppStorage("countryCode") var countryCode: String = "US"
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject var countryStore = CountryStore()
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Authentication")) {
                    if let token = authManager.userToken {
                        if let name = authManager.userDisplayName {
                            Text("Signed In: \(name)")
                        } else {
                            // If display name isn't fetched yet, show partial token or a placeholder
                            Text("Signed In: \(token.prefix(10))...")
                        }
                        Button("Sign Out") {
                            authManager.signOut()
                        }
                    } else {
                        Button("Sign In with Google") {
                            authManager.startSignInFlow()
                        }
                    }
                }
                
                Section(header: Text("API Key")) {
                    TextField("Enter API Key", text: $apiKey)
                }
                
                Section(header: Text("Results Count")) {
                    Picker("Results Count", selection: $resultsCount) {
                        ForEach(1...100, id: \.self) {
                            Text("\($0)")
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
                        Text("Selected: \(countryCode)")
                    }
                }
                
                Section {
                    Button("Save") {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Settings")
        }
    }
}
