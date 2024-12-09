import Foundation
import SwiftUI

enum AlertType: Identifiable {
    case noResults, apiError, emptyQuery, quotaExceeded
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
        }
    }
}

class YouTubeViewModel: ObservableObject {
    @Published var videos = [YouTubeVideo]()
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
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=\(query)&maxResults=\(resultsCount)&key=\(apiKey)&type=video"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.videos = response.items
                        self.currentAlert = self.videos.isEmpty ? .noResults : nil
                    }
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                       errorResponse.error.code == 403 {
                        DispatchQueue.main.async {
                            self.currentAlert = .quotaExceeded
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.currentAlert = .apiError
                        }
                    }
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
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.videos = response.items
                        self.currentAlert = self.videos.isEmpty ? .noResults : nil
                        
                        // Update the cache with new results
                        self.cacheTrendingVideos(self.videos)
                    }
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                       errorResponse.error.code == 403 {
                        DispatchQueue.main.async {
                            self.currentAlert = .quotaExceeded
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.currentAlert = .apiError
                        }
                    }
                }
            }
        }.resume()
    }

    func searchSuggestions(query: String) -> [String] {
        return lastSearches
    }
    
    func deleteSearches(at offsets: IndexSet) {
        lastSearches.remove(atOffsets: offsets)
        lastSearches = lastSearches
    }
    
    // MARK: - Caching Methods
    
    private func cacheTrendingVideos(_ videos: [YouTubeVideo]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(videos)
            UserDefaults.standard.set(data, forKey: trendingCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: trendingCacheDateKey)
        } catch {
            print("Failed to cache trending videos: \(error)")
        }
    }
    
    private func loadCachedTrendingVideos() -> [YouTubeVideo]? {
        guard let data = UserDefaults.standard.data(forKey: trendingCacheKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            let videos = try decoder.decode([YouTubeVideo].self, from: data)
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

struct YouTubeResponse: Decodable {
    let items: [YouTubeVideo]
}

struct ErrorResponse: Decodable {
    let error: APIError
}

struct APIError: Decodable {
    let code: Int
    let message: String
    let errors: [ErrorDetail]
}

struct ErrorDetail: Decodable {
    let message: String
    let domain: String
    let reason: String
}
