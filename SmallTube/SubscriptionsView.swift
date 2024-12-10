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
    
    var body: some View {
        NavigationView {
            List(viewModel.subscriptions) { channel in
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
            .onAppear {
                viewModel.loadSubscriptions(token: authManager.userToken, authManager: authManager)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationTitle("Subscriptions")
            .alert(item: $viewModel.currentAlert) { alertType in
                switch alertType {
                case .noResults:
                    return Alert(title: Text("No Results"), message: Text("No subscriptions found."), dismissButton: .default(Text("OK")))
                case .apiError:
                    return Alert(title: Text("Error"), message: Text("Unable to load subscriptions. Check your sign-in and API key."), dismissButton: .default(Text("OK")))
                case .emptyQuery:
                    return Alert(title: Text("Empty Query"), message: Text("Please enter a search term."), dismissButton: .default(Text("OK")))
                case .quotaExceeded:
                    return Alert(title: Text("Quota Exceeded"), message: Text("You have exceeded your YouTube API quota."), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}
