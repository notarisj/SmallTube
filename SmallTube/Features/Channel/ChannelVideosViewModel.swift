//
//  ChannelVideosViewModel.swift
//  SmallTube
//

import Foundation
import OSLog

@MainActor
final class ChannelVideosViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?
    @Published var isLoading = false

    private var cacheTTL: TimeInterval { TimeInterval(AppPreferences.cacheTimeout.rawValue) }
    private let logger = AppLogger.network

    // MARK: - Public API

    func loadVideos(channelId: String, ignoreCache: Bool = false) async {
        guard !AppPreferences.apiKeys.isEmpty else {
            logger.warning("loadVideos aborted: API key missing")
            currentAlert = .apiError
            return
        }

        isLoading = true
        defer { isLoading = false }

        let channelCache = CacheService<[CachedYouTubeVideo]>(filename: "channel_\(channelId).json", ttl: cacheTTL)
        if !ignoreCache, let cached = channelCache.load(), !cached.isEmpty, !channelCache.isExpired {
            logger.debug("Cache hit for channel \(channelId, privacy: .public): \(cached.count) videos")
            videos = cached
            return
        }

        await fetchVideos(channelId: channelId, cache: channelCache)
    }

    // MARK: - Private

    private func fetchVideos(
        channelId: String,
        cache: CacheService<[CachedYouTubeVideo]>
    ) async {
        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                let urlString = "https://www.googleapis.com/youtube/v3/search?part=id,snippet&channelId=\(channelId)&maxResults=20&key=\(apiKey)&type=video&order=date"
                return URL(string: urlString)
            }
            let searchResponse = try JSONDecoder().decode(YouTubeResponse.self, from: data)
            let videoIds = searchResponse.items.map { $0.id }.joined(separator: ",")

            guard !videoIds.isEmpty else {
                logger.info("No videos found for channel \(channelId, privacy: .public)")
                videos = []
                currentAlert = .noResults
                return
            }

            let detailed = try await fetchVideoDetails(videoIds: videoIds, channelId: channelId)
            videos = detailed
            cache.save(detailed)
            currentAlert = detailed.isEmpty ? .noResults : nil
        } catch {
            logger.error("Channel videos fetch failed [\(channelId, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            currentAlert = ErrorHandler.mapErrorToAlertType(data: nil, error: error)
        }
    }

    private func fetchVideoDetails(videoIds: String, channelId: String) async throws -> [CachedYouTubeVideo] {
        let data = try await NetworkService.fetchYouTube { apiKey in
            URL(string: "https://www.googleapis.com/youtube/v3/videos?part=contentDetails,snippet&id=\(videoIds)&key=\(apiKey)")
        }
        let videoResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
        let valid = videoResponse.items.filter { ($0.durationSeconds ?? Int.max) >= 180 }
        logger.debug("Channel \(channelId, privacy: .public): \(valid.count)/\(videoResponse.items.count) videos kept (≥3 min)")
        var cached = valid.map { CachedYouTubeVideo(from: $0) }
        
        if let thumbnails = try? await NetworkService.fetchChannelThumbnails(for: [channelId]),
           let iconURL = thumbnails[channelId] {
            for i in 0..<cached.count {
                cached[i].channelIconURL = iconURL
            }
        }
        
        return cached
    }
}
