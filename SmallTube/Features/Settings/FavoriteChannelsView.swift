//
//  FavoriteChannelsView.swift
//  SmallTube
//

import SwiftUI

struct FavoriteChannelsView: View {
    @StateObject var subscriptionsViewModel = SubscriptionsViewModel()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    var filteredSubscriptions: [YouTubeChannel] {
        if searchText.isEmpty {
            return subscriptionsViewModel.subscriptions
        } else {
            return subscriptionsViewModel.subscriptions.filter { channel in
                channel.title.localizedCaseInsensitiveContains(searchText) || channel.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            if filteredSubscriptions.isEmpty {
                if searchText.isEmpty {
                    Text("No subscriptions found or loaded yet.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    Text("No channels match your search.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(filteredSubscriptions, id: \.id) { channel in
                    let isFavorite = subscriptionManager.isFavorite(id: channel.id)
                    Button {
                        // Toggle favorite using haptic feedback
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        subscriptionManager.toggleFavorite(id: channel.id)
                    } label: {
                        HStack {
                            AsyncImage(url: channel.thumbnailURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(channel.title)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .foregroundColor(isFavorite ? .yellow : .gray)
                                .font(.system(size: 20))
                        }
                    }
                    .buttonStyle(.plain) // remove highlighting
                }
            }
        }
        .navigationTitle("Favorite Channels")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search subscriptions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            // Ensure subscriptions are loaded when viewing this page.
            if subscriptionsViewModel.subscriptions.isEmpty {
                _ = await subscriptionsViewModel.fetchSubscriptions()
            }
        }
    }
}
