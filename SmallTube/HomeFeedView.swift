//
//  HomeFeedView.swift
//  SmallTube
//
//  Created by John Notaris on 12/10/24.
//

import SwiftUI

struct HomeFeedView: View {
    @StateObject var viewModel = HomeFeedViewModel()
    @EnvironmentObject var authManager: AuthManager
    
    // Access the horizontal size class from the environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

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
        .navigationTitle("Home Feed")
        .onAppear {
            viewModel.loadHomeFeed(token: authManager.userToken)
        }
        .toolbar {
            // Show toolbar items only when horizontal size class is compact (e.g., iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
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
