//
//  ChannelVideosView.swift
//  SmallTube
//

import SwiftUI

struct ChannelVideosView: View {
    let channel: YouTubeChannel
    
    @StateObject private var viewModel = ChannelVideosViewModel()
    @State private var isDescriptionExpanded = false
    @State private var showingAvatarPreview = false
    
    private var currentChannel: YouTubeChannel {
        viewModel.detailedChannel ?? channel
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
                                VideoRowView(video: video, showChannelLink: false)
                            }
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.loadChannelDetails(channelId: channel.id, ignoreCache: true)
                        await viewModel.loadVideos(channelId: channel.id, ignoreCache: true)
                    }
                }
            }
        }
        .navigationTitle(currentChannel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.loadChannelDetails(channelId: channel.id)
            await viewModel.loadVideos(channelId: channel.id)
        }
        .alert(item: $viewModel.currentAlert) { AlertBuilder.buildAlert(for: $0) }
    }
    
    private var channelHeader: some View {
            VStack(spacing: 0) {
                // MARK: Banner
                if let bannerURL = currentChannel.bannerURL {
                    AsyncImage(url: bannerURL) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .clipped()
                        } else if phase.error != nil {
                            Color(uiColor: .systemGray6).frame(height: 120)
                        } else {
                            Color(uiColor: .systemGray6).frame(height: 120)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // MARK: Avatar and Title
                    HStack(alignment: .bottom, spacing: 16) {
                        Button {
                            showingAvatarPreview = true
                        } label: {
                            AsyncImage(url: currentChannel.thumbnailURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 4))
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .offset(y: currentChannel.bannerURL != nil ? -40 : 0) // Overlap banner if exists
                        .padding(.bottom, currentChannel.bannerURL != nil ? -40 : 0)
                        .fullScreenCover(isPresented: $showingAvatarPreview) {
                            NavigationStack {
                                ZStack {
                                    Color.black.ignoresSafeArea()
                                    
                                    AsyncImage(url: currentChannel.thumbnailURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFit()
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(.white.opacity(0.5))
                                                .padding()
                                        }
                                    }
                                }
                                .toolbar {
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button("Done") {
                                            showingAvatarPreview = false
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    }
                                }
                                .toolbarBackground(.black, for: .navigationBar)
                                .toolbarBackground(.visible, for: .navigationBar)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentChannel.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            if let customUrl = currentChannel.customUrl {
                                Text(customUrl.hasPrefix("@") ? customUrl : "@\(customUrl)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                    
                    // MARK: Stats Bar
                    HStack(spacing: 12) {
                        if let subCount = currentChannel.subscriberCount {
                            Text("\(formatCount(subCount)) subscribers")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if currentChannel.hiddenSubscriberCount == true {
                            Text("Subscribers hidden")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if currentChannel.subscriberCount != nil || currentChannel.hiddenSubscriberCount == true {
                            Text("•")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        
                        if let vidCount = currentChannel.videoCount {
                            Text("\(formatCount(vidCount)) videos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // MARK: Description & Detail Page Link
                    NavigationLink(destination: ChannelDetailView(channel: currentChannel)) {
                        HStack(spacing: 4) {
                            Text(currentChannel.description.isEmpty ? "More about this channel" : currentChannel.description)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, currentChannel.bannerURL != nil ? 0 : 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        private func formatCount(_ count: Int) -> String {
            return count.formatted(.number.notation(.compactName))
        }
}
