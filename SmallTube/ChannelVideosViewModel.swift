//
//  ChannelVideosViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import Foundation
import SwiftUI

class ChannelVideosViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?

    private let apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
    private let cacheDuration: TimeInterval = 900 // 15 minutes

    // Cache keys are channel-specific
    private func cacheKey(for channelId: String) -> String {
        return "cachedVideos_\(channelId)"
    }

    private func cacheDateKey(for channelId: String) -> String {
        return "cachedVideosDate_\(channelId)"
    }

    func loadVideos(for channel: YouTubeChannel) {
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }

        // Check cache first
        if let cachedVideos = loadCachedVideos(for: channel.id), !cachedVideos.isEmpty, !isCacheExpired(for: channel.id) {
            DispatchQueue.main.async {
                self.videos = cachedVideos
            }
            return
        }

        // If not cached or cache expired, fetch from API
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=\(channel.id)&maxResults=20&key=\(apiKey)&type=video"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.currentAlert = .apiError
                }
                return
            }

            do {
                let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                let fetchedVideos = response.items.map { CachedYouTubeVideo(from: $0) }
                DispatchQueue.main.async {
                    self.videos = fetchedVideos
                    self.cacheVideos(fetchedVideos, for: channel.id)
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }

    // MARK: - Caching Methods

    private func cacheVideos(_ videos: [CachedYouTubeVideo], for channelId: String) {
        do {
            let data = try JSONEncoder().encode(videos)
            UserDefaults.standard.set(data, forKey: cacheKey(for: channelId))
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheDateKey(for: channelId))
            print("Cached \(videos.count) videos for channel \(channelId).")
        } catch {
            print("Failed to cache videos for channel \(channelId): \(error)")
        }
    }

    private func loadCachedVideos(for channelId: String) -> [CachedYouTubeVideo]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: channelId)) else {
            print("No cached videos found for channel \(channelId).")
            return nil
        }
        do {
            let videos = try JSONDecoder().decode([CachedYouTubeVideo].self, from: data)
            print("Loaded \(videos.count) cached videos for channel \(channelId).")
            return videos
        } catch {
            print("Failed to decode cached videos for channel \(channelId): \(error)")
            return nil
        }
    }

    private func isCacheExpired(for channelId: String) -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: cacheDateKey(for: channelId))
        guard lastFetchTime > 0 else {
            print("Cache date not found for channel \(channelId). Cache is expired.")
            return true // No cache date found
        }
        let now = Date().timeIntervalSince1970
        let expired = now - lastFetchTime > cacheDuration
        print("Cache expired for channel \(channelId): \(expired)")
        return expired
    }
}
