//
//  SubscriptionsViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import Foundation
import SwiftUI

class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [YouTubeChannel] = []
    @Published var currentAlert: AlertType?
    
    // Sort Option Persistence
    @AppStorage("subscriptionsSortOption") var sortOption: SortOption = .az
    
    enum SortOption: String, CaseIterable, Identifiable {
        case az = "A-Z"
        case za = "Z-A"
        
        var id: String { self.rawValue }
    }
    
    private let subscriptionsCacheKey = "subscriptionsCacheKey"
    private let subscriptionsCacheDateKey = "subscriptionsCacheDateKey"
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }
    
    var resultsCount: String {
        get { UserDefaults.standard.string(forKey: "resultsCount") ?? "10" }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }
    
    var countryCode: String {
        get { UserDefaults.standard.string(forKey: "countryCode") ?? "US" }
        set { UserDefaults.standard.set(newValue, forKey: "countryCode") }
    }

    func loadImportedSubscriptions(completion: @escaping ([YouTubeChannel]) -> Void) {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
                completion([])
            }
            return
        }

        let channelIds = SubscriptionManager.shared.subscriptionIds
        guard !channelIds.isEmpty else {
            DispatchQueue.main.async {
                self.subscriptions = []
                completion([])
            }
            return
        }
        
        // Batch IDs into groups of 50 (API limit)
        let batches = channelIds.chunked(into: 50)
        var allChannels: [YouTubeChannel] = []
        let group = DispatchGroup()
        
        for batch in batches {
            group.enter()
            let idsString = batch.joined(separator: ",")
            let urlString = "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=\(idsString)&key=\(apiKey)"
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                guard let data = data else { return }
                
                do {
                    let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                    let channels = response.items.map { item in
                        YouTubeChannel(
                            id: item.id,
                            title: item.snippet.title,
                            description: item.snippet.description,
                            thumbnailURL: item.snippet.thumbnails.default.url
                        )
                    }
                    DispatchQueue.main.async {
                        allChannels.append(contentsOf: channels)
                    }
                } catch {
                    print("Error decoding channel batch: \(error)")
                }
            }.resume()
        }
        
        group.notify(queue: .main) {
            self.sortChannels(allChannels)
            completion(self.subscriptions)
        }
    }
    
    private func sortChannels(_ channels: [YouTubeChannel]) {
        switch sortOption {
        case .az:
            self.subscriptions = channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .za:
            self.subscriptions = channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }
    
    func updateSortOption(_ option: SortOption) {
        sortOption = option
        sortChannels(self.subscriptions)
    }
    
    // Helper extension for chunking
    // Note: In a real project, this might go in a Utility file
    
    // Old method signature kept or removed? Removed as per instruction to use stored IDs.
    // The previous code had `loadSubscriptions(token: ...)` which is now obsolete.
    
    // MARK: - Caching
    private func cacheSubscriptions(_ channels: [YouTubeChannel]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(channels)
            UserDefaults.standard.set(data, forKey: subscriptionsCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: subscriptionsCacheDateKey)
        } catch {
            print("Failed to cache subscriptions: \(error)")
        }
    }
    
    private func loadCachedSubscriptions() -> [YouTubeChannel]? {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsCacheKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([YouTubeChannel].self, from: data)
        } catch {
            print("Failed to decode cached subscriptions: \(error)")
            return nil
        }
    }
    
    func deleteChannel(at offsets: IndexSet) {
        // Find the IDs to remove based on the current subscriptions list
        // Note: The subscriptions list in VM matches the order of loaded IDs if not sorted otherwise.
        // However, if we filter or sort, indices might not match `SubscriptionManager.subscriptionIds`.
        // Ideally, we remove by ID.
        
        // Map offsets to IDs
        let idsToRemove = offsets.map { subscriptions[$0].id }
        
        // Remove from manager
        var currentIds = SubscriptionManager.shared.subscriptionIds
        currentIds.removeAll { idsToRemove.contains($0) }
        SubscriptionManager.shared.subscriptionIds = currentIds
        UserDefaults.standard.set(currentIds, forKey: "storedSubscriptionIds")
        
        // Update local list
        subscriptions.remove(atOffsets: offsets)
    }
    
    func addChannel(id: String) {
        SubscriptionManager.shared.addSubscription(id: id)
        // Reload to fetch the new channel's details
        loadImportedSubscriptions { _ in }
    }
    
    func searchYouTubeChannels(query: String, completion: @escaping ([YouTubeChannel]) -> Void) {
        guard !query.isEmpty, !apiKey.isEmpty else {
            completion([])
            return
        }
        
        // Encode query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion([])
            return
        }
        
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q=\(encodedQuery)&maxResults=20&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion([])
                return
            }
            
            do {
                let response = try JSONDecoder().decode(SearchResponse.self, from: data)
                let channels = response.items.map { item in
                    YouTubeChannel(
                        id: item.snippet.channelId ?? item.id.channelId ?? "",
                        title: item.snippet.title,
                        description: item.snippet.description,
                        thumbnailURL: item.snippet.thumbnails.default.url
                    )
                }
                // Filter out channels with empty IDs just in case
                let validChannels = channels.filter { !$0.id.isEmpty }
                
                DispatchQueue.main.async {
                    completion(validChannels)
                }
            } catch {
                print("Search decode error: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
    
    func validateAndAddChannel(id: String, completion: @escaping (Bool) -> Void) {
        guard !id.isEmpty, !apiKey.isEmpty else {
            completion(false)
            return
        }
        
        let urlString = "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=\(id)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                if let _ = response.items.first {
                    // Valid channel
                    DispatchQueue.main.async {
                        self.addChannel(id: id)
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }.resume()
    }

    private func isCacheExpired() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: subscriptionsCacheDateKey)
        guard lastFetchTime > 0 else {
            return true
        }
        let now = Date().timeIntervalSince1970
        return now - lastFetchTime > cacheDuration
    }
}

