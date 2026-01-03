//
//  SearchView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import SwiftUI

struct SearchView: View {
    @StateObject var viewModel = YouTubeViewModel()
    @EnvironmentObject var appState: AppState
    @State var query: String = ""
    @State var showSearchView: Bool = true
    
    var body: some View {
        VStack {
            if showSearchView {
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
                .searchable(text: $query, prompt: "Search") {
                    ForEach(viewModel.searchSuggestions(query: query), id: \.self) { suggestion in
                        Text(suggestion).onTapGesture {
                            query = suggestion
                            viewModel.searchVideos(query: query)
                        }
                    }
                    .onDelete(perform: viewModel.deleteSearches)
                }
                .onSubmit(of: .search) {
                    viewModel.searchVideos(query: query.trimmingCharacters(in: .whitespacesAndNewlines))
                    showSearchView = false
                }
            } else {
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
                .alert(item: $viewModel.currentAlert) { alertType in
                    AlertBuilder.buildAlert(for: alertType)
                }
            }
        }
        .toolbar {
            // Conditionally show toolbar items only on iPhone
            if UIDevice.current.userInterfaceIdiom != .pad {
                if !showSearchView {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showSearchView = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
                // Add settings icon
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        appState.showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .navigationTitle(query.isEmpty ? "SmallTube" : query)
    }
}
