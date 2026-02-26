import SwiftUI
import LocalAuthentication

struct APIKeySettingsView: View {
    @State private var apiKey: String = AppPreferences.apiKey
    
    @State private var showApiKey = false
    @State private var newApiKey = ""
    @State private var isValidating = false
    @State private var validationStatuses: [Int: Bool] = [:]
    @State private var apiQuotaUsage: [String: Int] = AppPreferences.apiQuotaUsage
    @State private var apiKeyNames: [String: String] = AppPreferences.apiKeyNames
    
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("The app will automatically rotate to the next key if the quota is exceeded.")
                    Text("API usage is an estimate tracked locally. Quotas reset locally at midnight Pacific Time.")
                }
            }
            
            Section {
                testKeysRow(keys: currentKeys)
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
        .onChange(of: apiKeyNames) { AppPreferences.apiKeyNames = apiKeyNames }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            showApiKey = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            apiQuotaUsage = AppPreferences.apiQuotaUsage
            apiKeyNames = AppPreferences.apiKeyNames
        }
    }
    
    private func nameBinding(for key: String, index: Int) -> Binding<String> {
        Binding(
            get: {
                apiKeyNames[key] ?? "Key \(index + 1)"
            },
            set: { newValue in
                if newValue.isEmpty {
                    apiKeyNames.removeValue(forKey: key)
                } else {
                    apiKeyNames[key] = newValue
                }
            }
        )
    }

    private func apiKeyRow(index: Int, key: String, keys: [String]) -> some View {
        let used = apiQuotaUsage[key] ?? 0
        let limit = 10000

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Key \(index + 1)", text: nameBinding(for: key, index: index))
                    .lineLimit(1)

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
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(Double(used), Double(limit)), total: Double(limit))
                    .tint(used >= limit ? .red : (used > 8000 ? .orange : .accentColor))
                
                HStack {
                    Text("Quota Usage")
                    Spacer()
                    Text("\(used) / 10,000")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
