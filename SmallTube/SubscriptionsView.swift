//
//  SubscriptionsView.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import SwiftUI

struct SubscriptionsView: View {
    @StateObject var viewModel = SubscriptionsViewModel()
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    
    // Access the horizontal size class from the environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        List(viewModel.subscriptions) { channel in
            NavigationLink(destination: ChannelVideosView(channel: channel)) {
                HStack {
                    AsyncImage(url: channel.thumbnailURL)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text(channel.title)
                            .font(.headline)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Text(channel.description)
                            .font(.subheadline)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSubscriptions(token: authManager.userToken) { subscriptions in
                DispatchQueue.main.async {
                    viewModel.subscriptions = subscriptions
                }
            }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            // Show toolbar items only when horizontal size class is compact (e.g., iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        appState.showSettings = true
                    }) {
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
