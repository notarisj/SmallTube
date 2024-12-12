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
        List {
            // Channel Info as the first entry in the list
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: channel.thumbnailURL)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .truncationMode(.tail)

                        Text(channel.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true) // Allow multi-line
                    }
                }
                .padding(.vertical, 8)
            }

            // Videos list
            ForEach(viewModel.videos) { video in
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
