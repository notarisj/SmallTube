//
//  ChannelVideosViewModel.swift
//  SmallTube
//

import Foundation
import SwiftUI
import OSLog

class ChannelVideosViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var channelDescription: String = ""
    @Published var currentAlert: AlertType?

    private let cacheDuration: TimeInterval = 900

    private let logger = AppLogger.network

    // Computed so changes via Settings are always picked up.
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }

    // MARK: - Cache helpers (per-channel)

    private func cache(for channelId: String) -> CacheService<[CachedYouTubeVideo]> {
        CacheService(filename: "channel_\(channelId).json", ttl: cacheDuration)
    }

    // MARK: - Public API

    func loadVideos(for channel: YouTubeChannel) {
        guard !apiKey.isEmpty else {
            logger.warning("loadVideos aborted: API key missing")
            DispatchQueue.main.async { self.currentAlert = .apiError }
            return
        }

        let channelCache = cache(for: channel.id)
        if let cached = channelCache.load(), !cached.isEmpty, !channelCache.isExpired {
            logger.debug("Cache hit for channel \(channel.id, privacy: .public): \(cached.count) videos")
            DispatchQueue.main.async { self.videos = cached }
            return
        }

        let urlString = "https://www.googleapis.com/youtube/v3/search?part=id,snippet&channelId=\(channel.id)&maxResults=20&key=\(apiKey)&type=video&order=date"
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL for channel search — channelId: \(channel.id, privacy: .public)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.logger.error("Channel search error [\(channel.id, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { self.currentAlert = .apiError }
                return
            }
            guard let data else {
                DispatchQueue.main.async { self.currentAlert = .apiError }
                return
            }

            do {
                let searchResponse = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let videoIds = searchResponse.items.map { $0.id }.joined(separator: ",")
                guard !videoIds.isEmpty else {
                    self.logger.info("No videos found for channel \(channel.id, privacy: .public)")
                    DispatchQueue.main.async {
                        self.videos = []
                        self.currentAlert = .noResults
                    }
                    return
                }
                self.fetchVideoDetails(videoIds: videoIds, channelId: channel.id)
            } catch {
                self.logger.error("Channel search decode error [\(channel.id, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }

    // MARK: - Private

    private func fetchVideoDetails(videoIds: String, channelId: String) {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=contentDetails,snippet&id=\(videoIds)&key=\(apiKey)") else {
            logger.error("Invalid URL for video details — channelId: \(channelId, privacy: .public)")
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.logger.error("Video details error [\(channelId, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            }
            guard let data else { return }

            do {
                let videoResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
                let valid = videoResponse.items.filter { ($0.durationSeconds ?? Int.max) >= 180 }
                let cached = valid.map { CachedYouTubeVideo(from: $0) }
                self.logger.debug("Channel \(channelId, privacy: .public): \(cached.count)/\(videoResponse.items.count) videos kept (≥3 min)")

                DispatchQueue.main.async {
                    self.videos = cached
                    self.cache(for: channelId).save(cached)
                    self.currentAlert = cached.isEmpty ? .noResults : nil
                }
            } catch {
                self.logger.error("Video details decode error [\(channelId, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            }
        }.resume()
    }
}
