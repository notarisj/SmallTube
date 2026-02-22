//
//  TrendingView.swift
//  SmallTube
//

import SwiftUI

struct TrendingView: View {
    @StateObject var viewModel = YouTubeViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(viewModel.videos) { video in
            NavigationLink(destination: VideoPlayerView(video: video)) {
                HStack(spacing: 12) {
                    AsyncImage(url: video.thumbnailURL) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .failure: Image(systemName: "play.rectangle").resizable().scaledToFit()
                        default: Color.secondary.opacity(0.2)
                        }
                    }
                    .frame(width: 100, height: 60)
                    .cornerRadius(8)
                    .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(video.description)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear { viewModel.loadTrendingVideos() }
        .navigationTitle("Trending")
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
}
