//
//  SettingsView.swift
//  SmallTube
//

import SwiftUI
import OSLog

struct SettingsView: View {
    @State private var apiKeyCount: Int = AppPreferences.apiKeys.count
    @AppStorage("resultsCount") private var resultsCount: Int = 10
    @AppStorage("homeFeedChannelCount") private var homeFeedChannelCount: Int = 15
    @AppStorage("countryCode")  private var countryCode: String = "US"
    @AppStorage("autoplay")     private var autoplay: Bool = true
    @AppStorage("thumbnailQuality") private var thumbnailQuality: ThumbnailQuality = .high
    @AppStorage("cacheTimeout") private var cacheTimeout: CacheTimeout = .fiveMinutes
    @AppStorage("totalDataBytesUsed") private var totalDataBytesUsed: Int = 0
    @State private var totalApiQuotaUsed: Int = AppPreferences.totalApiQuotaUsed

    @Environment(\.dismiss) private var dismiss

    @State private var countryStore = CountryStore()
    @State private var showFileImporter = false
    @State private var showImportInstructions = false
    @State private var showClearConfirmation = false
    @State private var showResetTrackingConfirmation = false
    @State private var showApiKeyInstructions = false

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        Form {
            subscriptionsSection
            apiConfigurationSection
            homeFeedSection
            preferencesSection
            usageSection
        }
        .onAppear {
            apiKeyCount = AppPreferences.apiKeys.count
            totalApiQuotaUsed = AppPreferences.totalApiQuotaUsed
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            totalApiQuotaUsed = AppPreferences.totalApiQuotaUsed
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            "Clear Subscriptions",
            isPresented: $showClearConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                subscriptionManager.clearSubscriptions()
            }
        } message: {
            Text("This will remove all imported subscriptions and cannot be undone.")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                _ = subscriptionManager.parseCSV(url: url)
            case .failure(let error):
                AppLogger.ui.error("File importer error: \(error.localizedDescription, privacy: .public)")
            }
        }
        .sheet(isPresented: $showImportInstructions) {
            InstructionSheet(title: "Import Guide", steps: [
                InstructionStep(1, "Go to Google Takeout in your browser.", link: ("Open Google Takeout", "https://takeout.google.com")),
                InstructionStep(2, "Deselect all, then select only 'YouTube'."),
                InstructionStep(3, "Tap 'All YouTube data included', deselect all, select 'subscriptions'."),
                InstructionStep(4, "Tap 'Next step' → 'Create export'. Wait for the download link."),
                InstructionStep(5, "Download and unzip. Find 'subscriptions.csv'."),
                InstructionStep(6, "Return here and tap 'Import CSV File'.")
            ])
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

    // MARK: - Sections

    @ViewBuilder
    private var subscriptionsSection: some View {
        Section {
            Button {
                showImportInstructions = true
            } label: {
                Label("How to Import from YouTube", systemImage: "questionmark.circle")
            }

            Button {
                showFileImporter = true
            } label: {
                Label("Import CSV File", systemImage: "square.and.arrow.down")
            }

            if !subscriptionManager.subscriptionIds.isEmpty {
                HStack {
                    Label {
                        Text("Imported")
                    } icon: {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(subscriptionManager.subscriptionIds.count) channels")
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear All Subscriptions", systemImage: "trash")
                }
            }
        } header: {
            Text("Subscriptions")
        }
    }

    private var currentKeysCount: Int {
        apiKeyCount
    }

    @ViewBuilder
    private var apiConfigurationSection: some View {
        Section("API Configuration") {
            Button {
                showApiKeyInstructions = true
            } label: {
                Label("How to Get an API Key", systemImage: "questionmark.circle")
            }

            NavigationLink {
                APIKeySettingsView()
            } label: {
                HStack {
                    Label("API Keys", systemImage: "key.fill")
                    Spacer()
                    Text("\(currentKeysCount)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var homeFeedSection: some View {
        Section("Home Feed") {
            Picker("Channels to Mix", selection: $homeFeedChannelCount) {
                ForEach(5...100, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            NavigationLink {
                FavoriteChannelsView()
            } label: {
                Label("Favorite Channels", systemImage: "star.fill")
            }
        }
    }

    @ViewBuilder
    private var usageSection: some View {
        Section {
            HStack {
                Text("API Quota Used")
                Spacer()
                Text("\(totalApiQuotaUsed)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Data Used")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(totalDataBytesUsed), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                showResetTrackingConfirmation = true
            } label: {
                Text("Reset Tracking")
            }
            .alert(
                "Reset Tracking",
                isPresented: $showResetTrackingConfirmation
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    AppPreferences.apiQuotaUsage = [:]
                    totalApiQuotaUsed = 0
                    totalDataBytesUsed = 0
                }
            } message: {
                Text("Are you sure you want to reset all data usage and API quota tracking statistics?")
            }
        } header: {
            Text("Usage")
        } footer: {
            Text("Data usage is only calculated for API requests, not video playback.")
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Autoplay Videos", isOn: $autoplay)

            Picker("Results per Request", selection: $resultsCount) {
                ForEach(1...100, id: \.self) { count in
                    Text("\(count)")
                }
            }

            Picker("Thumbnail Quality", selection: $thumbnailQuality) {
                ForEach(ThumbnailQuality.allCases) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            }

            Picker("Cache Refresh Timeout", selection: $cacheTimeout) {
                ForEach(CacheTimeout.allCases) { timeout in
                    Text(timeout.title).tag(timeout)
                }
            }

            NavigationLink {
                CountryPickerView(selected: $countryCode, countries: countryStore.countries)
            } label: {
                HStack {
                    Text("Country")
                    Spacer()
                    Text(countryCode)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

}

// MARK: - Country Picker (searchable full-screen list)

private struct CountryPickerView: View {
    @Binding var selected: String
    let countries: [Country]
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""

    private var filtered: [Country] {
        search.isEmpty ? countries : countries.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            $0.code.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(filtered) { country in
            Button {
                selected = country.code
                dismiss()
            } label: {
                HStack {
                    Text(country.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(country.code)
                        .foregroundStyle(.secondary)
                    if country.code == selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Country")
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
    }
}

// MARK: - Instruction Sheet

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
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.number)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.accentColor))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.text)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)

                            if let link = step.link, let url = URL(string: link.url) {
                                Link(link.title, destination: url)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
