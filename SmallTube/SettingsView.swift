//
//  SettingsView.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import SwiftUI
import OSLog

struct SettingsView: View {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("resultsCount") var resultsCount: Int = 10
    @AppStorage("countryCode") var countryCode: String = "US"
    
    @Environment(\.dismiss) private var dismiss
    @StateObject var countryStore = CountryStore()
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    // State variable to control the display of the file importer
    @State private var showFileImporter = false
    
    // Instruction Sheets State
    @State private var showImportInstructions = false
    @State private var showApiKeyInstructions = false
    
    // Alert State
    @State private var showClearConfirmation = false
    
    // API Key State
    @State private var showApiKey = false
    
    // API Key Validation State
    @State private var isValidating = false
    @State private var validationResult: Bool? = nil // nil = not tested, true = valid, false = invalid
    @State private var validationMessage: String = ""

    var body: some View {
        Form {
            // MARK: - Import Section
            Section(header: Text("Subscriptions")) {
                Button(action: { showImportInstructions = true }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                        Text("How to import from YouTube")
                            .foregroundColor(.primary)
                    }
                }
                
                Button(action: { showFileImporter = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                        Text("Import CSV File")
                            .foregroundColor(.primary)
                    }
                }
                
                if !subscriptionManager.subscriptionIds.isEmpty {
                    HStack {
                        Text("Imported")
                        Spacer()
                        Text("\(subscriptionManager.subscriptionIds.count) channels")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Text("Clear All Subscriptions")
                            .foregroundColor(.red)
                    }
                    .alert(isPresented: $showClearConfirmation) {
                        Alert(
                            title: Text("Clear Subscriptions"),
                            message: Text("Are you sure you want to remove all imported subscriptions? This action cannot be undone."),
                            primaryButton: .destructive(Text("Clear All")) {
                                subscriptionManager.clearSubscriptions()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            
            // MARK: - API Key Section
            Section(header: Text("API Configuration")) {
                Button(action: { showApiKeyInstructions = true }) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        Text("How to get an API Key")
                            .foregroundColor(.primary)
                    }
                }
                
                HStack {
                    if showApiKey {
                        TextField("Enter API Key", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter API Key", text: $apiKey)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .foregroundColor(.blue)
                    }
                }
                .onChange(of: apiKey) { _ in
                    validationResult = nil
                    validationMessage = ""
                }
                
                HStack {
                    Button(action: validateApiKey) {
                        if isValidating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Test API Key")
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                    
                    if let result = validationResult {
                        Spacer()
                        if result {
                            Label("Valid", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Invalid", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                

            }
            
            Section(header: Text("Preferences")) {
                Picker("Results Count", selection: $resultsCount) {
                    ForEach(1...100, id: \.self) { count in
                        Text("\(count)")
                    }
                }
                
                Menu {
                    ForEach(countryStore.countries) { country in
                        Button(country.name) {
                            countryCode = country.code
                        }
                    }
                } label: {
                    HStack {
                        Text("Country")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(countryCode)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedFile = urls.first else { return }
                _ = subscriptionManager.parseCSV(url: selectedFile)
            case .failure(let error):
                AppLogger.ui.error("File importer error: \(error.localizedDescription, privacy: .public)")
            }
        }
        .sheet(isPresented: $showImportInstructions) {
            InstructionSheet(title: "Import Guide", steps: [
                InstructionStep(1, "Go to Google Takeout in your browser.", link: ("Open Google Takeout", "https://takeout.google.com")),
                InstructionStep(2, "Deselect all products, then scroll down and select only 'YouTube'."),
                InstructionStep(3, "Click 'All YouTube data included' button, deselect all, and select ONLY 'subscriptions'."),
                InstructionStep(4, "Click 'Next step', then 'Create export'. Wait for the email or download link."),
                InstructionStep(5, "Download and unzip the file. Look for 'subscriptions.csv'."),
                InstructionStep(6, "Return here and tap 'Import CSV File' to select that file.")
            ])
        }
        .sheet(isPresented: $showApiKeyInstructions) {
            InstructionSheet(title: "API Key Guide", steps: [
                InstructionStep(1, "Go to the Google Cloud Console.", link: ("Open Console", "https://console.cloud.google.com/")),
                InstructionStep(2, "Create a new project (or select an existing one)."),
                InstructionStep(3, "Search for 'YouTube Data API v3' in the library and enable it."),
                InstructionStep(4, "Go to 'Credentials' -> 'Create Credentials' -> 'API Key'."),
                InstructionStep(5, "Copy the API Key."),
                InstructionStep(6, "Paste certain key into the field in Settings.")
            ])
        }
    }
    
    private func validateApiKey() {
        guard !apiKey.isEmpty else { return }
        
        isValidating = true
        validationResult = nil
        validationMessage = ""
        
        // Simple test request: Search for "YouTube"
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=YouTube&maxResults=1&type=video&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            isValidating = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isValidating = false
                
                if let error = error {
                    self.validationResult = false
                    self.validationMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.validationResult = false
                    self.validationMessage = "Invalid response from server."
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    self.validationResult = true
                    self.validationMessage = "" 
                } else {
                    self.validationResult = false
                    self.validationMessage = ""
                }
            }
        }.resume()
    }
}

// Simple error response model for validation
struct YouTubeErrorResponse: Decodable {
    let error: YouTubeErrorDetail
}

struct YouTubeErrorDetail: Decodable {
    let message: String
}

// MARK: - Helper Views & Models

struct InstructionStep: Identifiable {
    let id = UUID()
    let number: Int
    let text: String
    let link: (title: String, url: String)?
    
    init(_ number: Int, _ text: String, link: (String, String)? = nil) {
        self.number = number
        self.text = text
        self.link = link
    }
}

struct InstructionSheet: View {
    let title: String
    let steps: [InstructionStep]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 15) {
                        Text("\(step.number)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.blue))
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(step.text)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let link = step.link, let url = URL(string: link.url) {
                                Link(link.title, destination: url)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
