//
//  SubscriptionsView.swift
//  SmallTube
//

import SwiftUI

struct SubscriptionsView: View {
    @ObservedObject var viewModel: SubscriptionsViewModel
    @Binding var showAddChannelSheet: Bool

    @State private var searchText = ""
    @State private var channelToDelete: YouTubeChannel?
    @State private var showingDeleteAlert = false

    private var filteredSubscriptions: [YouTubeChannel] {
        searchText.isEmpty
            ? viewModel.subscriptions
            : viewModel.subscriptions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if viewModel.subscriptions.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "No Subscriptions",
                    systemImage: "person.2",
                    description: Text("Tap + to add a channel, or import a CSV in Settings.")
                )
            } else {
                List {
                    ForEach(filteredSubscriptions) { channel in
                        NavigationLink(destination: ChannelVideosView(channel: channel)) {
                            ChannelRowView(channel: channel)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                channelToDelete = channel
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .task { _ = await viewModel.fetchSubscriptions() }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
        .alert("Delete Subscription", isPresented: $showingDeleteAlert, presenting: channelToDelete) { channel in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.removeChannel(id: channel.id)
            }
        } message: { channel in
            Text("Are you sure you want to unsubscribe from \(channel.title)?")
        }
        .sheet(isPresented: $showAddChannelSheet) {
            AddChannelView(isPresented: $showAddChannelSheet, viewModel: viewModel)
        }
    }
}

// MARK: - Channel Row

private struct ChannelRowView: View {
    let channel: YouTubeChannel

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.headline)
                if !channel.description.isEmpty {
                    Text(channel.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Add Channel Sheet

struct AddChannelView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: SubscriptionsViewModel

    @State private var query = ""
    @State private var searchResults: [YouTubeChannel] = []
    @State private var isLoadingSearch = false
    @State private var isAddingManual = false
    @State private var manualId = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                manualSection
                loadingRows
                searchResultsSection
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search YouTube Channels")
            .onSubmit(of: .search) { performSearch() }
            .onChange(of: query) { _, new in
                if new.isEmpty { searchResults = []; errorMessage = nil }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Sub-views (extracted so the type-checker stays fast)

    @ViewBuilder
    private var manualSection: some View {
        Section {
            HStack {
                TextField("Channel ID (UC…)", text: $manualId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if isAddingManual {
                    ProgressView()
                } else {
                    Button("Add") { addManualId() }
                        .disabled(manualId.isEmpty)
                }
            }
        } header: {
            Text("Add by ID")
        } footer: {
            Text("Enter a YouTube Channel ID (e.g. UC…) if you already have it.")
        }
    }

    @ViewBuilder
    private var loadingRows: some View {
        if isLoadingSearch {
            HStack { Spacer(); ProgressView(); Spacer() }
                .listRowSeparator(.hidden)
        }
        if let msg = errorMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if !searchResults.isEmpty {
            Section("Search Results") {
                ForEach(searchResults) { channel in
                    channelRow(channel)
                }
            }
        }
    }

    private func channelRow(_ channel: YouTubeChannel) -> some View {
        let isSubscribed = viewModel.subscriptions.contains { $0.id == channel.id }
        return Button {
            guard !isSubscribed else { return }
            viewModel.addChannel(id: channel.id)
            isPresented = false
        } label: {
            ChannelSearchRowView(channel: channel, isSubscribed: isSubscribed)
        }
        .disabled(isSubscribed)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !query.isEmpty else { return }
        isLoadingSearch = true
        errorMessage = nil
        Task {
            let channels = await viewModel.searchYouTubeChannels(query: query)
            isLoadingSearch = false
            if channels.isEmpty { errorMessage = "No channels found." }
            searchResults = channels
        }
    }

    private func addManualId() {
        let trimmed = manualId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAddingManual = true
        errorMessage = nil
        Task {
            let success = await viewModel.validateAndAddChannel(id: trimmed)
            isAddingManual = false
            if success {
                isPresented = false
            } else {
                errorMessage = "Channel not found. Please check the ID and try again."
            }
        }
    }
}

// MARK: - Channel Search Row (isolated so type-checker handles it separately)

private struct ChannelSearchRowView: View {
    let channel: YouTubeChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(channel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isSubscribed ? "checkmark.circle.fill" : "plus.circle")
                .foregroundStyle(isSubscribed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        }
    }
}
