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
    private let cacheDuration: TimeInterval = 10 // 1 hour

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }

    var resultsCount: Int {
        get { UserDefaults.standard.integer(forKey: "resultsCount") }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }

    /// Load the home feed from user's subscribed channels
    /// - parameter token: The OAuth access token of the logged-in user.
    func loadHomeFeed(token: String?) {
        guard let token = token else {
            // Not signed in
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }

        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }

        // Check cache first
        if let cachedVideos = loadCachedHomeFeedVideos(), !cachedVideos.isEmpty, !isCacheExpired() {
            DispatchQueue.main.async {
                self.videos = cachedVideos
                self.currentAlert = self.videos.isEmpty ? .noResults : nil
            }
            return
        }

        // Fetch subscriptions first
        fetchSubscriptions(token: token) { channelIds in
            guard !channelIds.isEmpty else {
                DispatchQueue.main.async {
                    self.videos = []
                    self.currentAlert = .noResults
                }
                return
            }

            // Fetch videos using the 'videos' endpoint with batch requests
            self.fetchVideos(from: channelIds) { fetchedVideos in
                DispatchQueue.main.async {
                    self.videos = fetchedVideos
                    self.cacheHomeFeedVideos(self.videos)
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                }
            }
        }
    }

    private func fetchSubscriptions(token: String, completion: @escaping ([String]) -> Void) {
        // Fetch the user's subscriptions: channel IDs.
        // Endpoint: GET https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true&maxResults=5
        // Requires authorization with Bearer token
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true&maxResults=20") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.currentAlert = .apiError
                }
                completion([])
                return
            }
            do {
                let subResponse = try JSONDecoder().decode(SubscriptionListResponse.self, from: data)
                // Extract up to 5 channel IDs from response
                let channelIds = subResponse.items.prefix(5).map { $0.snippet.resourceId.channelId }
                completion(channelIds)
            } catch {
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion([])
            }
        }.resume()
    }

    private func fetchVideos(from channelIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        // Step 1: For each channel, get the uploads playlist ID
        // Step 2: Fetch videos from the uploads playlists

        let group = DispatchGroup()
        var allVideos: [CachedYouTubeVideo] = []
        let maxResultsPerChannel = min(resultsCount, 10) // Limit to 5 videos per channel

        for channelId in channelIds {
            group.enter()
            getUploadsPlaylistId(for: channelId) { playlistId in
                guard let playlistId = playlistId else {
                    group.leave()
                    return
                }

                self.fetchVideosFromPlaylist(playlistId: playlistId, maxResults: maxResultsPerChannel) { videos in
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
        // Endpoint: GET https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id={channelId}&key={apiKey}
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=contentDetails&id=\(channelId)&key=\(apiKey)") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.currentAlert = .apiError
                }
                completion(nil)
                return
            }
            do {
                let channelResponse = try JSONDecoder().decode(ChannelContentResponse.self, from: data)
                if let playlistId = channelResponse.items.first?.contentDetails.relatedPlaylists.uploads {
                    completion(playlistId)
                } else {
                    completion(nil)
                }
            } catch {
                print("Failed to parse channel content details: \(error)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion(nil)
            }
        }.resume()
    }

    private func fetchVideosFromPlaylist(playlistId: String, maxResults: Int, completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        // Endpoint: GET https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId={playlistId}&maxResults={maxResults}&key={apiKey}
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=\(playlistId)&maxResults=\(maxResults)&key=\(apiKey)") else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.currentAlert = .apiError
                }
                completion([])
                return
            }
            do {
                let playlistResponse = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
                let videoIds = playlistResponse.items.map { $0.snippet.resourceId.videoId }
                self.fetchVideoDetails(videoIds: videoIds) { videos in
                    completion(videos)
                }
            } catch {
                print("Failed to parse playlist items: \(error)")
                DispatchQueue.main.async {
                    self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
                }
                completion([])
            }
        }.resume()
    }

    private func fetchVideoDetails(videoIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        // Batch video IDs into groups of 50 (API limit)
        let batches = stride(from: 0, to: videoIds.count, by: 50).map {
            Array(videoIds[$0..<min($0 + 50, videoIds.count)])
        }

        var allVideos: [CachedYouTubeVideo] = []
        let group = DispatchGroup()

        for batch in batches {
            group.enter()
            let ids = batch.joined(separator: ",")
            guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(ids)&key=\(apiKey)") else {
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                guard let data = data, error == nil else { return }

                do {
                    let videoResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
                    let cachedVideos = videoResponse.items.map { CachedYouTubeVideo(from: $0) }
                    allVideos.append(contentsOf: cachedVideos)
                } catch {
                    print("Failed to parse video details: \(error)")
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
        } catch {
            print("Failed to cache home feed videos: \(error)")
        }
    }

    private func loadCachedHomeFeedVideos() -> [CachedYouTubeVideo]? {
        guard let data = UserDefaults.standard.data(forKey: homeFeedCacheKey) else { return nil }
        do {
            let videos = try JSONDecoder().decode([CachedYouTubeVideo].self, from: data)
            return videos
        } catch {
            print("Failed to decode cached home feed videos: \(error)")
            return nil
        }
    }

    private func isCacheExpired() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: homeFeedCacheDateKey)
        guard lastFetchTime > 0 else {
            return true // no cache date found
        }
        let now = Date().timeIntervalSince1970
        return now - lastFetchTime > cacheDuration
    }
}

// MARK: - Subscription Models

struct SubscriptionListResponse: Decodable {
    let items: [SubscriptionItem]
}

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

struct VideoListResponse: Decodable {
    let items: [YouTubeAPIVideo]
}
