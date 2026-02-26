//
//  SearchView.swift
//  SmallTube
//

import SwiftUI
import UIKit

struct SearchView: View {
    @StateObject private var viewModel = YouTubeViewModel()
    @Environment(\.isSearching) private var isSearching

    @State private var searchText = ""
    @State private var submittedQuery = ""
    @State private var isShowingResults = false
    @State private var showClearConfirmation = false

    var body: some View {
        mainContent
            .navigationTitle(isShowingResults && !submittedQuery.isEmpty ? submittedQuery : "Search")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Videos"
            )
            .onSubmit(of: .search) {
                performSearch(query: searchText)
            }
            .onChange(of: isSearching) { _, searching in
                if !searching && searchText.isEmpty {
                    isShowingResults = false
                }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    isShowingResults = false
                    viewModel.videos = []
                }
            }
            .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
            .alert("Clear History", isPresented: $showClearConfirmation) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearAllSearches()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all your previous searches and cannot be undone.")
            }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        if isShowingResults {
            resultsView
        } else if !viewModel.lastSearches.isEmpty {
            historyList
        } else {
            emptyPrompt
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if viewModel.videos.isEmpty {
            ContentUnavailableView.search(text: submittedQuery)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.videos) { video in
                        VideoRowView(video: video)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyList: some View {
        let filtered = searchText.isEmpty
            ? viewModel.lastSearches
            : viewModel.lastSearches.filter { $0.localizedCaseInsensitiveContains(searchText) }

        if filtered.isEmpty {
            emptyPrompt
        } else {
            List {
                Section {
                    ForEach(filtered, id: \.self) { item in
                        Button {
                            searchText = item
                            performSearch(query: item)
                        } label: {
                            Label(item, systemImage: "clock")
                                .foregroundStyle(.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.removeSearch(item)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(searchText.isEmpty ? "Recent" : "Previous Searches")
                        Spacer()
                        if searchText.isEmpty {
                            Button("Clear All") {
                                showClearConfirmation = true
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyPrompt: some View {
        ContentUnavailableView(
            "Search SmallTube",
            systemImage: "play.rectangle.on.rectangle",
            description: Text("Search for videos above.")
        )
        .symbolRenderingMode(.hierarchical)
    }

    // MARK: - Actions

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submittedQuery = trimmed
        isShowingResults = true
        hideKeyboard()
        Task {
            await viewModel.searchVideos(query: trimmed)
        }
    }
}
