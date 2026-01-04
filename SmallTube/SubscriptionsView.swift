//
//  SubscriptionsView.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import SwiftUI

struct SubscriptionsView: View {
    @StateObject var viewModel = SubscriptionsViewModel()
    @EnvironmentObject var appState: AppState
    
    // Access the horizontal size class from the environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State private var showAddChannelSheet = false


    var body: some View {
        List {
            ForEach(viewModel.subscriptions) { channel in
                NavigationLink(destination: ChannelVideosView(channelId: channel.id, channelTitle: channel.title)) {
                    HStack {
                        AsyncImage(url: channel.thumbnailURL)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(channel.title)
                                .font(.headline)
                            Text(channel.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete(perform: viewModel.deleteChannel)
        }
        .onAppear {
            viewModel.loadImportedSubscriptions { _ in }
        }
        .navigationTitle("Subscriptions")
        .toolbar {
            // Show toolbar items only when horizontal size class is compact (e.g., iPhone)
            if UIDevice.current.userInterfaceIdiom != .pad {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showAddChannelSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        Menu {
                            Picker("Sort By", selection: $viewModel.sortOption) {
                                ForEach(SubscriptionsViewModel.SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .onChange(of: viewModel.sortOption) { newValue in
                            viewModel.updateSortOption(newValue)
                        }
                        
                        Button(action: {
                            appState.showSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddChannelSheet) {
            AddChannelView(isPresented: $showAddChannelSheet) { newId in
                viewModel.addChannel(id: newId)
            }
        }
        .alert(item: $viewModel.currentAlert) { alertType in
            AlertBuilder.buildAlert(for: alertType)
        }
    }
}

struct AddChannelView: View {
    @Binding var isPresented: Bool
    var onAdd: (String) -> Void
    
    @State private var channelId: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter Channel ID")) {
                    TextField("Channel ID (e.g. UC...)", text: $channelId)
                }
                
                Section {
                    Button("Add Channel") {
                        if !channelId.isEmpty {
                            onAdd(channelId)
                            isPresented = false
                        }
                    }
                    .disabled(channelId.isEmpty)
                }
            }
            .navigationTitle("Add Subscription")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
