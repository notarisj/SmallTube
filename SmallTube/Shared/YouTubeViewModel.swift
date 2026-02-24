//
//  YouTubeViewModel.swift
//  SmallTube
//
//  Handles Search and Trending data fetching.
//  @MainActor guarantees all @Published mutations occur on the main thread
//  without manual DispatchQueue.main.async calls.
//

import Foundation
import OSLog

// MARK: - Alert

enum AlertType: Identifiable {
    case noResults, apiError, emptyQuery, quotaExceeded, credsMismatch, unknownError

    var id: Int {
        switch self {
        case .noResults:     return 0
        case .apiError:      return 1
        case .emptyQuery:    return 2
        case .quotaExceeded: return 3
        case .credsMismatch: return 4
        case .unknownError:  return 5
        }
    }
}

// MARK: - ViewModel

@MainActor
final class YouTubeViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?
    @Published var isLoading = false

    @Published var lastSearches: [String] = [] {
        didSet { AppPreferences.lastSearches = lastSearches }
    }

    private var trendingCache: CacheService<[CachedYouTubeVideo]> {
        CacheService(filename: "trending.json", ttl: TimeInterval(AppPreferences.cacheTimeout.rawValue))
    }
    private let logger = AppLogger.network
    private var currentTask: Task<Void, Never>?

    init() {
        self.lastSearches = AppPreferences.lastSearches
    }

    // MARK: - Search

    func searchVideos(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { currentAlert = .emptyQuery; return }

        isLoading = true
        defer { isLoading = false }

        videos = []

        // Deduplicate and move to top (max 10)
        var searches = lastSearches
        searches.removeAll { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        searches.insert(trimmed, at: 0)
        lastSearches = Array(searches.prefix(10))

        guard !AppPreferences.apiKeys.isEmpty else {
            logger.warning("searchVideos aborted: API key missing")
            currentAlert = .apiError
            return
        }

        await performSearch(query: trimmed)
    }

    private func performSearch(query: String) async {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            logger.error("Invalid search URL for query: \(query, privacy: .private)")
            return
        }

        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoDuration=long&q=\(encoded)&maxResults=\(AppPreferences.resultsCount)&key=\(apiKey)")
            }
            let searchResponse = try JSONDecoder().decode(YouTubeResponse.self, from: data)
            let videoIds = searchResponse.items.map { $0.id }.joined(separator: ",")
            
            if videoIds.isEmpty {
                videos = []
                currentAlert = .noResults
                return
            }

            // Fetch full details for these videos (v3/search returns truncated descriptions)
            let detailsData = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=\(videoIds)&key=\(apiKey)")
            }
            let detailsResponse = try JSONDecoder().decode(YouTubeResponse.self, from: detailsData)
            let cached = detailsResponse.items.map { CachedYouTubeVideo(from: $0) }
            
            videos = cached
            currentAlert = cached.isEmpty ? .noResults : nil
        } catch is CancellationError {
            // Task was cancelled (e.g. user navigated away) — not an error.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            currentAlert = ErrorHandler.mapErrorToAlertType(data: nil, error: error)
        }
    }

    // MARK: - Trending

    func loadTrendingVideos(ignoreCache: Bool = false) async {
        guard !AppPreferences.apiKeys.isEmpty else {
            logger.warning("loadTrendingVideos aborted: API key missing")
            currentAlert = .apiError
            return
        }

        isLoading = true
        defer { isLoading = false }

        if ignoreCache {
            videos = []
        }

        if !ignoreCache, let cached = trendingCache.load(), !cached.isEmpty, !trendingCache.isExpired {
            logger.debug("Returning \(cached.count) trending videos from cache")
            videos = cached
            return
        }

        await fetchTrending()
    }

    /// Starts a fresh trending fetch, cancelling any in-flight request first.
    /// Use this from toolbar buttons so the Task lifecycle is managed here.
    func refreshTrending() {
        currentTask?.cancel()
        currentTask = Task {
            await loadTrendingVideos(ignoreCache: true)
        }
    }

    private func fetchTrending() async {
        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet&chart=mostPopular&maxResults=\(AppPreferences.resultsCount)&regionCode=\(AppPreferences.countryCode)&key=\(apiKey)")
            }
            let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
            let cached = response.items.map { CachedYouTubeVideo(from: $0) }
            videos = cached
            currentAlert = cached.isEmpty ? .noResults : nil
            trendingCache.save(cached)
        } catch is CancellationError {
            // Task was cancelled — silently ignore, not a user-facing error.
            logger.debug("Trending fetch cancelled")
        } catch let error as URLError where error.code == .cancelled {
            logger.debug("Trending fetch cancelled")
        } catch {
            logger.error("Trending failed: \(error.localizedDescription, privacy: .public)")
            currentAlert = ErrorHandler.mapErrorToAlertType(data: nil, error: error)
        }
    }

    // MARK: - Search History

    func searchSuggestions(query: String) -> [String] {
        guard !query.isEmpty else { return lastSearches }
        return lastSearches.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    func deleteSearches(at offsets: IndexSet) {
        lastSearches.remove(atOffsets: offsets)
    }

    func removeSearch(_ query: String) {
        lastSearches.removeAll { $0 == query }
    }

    func clearAllSearches() {
        lastSearches = []
    }
}
