//
//  SubscriptionsView.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import SwiftUI

struct SubscriptionsView: View {
    @StateObject var viewModel = SubscriptionsViewModel()
    @EnvironmentObject var appState: AppState
    
    // Access the horizontal size class from the environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var searchText = ""
    @State private var showAddChannelSheet = false

    var filteredSubscriptions: [YouTubeChannel] {
        if searchText.isEmpty {
            return viewModel.subscriptions
        } else {
            return viewModel.subscriptions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List {
            ForEach(filteredSubscriptions) { channel in
                NavigationLink(destination: ChannelVideosView(channelId: channel.id, channelTitle: channel.title, channelDescription: channel.description, channelThumbnailURL: channel.thumbnailURL)) {
                    HStack {
                        AsyncImage(url: channel.thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "person.crop.circle").resizable()
                            default:
                                Color.secondary.opacity(0.2)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(channel.title)
                                .font(.headline)
                            Text(channel.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete(perform: viewModel.deleteChannel)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .onAppear {
            viewModel.loadImportedSubscriptions { _ in }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            // Show toolbar items only when horizontal size class is compact (e.g., iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showAddChannelSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        Menu {
                            Picker("Sort By", selection: $viewModel.sortOption) {
                                ForEach(SubscriptionsViewModel.SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .onChange(of: viewModel.sortOption) { newValue in
                            viewModel.updateSortOption(newValue)
                        }
                        
                        Button(action: {
                            appState.showSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddChannelSheet) {
            AddChannelView(isPresented: $showAddChannelSheet, viewModel: viewModel)
        }
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}

struct AddChannelView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: SubscriptionsViewModel
    
    @State private var query: String = ""
    @State private var searchResults: [YouTubeChannel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Manual ID input
    @State private var manualId: String = ""
    @State private var isAddingManual = false
    
    @State private var showValidationError = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .listRowSeparator(.hidden)
                }
                
                if !searchResults.isEmpty {
                    Section(header: Text("Search Results")) {
                        ForEach(searchResults) { channel in
                            let isSubscribed = viewModel.subscriptions.contains { $0.id == channel.id }
                            Button(action: {
                                if !isSubscribed {
                                    viewModel.addChannel(id: channel.id)
                                    isPresented = false
                                }
                            }) {
                                HStack {
                                    AsyncImage(url: channel.thumbnailURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            Image(systemName: "person.crop.circle").resizable()
                                        default:
                                            Color.secondary.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    
                                    VStack(alignment: .leading) {
                                        Text(channel.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(channel.description)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isSubscribed {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .disabled(isSubscribed)
                        }
                    }
                }
                
                Section(header: Text("Or Add by ID"), footer: Text("Enter a YouTube Channel ID directly (e.g. UC...) if you have it.")) {
                    HStack {
                        TextField("Channel ID", text: $manualId)
                            .autocapitalization(.none)
                        
                        if isAddingManual {
                            ProgressView()
                        } else {
                            Button("Add") {
                                validateAndAddId()
                            }
                            .disabled(manualId.isEmpty)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search YouTube Channels")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: query) { newValue in
                if newValue.isEmpty {
                    searchResults = []
                    errorMessage = nil
                }
            }
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !query.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        
        viewModel.searchYouTubeChannels(query: query) { channels in
            isLoading = false
            if channels.isEmpty {
                errorMessage = "No channels found."
            }
            searchResults = channels
        }
    }
    
    private func validateAndAddId() {
        guard !manualId.isEmpty else { return }
        isAddingManual = true
        errorMessage = nil

        viewModel.validateAndAddChannel(id: manualId) { success in
            isAddingManual = false
            if success {
                isPresented = false
            } else {
                errorMessage = "Channel not found. Please check the ID and try again."
            }
        }
    }
}
