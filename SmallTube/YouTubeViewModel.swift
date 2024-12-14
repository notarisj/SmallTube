//
//  YouTubeViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import Foundation
import SwiftUI

enum AlertType: Identifiable {
    case noResults, apiError, emptyQuery, quotaExceeded, credsMismatch, unknownError
    var id: Int {
        switch self {
        case .noResults:
            return 0
        case .apiError:
            return 1
        case .emptyQuery:
            return 2
        case .quotaExceeded:
            return 3
        case .credsMismatch:
            return 4
        case .unknownError:
            return 5
        }
    }
}

class YouTubeViewModel: ObservableObject {
    @Published var videos = [CachedYouTubeVideo]()
    @Published var currentAlert: AlertType?
    
    // MARK: - Caching properties
    private let trendingCacheKey = "trendingVideosCacheKey"
    private let trendingCacheDateKey = "trendingVideosCacheDateKey"
    private let cacheDuration: TimeInterval = 300 // 5 minutes in seconds
    
    var lastSearches: [String] {
        get {
            return UserDefaults.standard.array(forKey: "lastSearches") as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSearches")
        }
    }
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }
    
    var resultsCount: String {
        get { UserDefaults.standard.string(forKey: "resultsCount") ?? "10" }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }
    
    // Retrieve country code
    var countryCode: String {
        get { UserDefaults.standard.string(forKey: "countryCode") ?? "US" }
        set { UserDefaults.standard.set(newValue, forKey: "countryCode") }
    }
    
    func searchVideos(query: String) {
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .emptyQuery
            }
            return
        }
        // Save the search query
        var searches = lastSearches
        if !searches.contains(query) {
            searches.insert(query, at: 0)
            if searches.count > 10 {
                searches = Array(searches.prefix(10))
            }
            lastSearches = searches
        }
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=\(encodedQuery)&maxResults=\(resultsCount)&key=\(apiKey)&type=video"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let cachedVideos = response.items.map { CachedYouTubeVideo(from: $0) }
                DispatchQueue.main.async {
                    self.videos = cachedVideos
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }
    
    func loadTrendingVideos() {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }
        
        // Check cache first
        if let cachedVideos = loadCachedTrendingVideos(), !cachedVideos.isEmpty, !isCacheExpired() {
            // If we have cached results and they're still valid
            DispatchQueue.main.async {
                self.videos = cachedVideos
                self.currentAlert = self.videos.isEmpty ? .noResults : nil
            }
            return
        }
        
        // If cache is expired or doesn't exist, fetch again
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&maxResults=\(resultsCount)&regionCode=\(countryCode)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else { return }
            do {
                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let cachedVideos = response.items.map { CachedYouTubeVideo(from: $0) }
                DispatchQueue.main.async {
                    self.videos = cachedVideos
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                    
                    // Update the cache with new results
                    self.cacheTrendingVideos(self.videos)
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }

    func searchSuggestions(query: String) -> [String] {
        // For now, we just return last searches. You could filter by query if desired.
        return lastSearches
    }
    
    func deleteSearches(at offsets: IndexSet) {
        var searches = lastSearches
        searches.remove(atOffsets: offsets)
        lastSearches = searches
    }
    
    // MARK: - Caching Methods
    
    private func cacheTrendingVideos(_ videos: [CachedYouTubeVideo]) {
        do {
            let data = try JSONEncoder().encode(videos)
            UserDefaults.standard.set(data, forKey: trendingCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: trendingCacheDateKey)
        } catch {
            print("Failed to cache trending videos: \(error)")
        }
    }

    private func loadCachedTrendingVideos() -> [CachedYouTubeVideo]? {
        guard let data = UserDefaults.standard.data(forKey: trendingCacheKey) else { return nil }
        do {
            let videos = try JSONDecoder().decode([CachedYouTubeVideo].self, from: data)
            return videos
        } catch {
            print("Failed to decode cached videos: \(error)")
            return nil
        }
    }

    private func isCacheExpired() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: trendingCacheDateKey)
        guard lastFetchTime > 0 else {
            return true // no cache date found
        }
        let now = Date().timeIntervalSince1970
        return now - lastFetchTime > cacheDuration
    }
}
