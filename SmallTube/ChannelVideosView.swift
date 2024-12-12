//
//  ChannelVideosView.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import SwiftUI

struct ChannelVideosView: View {
    @StateObject var viewModel = ChannelVideosViewModel()
    var channel: YouTubeChannel

    var body: some View {
        List(viewModel.videos) { video in
            NavigationLink(destination: VideoPlayerView(video: video)) {
                HStack {
                    if let url = URL(string: video.thumbnailURL.absoluteString) {
                        AsyncImage(url: url)
                            .frame(width: 100, height: 60)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(video.description)
                            .font(.subheadline)
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadVideos(for: channel)
        }
        .navigationTitle(channel.title)
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}
