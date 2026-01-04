//
//  ChannelVideosView.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import SwiftUI

struct ChannelVideosView: View {
    @StateObject var viewModel = ChannelVideosViewModel()
    var channelId: String
    var channelTitle: String

    var body: some View {
        List {
            // Channel Info as the first entry in the list
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 16) {
                    // Thumbnail not available from just ID/Title immediately
                    // AsyncImage(url: channel.thumbnailURL) ...
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(channelTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        
                        // Description not available
                        // Text(channel.description) ...
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
            let dummyChannel = YouTubeChannel(id: channelId, title: channelTitle, description: "", thumbnailURL: URL(string: "https://www.youtube.com")!)
            viewModel.loadVideos(for: dummyChannel)
        }
        .navigationTitle(channelTitle)
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}
