//
//  ContentView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = YouTubeViewModel()
    @State var query: String = ""
    @State var showSearchView: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if showSearchView {
                    List(viewModel.videos) { video in
                        NavigationLink(destination: VideoPlayerView(video: video)) {
                            HStack {
                                if let url = URL(string: video.thumbnailURL.absoluteString) {
                                    AsyncImage(url: url)
                                }
                                
                                // Title and Description
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
                }
                else {
                    // Your main view
                    List(viewModel.videos) { video in
                        NavigationLink(destination: VideoPlayerView(video: video)) {
                            HStack {
                                if let url = URL(string: video.thumbnailURL.absoluteString) {
                                    AsyncImage(url: url)
                                }
                                
                                // Title and Description
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
                        switch alertType {
                        case .noResults:
                            return Alert(title: Text("No Results"), message: Text("No videos found for your search."), dismissButton: .default(Text("OK")))
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                if !showSearchView {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            showSearchView = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                }
            }
            .navigationTitle(query.isEmpty ? "SmallTube" : query)
        }
    }
}
