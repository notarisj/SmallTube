//
//  SearchView.swift
//  SmallTube
//
//  Created for SmallTube.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = YouTubeViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.isSearching) private var isSearching
    
    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var isShowingResults = false
    
    var body: some View {
        Group {
            if isShowingResults && !viewModel.videos.isEmpty {
                resultsList
            } else if isShowingResults && viewModel.videos.isEmpty {
                emptyStateView
            } else {
                initialSearchView
            }
        }
        .navigationTitle(isShowingResults ? (submittedQuery.isEmpty ? "Search" : submittedQuery) : "Search")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search videos")
        .onChange(of: isSearching) { searching in
            if !searching && searchText.isEmpty {
                isShowingResults = false
            }
        }
        .onSubmit(of: .search) {
            performSearch(query: searchText)
        }
        .searchSuggestions {
            searchSuggestionsView
        }
        .toolbar {
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { appState.showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
    }
    
    // MARK: - Subviews
    
    private var resultsList: some View {
        List(viewModel.videos) { video in
            NavigationLink(destination: VideoPlayerView(video: video)) {
                VideoRowView(video: video)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Results for \"\(submittedQuery)\"")
                .font(.title3.weight(.semibold))
            
            Text("Try a different search term.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var initialSearchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
            
            Text("Search SmallTube")
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var searchSuggestionsView: some View {
        if searchText.isEmpty && !viewModel.lastSearches.isEmpty {
            Section {
                ForEach(viewModel.lastSearches, id: \.self) { historyItem in
                    Button {
                        searchText = historyItem
                        performSearch(query: historyItem)
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text(historyItem)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.removeSearch(historyItem)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button("Clear") {
                        viewModel.clearAllSearches()
                    }
                    .font(.caption)
                    .textCase(nil)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        submittedQuery = trimmed
        isShowingResults = true
        viewModel.searchVideos(query: trimmed)
        dismissSearch()
    }
}

// MARK: - Helper Views

struct VideoRowView: View {
    let video: CachedYouTubeVideo
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.secondary.opacity(0.1)
                        Image(systemName: "video.fill")
                            .foregroundColor(.secondary)
                    }
                default:
                    Color.secondary.opacity(0.1)
                }
            }
            .frame(width: 140, height: 80)
            .cornerRadius(10)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(video.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 2)
        }
        .padding(.vertical, 4)
    }
}
