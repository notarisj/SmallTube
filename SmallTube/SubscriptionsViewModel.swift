//
//  SubscriptionsViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import Foundation
import SwiftUI

class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [YouTubeChannel] = []
    @Published var currentAlert: AlertType?
    
    private let subscriptionsCacheKey = "subscriptionsCacheKey"
    private let subscriptionsCacheDateKey = "subscriptionsCacheDateKey"
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }
    
    var resultsCount: String {
        get { UserDefaults.standard.string(forKey: "resultsCount") ?? "10" }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }
    
    var countryCode: String {
        get { UserDefaults.standard.string(forKey: "countryCode") ?? "US" }
        set { UserDefaults.standard.set(newValue, forKey: "countryCode") }
    }

    func loadSubscriptions(token: String?, completion: @escaping ([YouTubeChannel]) -> Void) {
        guard let token = token else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
                completion([])
            }
            return
        }

        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
                completion([])
            }
            return
        }

        // Check cache
        if let cachedSubs = loadCachedSubscriptions(), !cachedSubs.isEmpty, !isCacheExpired() {
            DispatchQueue.main.async {
                self.subscriptions = cachedSubs
                completion(cachedSubs)
            }
            return
        }

        let urlString = "https://www.googleapis.com/youtube/v3/subscriptions?part=snippet&mine=true&maxResults=250&key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { (data, response, error) in
            self.handleSubscriptionResponse(data: data, response: response, error: error) { fetchedChannels in
                DispatchQueue.main.async {
                    self.subscriptions = fetchedChannels
                    self.cacheSubscriptions(fetchedChannels)
                    completion(fetchedChannels)
                }
            }
        }.resume()
    }

    private func handleSubscriptionResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping ([YouTubeChannel]) -> Void) {
        guard let data = data else {
            completion([])
            return
        }

        do {
            let response = try JSONDecoder().decode(SubscriptionResponse.self, from: data)
            let channels = response.items.map { item in
                YouTubeChannel(
                    id: item.snippet.resourceId.channelId,
                    title: item.snippet.title,
                    description: item.snippet.description,
                    thumbnailURL: item.snippet.thumbnails.default.url
                )
            }
            completion(channels)
        } catch {
            DispatchQueue.main.async {
                self.currentAlert = ErrorHandler.mapErrorToAlertType(data: data, error: error)
            }
        }
    }
    
    // MARK: - Caching
    private func cacheSubscriptions(_ channels: [YouTubeChannel]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(channels)
            UserDefaults.standard.set(data, forKey: subscriptionsCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: subscriptionsCacheDateKey)
        } catch {
            print("Failed to cache subscriptions: \(error)")
        }
    }
    
    private func loadCachedSubscriptions() -> [YouTubeChannel]? {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsCacheKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([YouTubeChannel].self, from: data)
        } catch {
            print("Failed to decode cached subscriptions: \(error)")
            return nil
        }
    }
    
    private func isCacheExpired() -> Bool {
        let lastFetchTime = UserDefaults.standard.double(forKey: subscriptionsCacheDateKey)
        guard lastFetchTime > 0 else {
            return true
        }
        let now = Date().timeIntervalSince1970
        return now - lastFetchTime > cacheDuration
    }
}

// MARK: - Subscription Response Models
struct SubscriptionResponse: Decodable {
    let items: [SubscriptionItem]
}

struct SubscriptionItem: Decodable {
    let snippet: SubscriptionSnippet
}

struct SubscriptionSnippet: Decodable {
    let title: String
    let description: String
    let resourceId: ResourceId
    let thumbnails: ThumbnailSet
}

struct ResourceId: Decodable {
    let channelId: String
}

struct ThumbnailSet: Decodable {
    let `default`: Thumbnail
}

struct Thumbnail: Decodable {
    let url: URL
}
