//
//  HomeFeedViewModel.swift
//  SmallTube
//

import Foundation
import OSLog

@MainActor
final class HomeFeedViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?
    @Published var isLoading = false

    private var cache: CacheService<[CachedYouTubeVideo]> {
        CacheService(filename: "homeFeed.json", ttl: TimeInterval(AppPreferences.cacheTimeout.rawValue))
    }
    private let logger = AppLogger.network
    private var currentTask: Task<Void, Never>?

    // Injected so the caller can share one SubscriptionsViewModel instance.
    private let subscriptionsViewModel: SubscriptionsViewModel

    init(subscriptionsViewModel: SubscriptionsViewModel) {
        self.subscriptionsViewModel = subscriptionsViewModel
    }

    // MARK: - Public API

    func loadHomeFeed(ignoreCache: Bool = false) async {
        guard !AppPreferences.apiKeys.isEmpty else {
            logger.warning("loadHomeFeed aborted: API key is missing")
            currentAlert = .apiError
            return
        }

        isLoading = true
        defer { isLoading = false }

        if ignoreCache {
            videos = []
        }

        if !ignoreCache, let cached = cache.load(), !cached.isEmpty, !cache.isExpired {
            logger.debug("Loaded \(cached.count) videos from cache")
            videos = cached
            return
        }

        await fetchFeed()
    }

    /// Starts a fresh feed fetch, cancelling any in-flight request first.
    /// Use this from toolbar buttons.
    func refreshFeed() {
        currentTask?.cancel()
        currentTask = Task {
            await loadHomeFeed(ignoreCache: true)
        }
    }

    private func fetchFeed() async {
        let subscriptions = await subscriptionsViewModel.fetchSubscriptions()

        guard !subscriptions.isEmpty else {
            logger.info("No subscriptions found — home feed empty")
            videos = []
            currentAlert = .noResults
            return
        }

        let selected = Array(subscriptions.shuffled().prefix(15))
        logger.debug("Fetching videos for \(selected.count) randomly-selected subscriptions")

        do {
            var fetched = try await fetchVideos(from: selected.map { $0.id })
            
            // Assign channel thumbnails from already loaded subscriptions
            let subDict = Dictionary(uniqueKeysWithValues: subscriptions.map { ($0.id, $0.thumbnailURL) })
            for i in 0..<fetched.count {
                if let url = subDict[fetched[i].channelId] {
                    fetched[i].channelIconURL = url
                }
            }
            
            videos = fetched
            cache.save(fetched)
            currentAlert = fetched.isEmpty ? .noResults : nil
        } catch is CancellationError {
            logger.debug("Home feed fetch cancelled")
        } catch let error as URLError where error.code == .cancelled {
            logger.debug("Home feed fetch cancelled via URLSession")
        } catch {
            logger.error("Home feed fetch failed: \(error.localizedDescription, privacy: .public)")
            currentAlert = .apiError
        }
    }

    // MARK: - Private helpers

    private func fetchVideos(from channelIds: [String]) async throws -> [CachedYouTubeVideo] {
        try await withThrowingTaskGroup(of: [CachedYouTubeVideo].self) { group in
            let maxPerChannel = min(AppPreferences.resultsCount, 10)
            for channelId in channelIds {
                group.addTask {
                    guard let playlistId = try? await self.uploadsPlaylistId(for: channelId) else { return [] }
                    return (try? await self.videosFromPlaylist(playlistId: playlistId, maxResults: maxPerChannel)) ?? []
                }
            }
            var all: [CachedYouTubeVideo] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all.sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    private func uploadsPlaylistId(for channelId: String) async throws -> String? {
        let data = try await NetworkService.fetchYouTube { apiKey in
            URL(string: "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=\(channelId)&key=\(apiKey)")
        }
        let decoded = try JSONDecoder().decode(ChannelContentResponse.self, from: data)
        let pid = decoded.items.first?.contentDetails.relatedPlaylists.uploads
        if let pid { logger.debug("Uploads playlist for \(channelId, privacy: .public): \(pid, privacy: .public)") }
        else        { logger.info("No uploads playlist for channel \(channelId, privacy: .public)") }
        return pid
    }

    private func videosFromPlaylist(playlistId: String, maxResults: Int) async throws -> [CachedYouTubeVideo] {
        let data = try await NetworkService.fetchYouTube { apiKey in
            URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=\(playlistId)&maxResults=\(maxResults)&key=\(apiKey)")
        }
        let decoded = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
        let videoIds = decoded.items.compactMap { $0.snippet.resourceId.videoId }
        logger.debug("Playlist \(playlistId, privacy: .public): \(videoIds.count) video IDs")
        return try await videoDetails(for: videoIds)
    }

    private func videoDetails(for videoIds: [String]) async throws -> [CachedYouTubeVideo] {
        let batches = stride(from: 0, to: videoIds.count, by: 50).map {
            Array(videoIds[$0..<min($0 + 50, videoIds.count)])
        }
        return try await withThrowingTaskGroup(of: [CachedYouTubeVideo].self) { group in
            for batch in batches {
                group.addTask {
                    let ids = batch.joined(separator: ",")
                    let data = try await NetworkService.fetchYouTube { apiKey in
                        URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=\(ids)&key=\(apiKey)")
                    }
                    let decoded = try JSONDecoder().decode(VideoListResponse.self, from: data)
                    let valid = decoded.items.filter { ($0.durationSeconds ?? Int.max) >= 180 }
                    self.logger.debug("Video details batch: \(valid.count)/\(decoded.items.count) kept (≥3 min)")
                    return valid.map { CachedYouTubeVideo(from: $0) }
                }
            }
            var all: [CachedYouTubeVideo] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }
    }
}

// MARK: - API Response Models

struct ChannelContentResponse: Decodable {
    let items: [ChannelContentItem]
}

struct ChannelContentItem: Decodable {
    let contentDetails: ContentDetails
}

struct ContentDetails: Decodable {
    let relatedPlaylists: RelatedPlaylists
}

struct RelatedPlaylists: Decodable {
    let uploads: String
}

struct PlaylistItemsResponse: Decodable {
    let items: [PlaylistItem]
}

struct PlaylistItem: Decodable {
    let snippet: PlaylistSnippet
}

struct PlaylistSnippet: Decodable {
    let resourceId: ResourceID
}

struct ResourceID: Decodable {
    let videoId: String
}
