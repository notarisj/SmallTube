//
//  ContentView.swift
//  SmallTube
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            SidebarContainerView()
        } else {
            TabContainerView()
        }
    }
}

// MARK: - iPad

private struct SidebarContainerView: View {
    @State private var selectedItem: SidebarItem? = .home
    @StateObject private var subscriptionsVM = SubscriptionsViewModel()
    @State private var showAddChannelSheet = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("Main") {
                    Label("Home",          systemImage: "house.fill").tag(SidebarItem.home)
                    Label("Trending",      systemImage: "flame.fill").tag(SidebarItem.trending)
                    Label("Search",        systemImage: "magnifyingglass").tag(SidebarItem.search)
                    Label("Subscriptions", systemImage: "person.2.fill").tag(SidebarItem.subscriptions)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("SmallTube")
        } detail: {
            NavigationStack {
                switch selectedItem {
                case .home:          HomeFeedView(subscriptionsViewModel: subscriptionsVM)
                case .trending:      TrendingView()
                case .search:        SearchView()
                case .subscriptions: SubscriptionsView(
                    viewModel: subscriptionsVM,
                    showAddChannelSheet: $showAddChannelSheet
                )
                case .none:
                    ContentUnavailableView("Select a Tab", systemImage: "sidebar.left")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - iPhone

private struct TabContainerView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: TabSelection = .home
    @StateObject private var subscriptionsVM = SubscriptionsViewModel()
    @State private var showAddChannelSheet = false

    enum TabSelection: String {
        case home = "Home"
        case trending = "Trending"
        case search = "Search"
        case subscriptions = "Subscriptions"
    }

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeFeedView(subscriptionsViewModel: subscriptionsVM)
                    .navigationTitle("Home")
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(TabSelection.home)

            NavigationStack {
                TrendingView()
                    .navigationTitle("Trending")
            }
            .tabItem { Label("Trending", systemImage: "flame") }
            .tag(TabSelection.trending)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(TabSelection.search)

            NavigationStack {
                SubscriptionsView(
                    viewModel: subscriptionsVM,
                    showAddChannelSheet: $showAddChannelSheet
                )
                .navigationTitle("Subscriptions")
                .toolbar {
                    if selectedTab == .subscriptions {
                        ToolbarItem(placement: .topBarTrailing) {
                            HStack(spacing: 16) {
                                Menu {
                                    Picker("Sort By", selection: $subscriptionsVM.sortOption) {
                                        ForEach(SubscriptionsViewModel.SortOption.allCases) { option in
                                            Text(option.rawValue).tag(option)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.up.arrow.down")
                                }
                                .onChange(of: subscriptionsVM.sortOption) { _, newValue in
                                    subscriptionsVM.updateSortOption(newValue)
                                }

                                Button { showAddChannelSheet = true } label: {
                                    Image(systemName: "plus")
                                }

                                Button { appState.showSettings = true } label: {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                    }
                }
            }
            .tabItem { Label("Subscriptions", systemImage: "person.2") }
            .tag(TabSelection.subscriptions)
        }
        .sheet(isPresented: $appState.showSettings) {
            NavigationStack { SettingsView() }
        }
    }
}
