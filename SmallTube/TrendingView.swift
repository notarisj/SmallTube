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
        NavigationView {
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
                switch alertType {
                case .noResults:
                    return Alert(title: Text("No Results"), message: Text("No videos found."), dismissButton: .default(Text("OK")))
                case .apiError:
                    return Alert(title: Text("API Error"), message: Text("Please set a valid api key in settings."), dismissButton: .default(Text("OK")))
                case .emptyQuery:
                    return Alert(title: Text("Empty Query"), message: Text("Please enter a search term."), dismissButton: .default(Text("OK")))
                case .quotaExceeded:
                    return Alert(title: Text("Quota Exceeded"), message: Text("You have exceeded your YouTube API quota."), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}
