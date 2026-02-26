//
//  TrendingView.swift
//  SmallTube
//

import SwiftUI

struct TrendingView: View {
    @StateObject private var viewModel = YouTubeViewModel()
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if viewModel.videos.isEmpty {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "No Trending Videos",
                        systemImage: "flame",
                        description: Text("Check your API key in Settings.")
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
                    await viewModel.loadTrendingVideos(ignoreCache: true)
                }
            }
        }
        .task { await viewModel.loadTrendingVideos() }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.refreshTrending()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.rotate, options: .repeating, isActive: viewModel.isLoading)
                }
            }
        }
    }
}
