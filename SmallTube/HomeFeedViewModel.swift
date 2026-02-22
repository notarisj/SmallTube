//
//  HomeFeedViewModel.swift
//  SmallTube
//

import Foundation
import SwiftUI
import OSLog

class HomeFeedViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?

    private let cache = CacheService<[CachedYouTubeVideo]>(filename: "homeFeed.json", ttl: 900)
    private let logger = AppLogger.network

    // Injected so the caller can share one SubscriptionsViewModel instance.
    private let subscriptionsViewModel: SubscriptionsViewModel

    init(subscriptionsViewModel: SubscriptionsViewModel) {
        self.subscriptionsViewModel = subscriptionsViewModel
    }

    // MARK: - Computed UserDefaults properties (user preferences only)

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }

    var resultsCount: Int {
        get {
            let count = UserDefaults.standard.integer(forKey: "resultsCount")
            return count > 0 ? count : 10
        }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }

    // MARK: - Public API

    func loadHomeFeed(token: String? = nil) {
        guard !apiKey.isEmpty else {
            logger.warning("loadHomeFeed aborted: API key is missing")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            return
        }

        // Return cached data if still fresh
        if let cached = cache.load(), !cached.isEmpty, !cache.isExpired {
            logger.debug("Loaded \(cached.count) videos from cache")
            DispatchQueue.main.async {
                self.videos = cached
                self.currentAlert = cached.isEmpty ? .noResults : nil
            }
            return
        }

        logger.debug("Fetching subscriptions for home feed…")
        subscriptionsViewModel.loadImportedSubscriptions { [weak self] subscriptions in
            guard let self else { return }
            guard !subscriptions.isEmpty else {
                logger.info("No subscriptions found — home feed empty")
                DispatchQueue.main.async {
                    self.videos = []
                    self.currentAlert = .noResults
                }
                return
            }

            let selected = Array(subscriptions.shuffled().prefix(15))
            logger.debug("Fetching videos for \(selected.count) randomly-selected subscriptions")
            self.fetchVideos(from: selected.map { $0.id }) { [weak self] fetched in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.videos = fetched
                    self.cache.save(fetched)
                    self.currentAlert = fetched.isEmpty ? .noResults : nil
                }
            }
        }
    }

    // MARK: - Private

    private func fetchVideos(from channelIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        let group = DispatchGroup()
        var allVideos: [CachedYouTubeVideo] = []
        let accumQueue = DispatchQueue(label: "com.smalltube.homeFeed.accum")
        let maxPerChannel = min(resultsCount, 10)

        for channelId in channelIds {
            group.enter()
            getUploadsPlaylistId(for: channelId) { [weak self] playlistId in
                guard let self, let playlistId else {
                    group.leave()
                    return
                }
                self.fetchVideosFromPlaylist(playlistId: playlistId, maxResults: maxPerChannel) { videos in
                    accumQueue.sync { allVideos.append(contentsOf: videos) }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(allVideos.sorted { $0.publishedAt > $1.publishedAt })
        }
    }

    private func getUploadsPlaylistId(for channelId: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=\(channelId)&key=\(apiKey)") else {
            logger.error("Invalid URL for uploads playlist — channelId: \(channelId, privacy: .public)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: { completion(nil) }) else { return }

            do {
                let decoded = try JSONDecoder().decode(ChannelContentResponse.self, from: data)
                let playlistId = decoded.items.first?.contentDetails.relatedPlaylists.uploads
                if let pid = playlistId {
                    self.logger.debug("Uploads playlist for \(channelId, privacy: .public): \(pid, privacy: .public)")
                } else {
                    self.logger.info("No uploads playlist found for channel \(channelId, privacy: .public)")
                }
                completion(playlistId)
            } catch {
                self.logger.error("Decode uploads playlist failed [\(channelId, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion(nil)
            }
        }.resume()
    }

    private func fetchVideosFromPlaylist(playlistId: String, maxResults: Int, completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=\(playlistId)&maxResults=\(maxResults)&key=\(apiKey)") else {
            logger.error("Invalid URL for playlist items — playlistId: \(playlistId, privacy: .public)")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: { completion([]) }) else { return }

            do {
                let decoded = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
                let videoIds = decoded.items.compactMap { $0.snippet.resourceId.videoId }
                self.logger.debug("Playlist \(playlistId, privacy: .public): \(videoIds.count) video IDs")
                self.fetchVideoDetails(videoIds: videoIds, completion: completion)
            } catch {
                self.logger.error("Decode playlist items failed [\(playlistId, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion([])
            }
        }.resume()
    }

    private func fetchVideoDetails(videoIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        let batches = stride(from: 0, to: videoIds.count, by: 50).map {
            Array(videoIds[$0..<min($0 + 50, videoIds.count)])
        }

        var allVideos: [CachedYouTubeVideo] = []
        let group = DispatchGroup()
        let accumQueue = DispatchQueue(label: "com.smalltube.homeFeed.details.accum")

        for batch in batches {
            group.enter()
            let ids = batch.joined(separator: ",")
            guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=\(ids)&key=\(apiKey)") else {
                logger.error("Invalid URL for video details batch")
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self else { group.leave(); return }
                defer { group.leave() }
                guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: {}) else { return }

                do {
                    let decoded = try JSONDecoder().decode(VideoListResponse.self, from: data)
                    let valid = decoded.items.filter { ($0.durationSeconds ?? Int.max) >= 180 }
                    let cached = valid.map { CachedYouTubeVideo(from: $0) }
                    self.logger.debug("Video details batch: \(cached.count)/\(decoded.items.count) kept (≥3 min)")
                    accumQueue.sync { allVideos.append(contentsOf: cached) }
                } catch {
                    self.logger.error("Decode video details failed: \(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async {
                        self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                    }
                }
            }.resume()
        }

        group.notify(queue: .main) { completion(allVideos) }
    }

    // MARK: - Response Handling

    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        onFailure: @escaping () -> Void
    ) -> Data? {
        if let error {
            logger.error("Network error: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            onFailure()
            return nil
        }
        guard let http = response as? HTTPURLResponse else {
            logger.error("Non-HTTP response received")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            onFailure()
            return nil
        }
        guard (200...299).contains(http.statusCode) else {
            logger.error("HTTP \(http.statusCode) error")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            onFailure()
            return nil
        }
        guard let data else {
            logger.error("No data in response")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            onFailure()
            return nil
        }
        return data
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
