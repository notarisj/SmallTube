//
//  ContentView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Sidebar layout for iPad without NavigationView
                iPadSidebarView()
            } else {
                // Tab bar layout for iPhone with NavigationView and title
                NavigationView {
                    iPhoneTabView()
                }
            }
        }
    }
}

struct iPadSidebarView: View {
    @State private var selectedItem: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            // Sidebar Content
            List(selection: $selectedItem) {
                Section(header: Text("Main")) {
                    Label("Home", systemImage: "house.fill")
                        .tag(SidebarItem.home)

                    Label("Trending", systemImage: "flame.fill")
                        .tag(SidebarItem.trending)

                    Label("Search", systemImage: "magnifyingglass")
                        .tag(SidebarItem.search)

                    Label("Subscriptions", systemImage: "person.2.fill")
                        .tag(SidebarItem.subscriptions)
                }

                Section(header: Text("Settings")) {
                    Label("Settings", systemImage: "gearshape.fill")
                        .tag(SidebarItem.settings)
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle("SmallTube")
        } detail: {
            // Add back button for navigation
            Group {
                switch selectedItem {
                case .home:
                    detailView(content: HomeFeedView(), title: "Home")
                case .trending:
                    detailView(content: TrendingView(), title: "Trending")
                case .search:
                    detailView(content: SearchView(), title: "Search")
                case .subscriptions:
                    detailView(content: SubscriptionsView(), title: "Subscriptions")
                case .settings:
                    detailView(content: SettingsView(), title: "Settings")
                case .none:
                    Text("Select an option")
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Helper function to add a back button in the navigation bar
    private func detailView<Content: View>(content: Content, title: String) -> some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            // Reset the selection to show the sidebar again
                            selectedItem = nil
                        }) {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
        }
    }
}

struct iPhoneTabView: View {
    var body: some View {
        TabView {
            NavigationView {
                HomeFeedView()
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationView {
                TrendingView()
                    .navigationTitle("Trending")
            }
            .tabItem {
                Label("Trending", systemImage: "flame")
            }

            NavigationView {
                SearchView()
                    .navigationTitle("Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationView {
                SubscriptionsView()
                    .navigationTitle("Subscriptions")
            }
            .tabItem {
                Label("Subscriptions", systemImage: "person.2")
            }
        }
    }
}
