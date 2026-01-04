//
//  HomeFeedViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 12/10/24.
//

import Foundation
import SwiftUI

class HomeFeedViewModel: ObservableObject {
    @Published var videos: [CachedYouTubeVideo] = []
    @Published var currentAlert: AlertType?

    private let homeFeedCacheKey = "homeFeedVideosCacheKey"
    private let homeFeedCacheDateKey = "homeFeedVideosCacheDateKey"
    private let cacheDuration: TimeInterval = 900 // 15 minutes

    private let subscriptionsViewModel = SubscriptionsViewModel() // Fetch subscriptions

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }

    var resultsCount: Int {
        get {
            let count = UserDefaults.standard.integer(forKey: "resultsCount")
            return count > 0 ? count : 10 // Default to 10 if not set
        }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }

    /// Load the home feed from user's subscribed channels
    /// - Parameter token: The OAuth access token of the logged-in user.
    /// Load the home feed from user's subscribed channels
    /// - Parameter token: The OAuth access token (Deprecated, now unused).
    func loadHomeFeed(token: String?) {
        // Token check removed as we use public API + imported IDs now
        
        guard !apiKey.isEmpty else {
            print("API Key is missing.")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }

        // Step 1: Check for cached videos
        if let cachedVideos = loadCachedHomeFeedVideos(), !cachedVideos.isEmpty, !isCacheExpired() {
            print("Loaded \(cachedVideos.count) videos from cache.")
            DispatchQueue.main.async {
                self.videos = cachedVideos
                self.currentAlert = self.videos.isEmpty ? .noResults : nil
            }
            return
        }

        // Step 2: Fetch subscriptions (using imported CSV data)
        print("Fetching subscriptions...")
        subscriptionsViewModel.loadImportedSubscriptions { subscriptions in
            guard !subscriptions.isEmpty else {
                print("No subscriptions found.")
                DispatchQueue.main.async {
                    self.videos = []
                    self.currentAlert = .noResults
                }
                return
            }

            // Step 3: Select 15 random subscriptions
            let selectedSubscriptions = Array(subscriptions.shuffled().prefix(15))

            // Step 4: Fetch videos for the selected subscriptions
            print("Fetching videos for selected subscriptions...")
            self.fetchVideos(from: selectedSubscriptions.map { $0.id }) { fetchedVideos in
                DispatchQueue.main.async {
                    self.videos = fetchedVideos
                    self.cacheHomeFeedVideos(fetchedVideos)
                    self.currentAlert = fetchedVideos.isEmpty ? .noResults : nil
                }
            }
        }
    }

    private func fetchVideos(from channelIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        // Step 1: For each channel, get the uploads playlist ID
        // Step 2: Fetch videos from the uploads playlists

        let group = DispatchGroup()
        var allVideos: [CachedYouTubeVideo] = []
        let maxResultsPerChannel = min(resultsCount, 10) // Limit to 10 videos per channel

        for channelId in channelIds {
            group.enter()
            getUploadsPlaylistId(for: channelId) { playlistId in
                guard let playlistId = playlistId else {
                    print("No uploads playlist ID found for channel: \(channelId)")
                    group.leave()
                    return
                }

                self.fetchVideosFromPlaylist(playlistId: playlistId, maxResults: maxResultsPerChannel) { videos in
                    print("Fetched \(videos.count) videos from playlist: \(playlistId)")
                    allVideos.append(contentsOf: videos)
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // Sort the videos by publish date (newest first)
            let sortedVideos = allVideos.sorted(by: { $0.publishedAt > $1.publishedAt })
            completion(sortedVideos)
        }
    }

    private func getUploadsPlaylistId(for channelId: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&type=video&videoDuration=long&id=\(channelId)&key=\(apiKey)") else {
            print("Invalid URL for fetching uploads playlist ID for channel: \(channelId)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: {
                completion(nil)
            }) else {
                return
            }

            do {
                let channelResponse = try JSONDecoder().decode(ChannelContentResponse.self, from: data)
                if let playlistId = channelResponse.items.first?.contentDetails.relatedPlaylists.uploads {
                    print("Uploads playlist ID for channel \(channelId): \(playlistId)")
                    completion(playlistId)
                } else {
                    print("No uploads playlist found for channel: \(channelId)")
                    completion(nil)
                }
            } catch {
                print("Decoding uploads playlist ID failed for channel \(channelId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion(nil)
            }
        }.resume()
    }

    private func fetchVideosFromPlaylist(playlistId: String, maxResults: Int, completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&type=video&videoDuration=long&playlistId=\(playlistId)&maxResults=\(maxResults)&key=\(apiKey)") else {
            print("Invalid URL for fetching videos from playlist: \(playlistId)")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: {
                completion([])
            }) else {
                return
            }

            do {
                let playlistResponse = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
                let videoIds = playlistResponse.items.compactMap { $0.snippet.resourceId.videoId }
                print("Video IDs from playlist \(playlistId): \(videoIds)")
                self.fetchVideoDetails(videoIds: videoIds) { videos in
                    completion(videos)
                }
            } catch {
                print("Decoding videos from playlist \(playlistId) failed: \(error.localizedDescription)")
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

        for batch in batches {
            group.enter()
            let ids = batch.joined(separator: ",")
            guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id=\(ids)&key=\(apiKey)") else {
                print("Invalid URL for fetching video details for IDs: \(ids)")
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }

                guard let data = self.handleResponse(data: data, response: response, error: error, onFailure: {
                    return
                }) else {
                    return
                }

                do {
                    let videoResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
                    
                    // Filter out videos shorter than 90 seconds (1.5 minutes)
                    let validVideos = videoResponse.items.filter { video in
                        guard let duration = video.durationSeconds else { return true } // Keep if duration unknown? Or strict filter?
                        // Assuming filter means exclude known short videos.
                        // YouTubeAPIVideo returns nil if duration missing.
                        return duration >= 180
                    }
                    
                    let cachedVideos = validVideos.map { CachedYouTubeVideo(from: $0) }
                    print("Fetched \(cachedVideos.count) video details for IDs: \(ids) (Filtered from \(videoResponse.items.count))")
                    allVideos.append(contentsOf: cachedVideos)
                } catch {
                    print("Decoding video details for IDs \(ids) failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                    }
                }
            }.resume()
        }

        group.notify(queue: .main) {
            completion(allVideos)
        }
    }

    // MARK: - Caching Methods

    private func cacheHomeFeedVideos(_ videos: [CachedYouTubeVideo]) {
       do {
           let data = try JSONEncoder().encode(videos)
           UserDefaults.standard.set(data, forKey: homeFeedCacheKey)
           UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: homeFeedCacheDateKey)
           print("Cached \(videos.count) videos.")
       } catch {
           print("Failed to cache home feed videos: \(error.localizedDescription)")
       }
   }

   private func loadCachedHomeFeedVideos() -> [CachedYouTubeVideo]? {
       guard let data = UserDefaults.standard.data(forKey: homeFeedCacheKey) else {
           print("No cached videos found.")
           return nil
       }
       do {
           let videos = try JSONDecoder().decode([CachedYouTubeVideo].self, from: data)
           print("Loaded \(videos.count) cached videos.")
           return videos
       } catch {
           print("Failed to decode cached home feed videos: \(error.localizedDescription)")
           return nil
       }
   }

   private func isCacheExpired() -> Bool {
       let lastFetchTime = UserDefaults.standard.double(forKey: homeFeedCacheDateKey)
       guard lastFetchTime > 0 else {
           print("Cache date not found. Cache is expired.")
           return true // No cache date found
       }
       let now = Date().timeIntervalSince1970
       let expired = now - lastFetchTime > cacheDuration
       print("Cache expired: \(expired)")
       return expired
   }
    
    private func handleResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        onFailure: @escaping () -> Void
    ) -> Data? {
        if let error = error {
            print("Error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            onFailure()
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response.")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            onFailure()
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("HTTP Status Code: \(httpResponse.statusCode)")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            onFailure()
            return nil
        }

        guard let data = data else {
            print("No data received.")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            onFailure()
            return nil
        }

        return data
    }
}

// MARK: - Subscription Models
// SubscriptionListResponse and related items removed as unused


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