// MARK: - Subscription Response Models
// MARK: - Channel Response Models
struct ChannelResponse: Decodable {
    let items: [ChannelResponseItem]
}

struct ChannelResponseItem: Decodable {
    let id: String
    let snippet: ChannelResponseSnippet
}

struct ChannelResponseSnippet: Decodable {
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
}

struct SearchResponse: Decodable {
    let items: [SearchItem]
}

struct SearchItem: Decodable {
    let id: SearchItemId
    let snippet: SearchSnippet
}

struct SearchItemId: Decodable {
    let channelId: String?
}

struct SearchSnippet: Decodable {
    let channelId: String? // Sometimes directly in snippet in some contexts, but mostly in id
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
}

struct ThumbnailSet: Decodable {
    let `default`: Thumbnail
}

struct Thumbnail: Decodable {
    let url: URL
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// Moved SubscriptionManager here to ensure availability in build scope
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    private let storedSubscriptionsKey = "storedSubscriptionIds"
    
    @Published var subscriptionIds: [String] = []
    
    init() {
        loadSubscriptions()
    }
    
    func parseCSV(url: URL) -> Bool {
        // Secure access to the file
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            let rows = data.components(separatedBy: .newlines)
            
            var newIds: [String] = []
            
            // Expected Header: Channel Id,Channel Url,Channel Title
            
            for (index, row) in rows.enumerated() {
                if index == 0 { continue } // Skip header
                let columns = row.components(separatedBy: ",")
                if let channelId = columns.first, !channelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if channelId.count > 5 { 
                        newIds.append(channelId)
                    }
                }
            }
            
            if !newIds.isEmpty {
                saveSubscriptions(newIds)
                return true
            }
            return false
            
        } catch {
            print("Failed to parse CSV: \(error)")
            return false
        }
    }
    
    private func saveSubscriptions(_ ids: [String]) {
        self.subscriptionIds = ids
        UserDefaults.standard.set(ids, forKey: storedSubscriptionsKey)
    }
    
    private func loadSubscriptions() {
        if let storedIds = UserDefaults.standard.stringArray(forKey: storedSubscriptionsKey) {
            self.subscriptionIds = storedIds
        }
    }
    
    func clearSubscriptions() {
        self.subscriptionIds = []
        UserDefaults.standard.removeObject(forKey: storedSubscriptionsKey)
    }
    
    func addSubscription(id: String) {
        let trimmedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedId.isEmpty, !subscriptionIds.contains(trimmedId) else { return }
        var ids = subscriptionIds
        ids.append(trimmedId)
        saveSubscriptions(ids)
    }
    
    func removeSubscriptions(at offsets: IndexSet) {
        var ids = subscriptionIds
        ids.remove(atOffsets: offsets)
        saveSubscriptions(ids)
    }
}
