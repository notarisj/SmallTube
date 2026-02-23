//
//  YouTubeViewModel.swift
//  SmallTube
//

import Foundation
import SwiftUI
import OSLog

enum AlertType: Identifiable {
    case noResults, apiError, emptyQuery, quotaExceeded, credsMismatch, unknownError
    var id: Int {
        switch self {
        case .noResults:    return 0
        case .apiError:     return 1
        case .emptyQuery:   return 2
        case .quotaExceeded:return 3
        case .credsMismatch:return 4
        case .unknownError: return 5
        }
    }
}

class YouTubeViewModel: ObservableObject {
    @Published var videos = [CachedYouTubeVideo]()
    @Published var currentAlert: AlertType?

    private let trendingCache = CacheService<[CachedYouTubeVideo]>(filename: "trending.json", ttl: 300)
    private let logger = AppLogger.network

    // MARK: - UserDefaults (user preferences only)

    @Published var lastSearches: [String] = [] {
        didSet { UserDefaults.standard.set(lastSearches, forKey: "lastSearches") }
    }

    init() {
        self.lastSearches = UserDefaults.standard.array(forKey: "lastSearches") as? [String] ?? []
    }

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

    // MARK: - Search

    func searchVideos(query: String) {
        guard !query.isEmpty else {
            DispatchQueue.main.async { self.currentAlert = .emptyQuery }
            return
        }

        DispatchQueue.main.async { self.videos = [] }

        // Persist query (deduplicate and move to top, max 10)
        var searches = lastSearches
        searches.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        searches.insert(query, at: 0)
        let updated = Array(searches.prefix(10))
        
        DispatchQueue.main.async {
            self.lastSearches = updated
        }

        guard !apiKey.isEmpty else {
            logger.warning("searchVideos aborted: API key missing")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            return
        }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoDuration=long&q=\(encoded)&maxResults=\(resultsCount)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            logger.error("Invalid search URL for query: \(query, privacy: .private)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.logger.error("Search network error: \(error.localizedDescription, privacy: .public)")
            }
            guard let data else { return }
            do {
                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let cached = response.items.map { CachedYouTubeVideo(from: $0) }
                DispatchQueue.main.async {
                    self.videos = cached
                    self.currentAlert = cached.isEmpty ? .noResults : nil
                }
            } catch {
                self.logger.error("Search decode error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }

    // MARK: - Trending

    func loadTrendingVideos() {
        guard !apiKey.isEmpty else {
            logger.warning("loadTrendingVideos aborted: API key missing")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            return
        }

        if let cached = trendingCache.load(), !cached.isEmpty, !trendingCache.isExpired {
            logger.debug("Returning \(cached.count) trending videos from cache")
            DispatchQueue.main.async {
                self.videos = cached
                self.currentAlert = cached.isEmpty ? .noResults : nil
            }
            return
        }

        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&maxResults=\(resultsCount)&regionCode=\(countryCode)&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            logger.error("Invalid trending URL")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.logger.error("Trending network error: \(error.localizedDescription, privacy: .public)")
            }
            guard let data else { return }
            do {
                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let cached = response.items.map { CachedYouTubeVideo(from: $0) }
                DispatchQueue.main.async {
                    self.videos = cached
                    self.currentAlert = cached.isEmpty ? .noResults : nil
                    self.trendingCache.save(cached)
                }
            } catch {
                self.logger.error("Trending decode error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }

    // MARK: - Search History

    func searchSuggestions(query: String) -> [String] {
        guard !query.isEmpty else { return lastSearches }
        return lastSearches.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func deleteSearches(at offsets: IndexSet) {
        var searches = lastSearches
        searches.remove(atOffsets: offsets)
        lastSearches = searches
    }

    func removeSearch(_ query: String) {
        var searches = lastSearches
        searches.removeAll { $0 == query }
        lastSearches = searches
    }

    func clearAllSearches() {
        lastSearches = []
    }
}
