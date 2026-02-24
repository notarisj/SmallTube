import SwiftUI
import LocalAuthentication

struct APIKeySettingsView: View {
    @State private var apiKey: String = AppPreferences.apiKey
    
    @State private var showApiKeyInstructions = false
    @State private var showApiKey = false
    @State private var newApiKey = ""
    @State private var isValidating = false
    @State private var validationStatuses: [Int: Bool] = [:]
    
    private var currentKeys: [String] {
        apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        Form {
            Section {
                ForEach(Array(currentKeys.enumerated()), id: \.offset) { index, key in
                    apiKeyRow(index: index, key: key, keys: currentKeys)
                }
                
                addKeyRow
            } header: {
                Text("API Keys")
            } footer: {
                Text("The app will automatically rotate to the next key if the quota is exceeded.")
            }
            
            Section {
                testKeysRow(keys: currentKeys)
            }
            
            Section {
                Button {
                    showApiKeyInstructions = true
                } label: {
                    Text("How to Get an API Key")
                }
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if showApiKey {
                        withAnimation { showApiKey = false }
                    } else {
                        authenticateToReveal()
                    }
                } label: {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                }
            }
        }
        .onChange(of: apiKey) { AppPreferences.apiKey = apiKey }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            showApiKey = false
        }
        .sheet(isPresented: $showApiKeyInstructions) {
            InstructionSheet(title: "API Key Guide", steps: [
                InstructionStep(1, "Go to Google Cloud Console.", link: ("Open Console", "https://console.cloud.google.com/")),
                InstructionStep(2, "Create or select a project."),
                InstructionStep(3, "Search 'YouTube Data API v3' in the library and enable it."),
                InstructionStep(4, "Go to Credentials → Create Credentials → API Key."),
                InstructionStep(5, "Copy the API key."),
                InstructionStep(6, "Paste it into the field above.")
            ])
        }
    }
    
    private func apiKeyRow(index: Int, key: String, keys: [String]) -> some View {
        HStack {
            Text("Key \(index + 1)")
                .layoutPriority(1)

            Spacer()

            HStack(spacing: 8) {
                if showApiKey {
                    TextField("", text: apiKeyBinding(index: index))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .onChange(of: keys[index]) { validationStatuses[index] = nil }
                } else {
                    Text("••••••••••••••••")
                        .foregroundColor(.secondary)
                }

                if let isValid = validationStatuses[index] {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isValid ? .green : .red)
                        .font(.body)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                var current = keys
                current.remove(at: index)
                apiKey = current.joined(separator: ",")
                validationStatuses.removeAll()
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private var addKeyRow: some View {
        HStack {
            Group {
                if showApiKey {
                    TextField("Add New Key", text: $newApiKey)
                } else {
                    SecureField("Add New Key", text: $newApiKey)
                        .textContentType(.password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: newApiKey) { validationStatuses.removeAll() }
            .onSubmit { addNewKey() }

            if !newApiKey.isEmpty {
                Spacer()
                Button {
                    addNewKey()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func testKeysRow(keys: [String]) -> some View {
        Button {
            Task { await validateApiKey() }
        } label: {
            HStack {
                Text("Test API Keys")
                Spacer()
                if isValidating {
                    ProgressView()
                } else if !validationStatuses.isEmpty {
                    let allValid = validationStatuses.values.count == keys.count && validationStatuses.values.allSatisfy { $0 }
                    if allValid {
                        Text("Verified")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Issues Found")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .disabled(keys.isEmpty || isValidating)
    }

    private func apiKeyBinding(index: Int) -> Binding<String> {
        Binding(
            get: {
                let keys = apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                return index < keys.count ? keys[index] : ""
            },
            set: { newValue in
                var keys = apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if index < keys.count {
                    keys[index] = newValue
                    apiKey = keys.joined(separator: ",")
                    validationStatuses[index] = nil
                }
            }
        )
    }

    private func validateApiKey() async {
        let keys = apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !keys.isEmpty else { return }
        
        isValidating = true
        validationStatuses.removeAll()

        await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, key) in keys.enumerated() {
                group.addTask {
                    do {
                        let url = URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&q=YouTube&maxResults=1&type=video&key=\(key)")!
                        let (data, _) = try await URLSession.shared.data(from: url)
                        let isValid = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] == nil
                        return (index, isValid)
                    } catch {
                        return (index, false)
                    }
                }
            }

            for await (index, isValid) in group {
                validationStatuses[index] = isValid
            }
        }
        
        isValidating = false
    }

    private func addNewKey() {
        let trimmed = newApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var keys = apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !keys.contains(trimmed) {
            keys.append(trimmed)
            apiKey = keys.joined(separator: ",")
            validationStatuses.removeAll()
        }
        newApiKey = ""
    }

    private func authenticateToReveal() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock to view API Keys") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        withAnimation { self.showApiKey = true }
                    }
                }
            }
        } else {
            // Fallback if no biometrics or passcode is set up
            withAnimation { self.showApiKey = true }
        }
    }
}
