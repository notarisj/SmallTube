//
//  ContentView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            TrendingView()
                .tabItem {
                    Label("Trending", systemImage: "flame")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: "person.2")
                }
        }
    }
}
