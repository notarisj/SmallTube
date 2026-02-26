import SwiftUI
import LocalAuthentication

struct APIKeySettingsView: View {
    // Master state for this view, synced with AppPreferences
    @State private var apiKey: String = AppPreferences.apiKey
    @State private var apiKeyNames = AppPreferences.apiKeyNames
    @State private var apiQuotaUsage = AppPreferences.apiQuotaUsage
    @State private var apiQuotaLimits = AppPreferences.apiQuotaLimits
    
    @State private var newApiKey = ""
    @State private var showAddKeyAlert = false
    
    @State private var validationStatuses: [String: Bool] = [:]
    @State private var isValidatingAll = false
    
    private var currentKeys: [String] {
        apiKey.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    var body: some View {
        List {
            Section {
                if currentKeys.isEmpty {
                    ContentUnavailableView("No API Keys", systemImage: "key", description: Text("Add a YouTube Data API key to get started."))
                } else {
                    ForEach(currentKeys, id: \.self) { key in
                        NavigationLink {
                            APIKeyDetailView(
                                key: key,
                                name: Binding(
                                    get: { apiKeyNames[key] ?? "" },
                                    set: { apiKeyNames[key] = $0 }
                                ),
                                usage: Binding(
                                    get: { apiQuotaUsage[key] ?? 0 },
                                    set: { apiQuotaUsage[key] = $0 }
                                ),
                                limit: Binding(
                                    get: { apiQuotaLimits[key] ?? 10000 },
                                    set: { apiQuotaLimits[key] = $0 }
                                ),
                                onKeyRenamed: { oldKey, newKey in
                                    handleKeyRename(from: oldKey, to: newKey)
                                }
                            )
                        } label: {
                            APIKeyListRow(
                                name: apiKeyNames[key] ?? "",
                                used: apiQuotaUsage[key] ?? 0,
                                limit: apiQuotaLimits[key] ?? 10000,
                                isValid: validationStatuses[key]
                            )
                        }
                    }
                    .onDelete(perform: deleteKeys)
                }
            } header: {
                Text("Your Keys")
            } footer: {
                if !currentKeys.isEmpty {
                    Text("The app rotates keys automatically. Swipe left to delete a key.")
                }
            }
            
            if !currentKeys.isEmpty {
                Section {
                    Button {
                        validateAllKeys()
                    } label: {
                        HStack {
                            Text("Validate All Keys")
                            Spacer()
                            if isValidatingAll {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isValidatingAll)
                }
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddKeyAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add API Key", isPresented: $showAddKeyAlert) {
            TextField("Paste Key Here", text: $newApiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newApiKey = "" }
            Button("Add") { addNewKey() }
        } message: {
            Text("Enter a YouTube Data API v3 key string.")
        }
        .onAppear {
            syncFromPreferences()
        }
        // Save back to preferences whenever our local state changes
        .onChange(of: apiKey) { AppPreferences.apiKey = apiKey }
        .onChange(of: apiKeyNames) { AppPreferences.apiKeyNames = apiKeyNames }
        .onChange(of: apiQuotaUsage) { AppPreferences.apiQuotaUsage = apiQuotaUsage }
        .onChange(of: apiQuotaLimits) { AppPreferences.apiQuotaLimits = apiQuotaLimits }
    }
    
    private func syncFromPreferences() {
        apiKey = AppPreferences.apiKey
        apiKeyNames = AppPreferences.apiKeyNames
        apiQuotaUsage = AppPreferences.apiQuotaUsage
        apiQuotaLimits = AppPreferences.apiQuotaLimits
    }
    
    private func handleKeyRename(from oldKey: String, to newKey: String) {
        var keys = currentKeys
        if let index = keys.firstIndex(of: oldKey) {
            keys[index] = newKey
            apiKey = keys.joined(separator: ",")
            
            // Move associated data
            if let name = apiKeyNames.removeValue(forKey: oldKey) {
                apiKeyNames[newKey] = name
            }
            if let usage = apiQuotaUsage.removeValue(forKey: oldKey) {
                apiQuotaUsage[newKey] = usage
            }
            if let limit = apiQuotaLimits.removeValue(forKey: oldKey) {
                apiQuotaLimits[newKey] = limit
            }
            if let status = validationStatuses.removeValue(forKey: oldKey) {
                validationStatuses[newKey] = status
            }
        }
    }
    
    private func validateAllKeys() {
        let keys = currentKeys
        guard !keys.isEmpty else { return }
        
        isValidatingAll = true
        validationStatuses.removeAll()
        
        Task {
            await withTaskGroup(of: (String, Bool).self) { group in
                for key in keys {
                    group.addTask {
                        do {
                            let url = URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&q=YouTube&maxResults=1&type=video&key=\(key)")!
                            let (data, _) = try await URLSession.shared.data(from: url)
                            let isValid = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] == nil
                            return (key, isValid)
                        } catch {
                            return (key, false)
                        }
                    }
                }
                
                for await (key, isValid) in group {
                    validationStatuses[key] = isValid
                }
            }
            isValidatingAll = false
        }
    }
    
    private func addNewKey() {
        let trimmed = newApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var keys = currentKeys
        if !keys.contains(trimmed) {
            keys.append(trimmed)
            apiKey = keys.joined(separator: ",")
        }
        newApiKey = ""
    }
    
    private func deleteKeys(at offsets: IndexSet) {
        var keys = currentKeys
        for index in offsets {
            let keyToRemove = keys[index]
            apiKeyNames.removeValue(forKey: keyToRemove)
            apiQuotaUsage.removeValue(forKey: keyToRemove)
            apiQuotaLimits.removeValue(forKey: keyToRemove)
            validationStatuses.removeValue(forKey: keyToRemove)
        }
        keys.remove(atOffsets: offsets)
        apiKey = keys.joined(separator: ",")
    }
}

// MARK: - List Row View

private struct APIKeyListRow: View {
    let name: String
    let used: Int
    let limit: Int
    let isValid: Bool?
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Untitled Key" : name)
                    .font(.headline)
                
                Text("\(used) / \(limit) units")
                    .font(.caption)
                    .foregroundStyle(used >= limit ? .red : .secondary)
            }
            
            Spacer()
            
            if let isValid {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isValid ? .green : .red)
            }
            
            let safeLimit = max(1, limit)
            ProgressView(value: min(Double(used), Double(safeLimit)), total: Double(safeLimit))
                .frame(width: 40)
                .progressViewStyle(.linear)
                .tint(used >= safeLimit ? .red : (Double(used) > Double(safeLimit) * 0.8 ? .orange : .accentColor))
        }
    }
}

