//
//  TrendingView.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import SwiftUI

struct TrendingView: View {
    @StateObject var viewModel = YouTubeViewModel()
    
    // Access the horizontal size class from the environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(viewModel.videos) { video in
            NavigationLink(destination: VideoPlayerView(video: video)) {
                HStack {
                    if let url = URL(string: video.thumbnailURL.absoluteString) {
                        AsyncImage(url: url)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Text(video.description)
                            .font(.subheadline)
                            .lineLimit(3)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadTrendingVideos()
        }
        .navigationTitle("Trending")
        .toolbar {
            // Show toolbar items only when horizontal size class is compact (e.g., iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        appState.showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}
