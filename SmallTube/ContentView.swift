//
//  ContentView.swift
//  SmallTube
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadSidebarView()
        } else {
            iPhoneTabView()
        }
    }
}

// MARK: - iPad

struct iPadSidebarView: View {
    @State private var selectedItem: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Main") {
                    Label("Home", systemImage: "house.fill").tag(SidebarItem.home)
                    Label("Trending", systemImage: "flame.fill").tag(SidebarItem.trending)
                    Label("Search", systemImage: "magnifyingglass").tag(SidebarItem.search)
                    Label("Subscriptions", systemImage: "person.2.fill").tag(SidebarItem.subscriptions)
                }
                Section("Settings") {
                    Label("Settings", systemImage: "gearshape.fill").tag(SidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("SmallTube")
        } detail: {
            Group {
                switch selectedItem {
                case .home:          detailView(HomeFeedView(), title: "Home")
                case .trending:      detailView(TrendingView(), title: "Trending")
                case .search:        detailView(SearchView(), title: "Search")
                case .subscriptions: detailView(SubscriptionsView(), title: "Subscriptions")
                case .settings:      detailView(SettingsView(), title: "Settings")
                case .none:
                    Text("Select an option").foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailView<Content: View>(_ content: Content, title: String) -> some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { selectedItem = nil } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
        }
    }
}

// MARK: - iPhone

struct iPhoneTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            NavigationStack {
                HomeFeedView().navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                TrendingView().navigationTitle("Trending")
            }
            .tabItem { Label("Trending", systemImage: "flame") }

            NavigationStack {
                SearchView().navigationTitle("Search")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                SubscriptionsView().navigationTitle("Subscriptions")
            }
            .tabItem { Label("Subscriptions", systemImage: "person.2") }
        }
        .sheet(isPresented: $appState.showSettings) {
            NavigationStack { SettingsView() }
        }
    }
}