// MARK: - Detail View

struct APIKeyDetailView: View {
    let key: String
    @Binding var name: String
    @Binding var usage: Int
    @Binding var limit: Int
    var onKeyRenamed: (String, String) -> Void
    
    @State private var editableKey: String = ""
    @State private var showPlainKey = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Name")
                    Spacer(minLength: 16)
                    TextField("Untitled Key", text: $name)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("API Key")
                    Spacer(minLength: 16)
                    if showPlainKey {
                        TextField("Key String", text: $editableKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(1)
                            .onChange(of: editableKey) { old, new in
                                let trimmedNew = new.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedNew.isEmpty && trimmedNew != key {
                                    onKeyRenamed(key, trimmedNew)
                                }
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = editableKey
                                } label: {
                                    Label("Copy Key", systemImage: "doc.on.doc")
                                }
                            }
                    } else {
                        HStack(spacing: 4) {
                            Text("••••••••••••••••")
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            authenticateToReveal()
                        }
                    }
                }
            } header: {
                Text("Identity")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    let safeLimit = max(1, limit)
                    ProgressView(value: min(Double(usage), Double(safeLimit)), total: Double(safeLimit))
                        .tint(usage >= safeLimit ? .red : (Double(usage) > Double(safeLimit) * 0.8 ? .orange : .accentColor))
                    
                    HStack {
                        Text("Usage:")
                            .font(.subheadline)
                        TextField("Usage", value: $usage, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        
                        Spacer()
                        
                        Text("Limit:")
                            .font(.subheadline)
                        TextField("Limit", value: $limit, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            } header: {
                Text("Quota")
            } footer: {
                Text("Usage is an estimate tracked locally and resets at midnight PT.")
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if showPlainKey {
                    Button {
                        UIPasteboard.general.string = editableKey
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                
                Button {
                    if showPlainKey {
                        showPlainKey = false
                    } else {
                        authenticateToReveal()
                    }
                } label: {
                    Image(systemName: showPlainKey ? "eye.slash" : "eye")
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onAppear {
            editableKey = key
        }
    }
    
    private func authenticateToReveal() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock to view API Key") { success, _ in
                DispatchQueue.main.async {
                    if success { withAnimation { self.showPlainKey = true } }
                }
            }
        } else {
            withAnimation { self.showPlainKey = true }
        }
    }
}
