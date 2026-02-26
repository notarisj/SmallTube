//
//  HomeFeedView.swift
//  SmallTube
//

import SwiftUI

struct HomeFeedView: View {
    @ObservedObject var subscriptionsViewModel: SubscriptionsViewModel
    @StateObject private var viewModel: HomeFeedViewModel
    @Environment(AppState.self) private var appState

    @State private var showingRefreshConfirmation = false

    init(subscriptionsViewModel: SubscriptionsViewModel) {
        self.subscriptionsViewModel = subscriptionsViewModel
        _viewModel = StateObject(wrappedValue: HomeFeedViewModel(subscriptionsViewModel: subscriptionsViewModel))
    }

    var body: some View {
        Group {
            if viewModel.videos.isEmpty {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "play.rectangle.on.rectangle",
                        description: Text("Add subscriptions to see your home feed.")
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.videos) { video in
                            VideoRowView(video: video)
                        }
                    }
                }
                .refreshable {
                    if AppPreferences.cacheTimeout == .disabled {
                        await viewModel.loadHomeFeed(ignoreCache: true)
                    } else {
                        showingRefreshConfirmation = true
                    }
                }
            }
        }
        .task { await viewModel.loadHomeFeed() }
        .alert("Refresh Feed?", isPresented: $showingRefreshConfirmation) {
            Button("Refresh", role: .destructive) {
                viewModel.refreshFeed()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Refreshing will invalidate the cache and fetch new results from the YouTube API, which uses more of your API quota.")
        }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if AppPreferences.cacheTimeout == .disabled {
                        viewModel.refreshFeed()
                    } else {
                        showingRefreshConfirmation = true
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, options: .repeating, isActive: viewModel.isLoading)
                }
            }
        }
    }
}
