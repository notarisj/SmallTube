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
    private let cacheDuration: TimeInterval = 1000
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }

    var resultsCount: String {
        get { UserDefaults.standard.string(forKey: "resultsCount") ?? "10" }
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
            
            // Fetch videos from each channel
            self.fetchVideos(from: channelIds) { fetchedVideos in
                // Sort the videos by some criterion, e.g., title or date
                // The snippet returned typically has a publishTime we can use to sort by date.
                // For simplicity, let's just leave them as-is or sort by title.
                // If you need sorting by publish date, you'll have to parse it out of snippet (if included).
                
                let sortedVideos = fetchedVideos // Add sorting logic if needed
                DispatchQueue.main.async {
                    self.videos = sortedVideos
                    self.currentAlert = self.videos.isEmpty ? .noResults : nil
                    self.cacheHomeFeedVideos(self.videos)
                }
            }
        }
    }

    private func fetchSubscriptions(token: String, completion: @escaping ([String]) -> Void) {
        // Fetch the user's subscriptions: channel IDs.
        // Endpoint: GET https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true
        // Requires authorization with Bearer token
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true&maxResults=10") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            do {
                let subResponse = try JSONDecoder().decode(SubscriptionListResponse.self, from: data)
                // Extract up to 10 channel IDs from response
                let channelIds = subResponse.items.prefix(10).map { $0.snippet.resourceId.channelId }
                completion(channelIds)
            } catch {
                print("Failed to parse subscriptions: \(error)")
                completion([])
            }
        }.resume()
    }

    private func fetchVideos(from channelIds: [String], completion: @escaping ([CachedYouTubeVideo]) -> Void) {
        guard !channelIds.isEmpty else {
            completion([])
            return
        }

        // We will fetch videos from all channels concurrently and then combine results.
        // One approach: For each channel, use the search endpoint filtered by channelId:
        // GET https://www.googleapis.com/youtube/v3/search?channelId={id}&part=snippet&maxResults={count}&order=date&key={apiKey}&type=video
        // This fetches recent videos from the channel.
        
        let group = DispatchGroup()
        var allVideos: [CachedYouTubeVideo] = []
        let maxResults = resultsCount
        
        for channelId in channelIds {
            group.enter()
            let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=\(channelId)&maxResults=\(maxResults)&order=date&key=\(apiKey)&type=video"
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                guard let data = data, error == nil else { return }
                
                do {
                    let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                    let cachedVideos = response.items.map { CachedYouTubeVideo(from: $0) }
                    allVideos.append(contentsOf: cachedVideos)
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                       errorResponse.error.code == 403 {
                        DispatchQueue.main.async {
                            self.currentAlert = .quotaExceeded
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.currentAlert = .apiError
                        }
                    }
                }
            }.resume()
        }
        
        group.notify(queue: .main) {
            // Sort the videos by publish date (newest first)
            let sortedVideos = allVideos.sorted(by: { $0.publishedAt > $1.publishedAt })
            completion(sortedVideos)
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
