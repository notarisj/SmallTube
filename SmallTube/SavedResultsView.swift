//
//  SavedResultsView.swift
//  SmallTube
//
//  Created by John Notaris on 15/5/24.
//

import SwiftUI

struct SavedSearch: Codable, Identifiable {
    let id: UUID
    let query: String
    let videos: [YouTubeVideo]
    let date: Date
}

struct SavedResultsView: View {
    @AppStorage("savedSearches") var savedSearchesData: Data = Data()
    @State private var savedSearches: [SavedSearch] = []
    @State private var selectedSearch: SavedSearch?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(savedSearches) { savedSearch in
                    NavigationLink(destination: SavedSearchDetailView(videos: savedSearch.videos, query: savedSearch.query)) {
                        Text(savedSearch.query)
                    }
                }
                .onDelete(perform: deleteSearch)
            }
            .navigationBarTitle("Saved Results", displayMode: .inline)
            .onAppear {
                loadSavedSearches()
            }
        }
    }
    
    func loadSavedSearches() {
        if let dictionary = try? JSONDecoder().decode([UUID: SavedSearch].self, from: savedSearchesData) {
            savedSearches = Array(dictionary.values).sorted(by: { $0.date > $1.date }) // Add sorting here
        }
    }
    
    func deleteSearch(at offsets: IndexSet) {
        offsets.forEach { index in
            savedSearches.remove(at: index)
        }
        let dictionary = Dictionary(uniqueKeysWithValues: savedSearches.map { ($0.id, $0) })
        if let encoded = try? JSONEncoder().encode(dictionary) {
            UserDefaults.standard.set(encoded, forKey: "savedSearches")
        }
    }
}
