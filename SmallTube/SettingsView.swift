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
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    // State variable to control the display of the file importer
    @State private var showFileImporter = false

    var body: some View {
        Form {
            Section(header: Text("Import Subscriptions")) {
                Text("To import your subscriptions:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("1. Go to takeout.google.com\n2. Deselect all, then select only 'YouTube'\n3. Click 'All YouTube data included' and select only 'subscriptions'\n4. Export and download the zip\n5. Import the 'subscriptions.csv' file here")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                
                Button("Import CSV File") {
                    showFileImporter = true
                }
                
                if !subscriptionManager.subscriptionIds.isEmpty {
                    Text("Imported: \(subscriptionManager.subscriptionIds.count) channels")
                        .foregroundColor(.green)
                    
                    Button("Clear All Subscriptions") {
                        subscriptionManager.clearSubscriptions()
                    }
                    .foregroundColor(.red)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        // Attach the alert to the Form or any parent view
        // Attach the file importer
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile = try result.get().first else { return }
                if subscriptionManager.parseCSV(url: selectedFile) {
                    // Success handling if needed
                }
            } catch {
                print("Error reading file: \(error.localizedDescription)")
            }
        }
    }
}
