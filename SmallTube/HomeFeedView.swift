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

    var body: some View {
        NavigationView {
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
            .alert(item: $viewModel.currentAlert) { alertType in
                switch alertType {
                case .noResults:
                    return Alert(title: Text("No Results"), message: Text("No home feed videos found."), dismissButton: .default(Text("OK")))
                case .apiError:
                    return Alert(title: Text("Error"), message: Text("Unable to load home feed. Check your sign-in and API key."), dismissButton: .default(Text("OK")))
                case .emptyQuery:
                    return Alert(title: Text("Empty Query"), message: Text("Please enter a search term."), dismissButton: .default(Text("OK")))
                case .quotaExceeded:
                    return Alert(title: Text("Quota Exceeded"), message: Text("You have exceeded your YouTube API quota."), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}
