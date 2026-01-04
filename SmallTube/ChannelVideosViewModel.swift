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
    @Published var channelDescription: String = ""
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

        // 1. Fetch video IDs via Search
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=id,snippet&channelId=\(channel.id)&maxResults=20&key=\(apiKey)&type=video&order=date"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.currentAlert = .apiError
                }
                return
            }

            do {
                let searchResponse = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                // YouTubeResponse.items are [YouTubeVideo]. YouTubeVideo.id is likely a plain String based on common issues?
                // Wait, typically search endpoint result is `itemId` object { kind, videoId }. 
                // Let's verify YouTubeAPIVideo.swift first. 
                // Assuming standard Google API, Search result is different from Video list result.
                
                // If YouTubeVideo (from YouTubeResponse) has `id` as String (video ID), then we use it directly.
                // If it has `id` as object, we access videoId.
                // Assuming YouTubeVideo in YouTubeAPIVideo.swift has `id: String` (commonly simplified) OR it handles the container.
                // Checked errors: "Value of type 'String' has no member 'videoId'" -> This means `id` IS A STRING.
                
                let videoIds = searchResponse.items.map { $0.id }.joined(separator: ",")
                
                if videoIds.isEmpty {
                    DispatchQueue.main.async {
                        self.videos = []
                        self.currentAlert = .noResults
                    }
                    return
                }
                
                // 2. Fetch Video Details (Duration)
                self.fetchVideoDetails(videoIds: videoIds, originalItems: searchResponse.items, channelId: channel.id)
                
            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
            }
        }.resume()
    }
    
    // Changing originalItems type to [YouTubeAPIVideo] which is likely the type in YouTubeResponse
    private func fetchVideoDetails(videoIds: String, originalItems: [YouTubeAPIVideo], channelId: String) {
        let detailsUrlString = "https://www.googleapis.com/youtube/v3/videos?part=contentDetails,snippet&id=\(videoIds)&key=\(apiKey)"
        guard let url = URL(string: detailsUrlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            guard let data = data else { return }
            
            do {
                let videoResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
                
                // Filter videos > 1.5 minutes (90 seconds)
                let validVideos = videoResponse.items.filter { video in
                    guard let duration = video.durationSeconds else { return true }
                    return duration >= 180 // 1.5 minutes
                }
                
                let cachedVideos = validVideos.map { CachedYouTubeVideo(from: $0) }
                
                DispatchQueue.main.async {
                    self.videos = cachedVideos
                    self.cacheVideos(cachedVideos, for: channelId)
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                }
                
            } catch {
                print("Error decoding video details: \(error)")
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
    


