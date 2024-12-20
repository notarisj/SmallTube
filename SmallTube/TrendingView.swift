//
//  TrendingView.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import SwiftUI

struct TrendingView: View {
    @StateObject var viewModel = YouTubeViewModel()
    
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
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}
