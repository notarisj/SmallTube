//
//  ChannelVideosView.swift
//  SmallTube
//

import SwiftUI

struct ChannelVideosView: View {
    let channel: YouTubeChannel

    @StateObject private var viewModel = ChannelVideosViewModel()
    @State private var isDescriptionExpanded = false

    var body: some View {
        Group {
            if viewModel.videos.isEmpty {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "No Videos",
                        systemImage: "play.slash",
                        description: Text("No long-form videos found for this channel.")
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        channelHeader
                        
                        Divider()

                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.videos) { video in
                                NavigationLink(destination: VideoPlayerView(video: video)) {
                                    VideoRowView(video: video)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadVideos(channelId: channel.id, ignoreCache: true)
                }
            }
        }
        .navigationTitle(channel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.loadVideos(channelId: channel.id) }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
    }

    private var channelHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: channel.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                default:
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                if !channel.description.isEmpty {
                    Text(channel.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.3)) {
                                isDescriptionExpanded.toggle()
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
