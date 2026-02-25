//
//  SubscriptionsViewModel.swift
//  SmallTube
//

import Foundation
import SwiftUI
import OSLog

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [YouTubeChannel] = []
    @Published var currentAlert: AlertType?

    @AppStorage("subscriptionsSortOption") var sortOption: SortOption = .az

    enum SortOption: String, CaseIterable, Identifiable {
        case az = "A–Z"
        case za = "Z–A"
        var id: String { rawValue }
    }

    private let cache = CacheService<[YouTubeChannel]>(filename: "subscriptions.json", ttl: 86400 * 30)
    private let logger = AppLogger.data

    // MARK: - Load

    /// Fetches all subscriptions and updates `self.subscriptions`.
    /// Returns the loaded array for callers that need it (e.g. HomeFeedViewModel).
    func fetchSubscriptions() async -> [YouTubeChannel] {

        let channelIds = SubscriptionManager.shared.subscriptionIds
        guard !channelIds.isEmpty else {
            logger.info("No stored subscription IDs found")
            subscriptions = []
            return []
        }

        // 1) Load optimistically from cache before network
        var initialDict = [String: YouTubeChannel]()
        if let cached = cache.load() {
            for channel in cached {
                if channelIds.contains(channel.id) {
                    initialDict[channel.id] = channel
                }
            }
        }
        for id in channelIds {
            if initialDict[id] == nil {
                initialDict[id] = YouTubeChannel(
                    id: id,
                    title: "Channel \(id.prefix(8))",
                    description: "Loading...",
                    thumbnailURL: URL(string: "about:blank")!
                )
            }
        }
        subscriptions = sort(Array(initialDict.values))

        guard !AppPreferences.apiKeys.isEmpty else {
            logger.warning("fetchSubscriptions skipping API fetch: API key missing")
            currentAlert = .apiError
            return subscriptions
        }

        // 2) Perform network fetch
        let batches = channelIds.chunked(into: 50)
        let channels = await withTaskGroup(of: [YouTubeChannel].self) { group in
            for batch in batches {
                group.addTask {
                    await self.fetchChannelBatch(ids: batch)
                }
            }
            var all: [YouTubeChannel] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }

        var fetchedDict = [String: YouTubeChannel]()
        for channel in channels {
            fetchedDict[channel.id] = channel
        }
        
        // If network failed entirely, use cache/placeholders we already populated
        // We only overwrite the cache if we got actual data
        if !channels.isEmpty {
            for channel in channels {
                initialDict[channel.id] = channel
            }
            let finalChannels = Array(initialDict.values)
            cache.save(finalChannels)
            let sorted = sort(finalChannels)
            subscriptions = sorted
            return sorted
        } else {
            return subscriptions // Return what we optimistically loaded
        }

    }

    /// Convenience wrapper for call-sites that don't need the return value.
    func loadImportedSubscriptions() {
        Task { await fetchSubscriptions() }
    }

    // MARK: - Sorting

    func updateSortOption(_ option: SortOption) {
        sortOption = option
        subscriptions = sort(subscriptions)
    }

    private func sort(_ channels: [YouTubeChannel]) -> [YouTubeChannel] {
        switch sortOption {
        case .az: return channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .za: return channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }

    // MARK: - Mutations

    func deleteChannel(at offsets: IndexSet) {
        let idsToRemove = offsets.map { subscriptions[$0].id }
        SubscriptionManager.shared.removeSubscriptionIds(idsToRemove)
        subscriptions.remove(atOffsets: offsets)
        logger.info("Removed \(idsToRemove.count) subscription(s)")
    }

    func removeChannel(id: String) {
        if let index = subscriptions.firstIndex(where: { $0.id == id }) {
            deleteChannel(at: IndexSet(integer: index))
        }
    }

    func addChannel(id: String) {
        SubscriptionManager.shared.addSubscription(id: id)
        Task { await fetchSubscriptions() }
    }

    // MARK: - Channel Search (async)

    func searchYouTubeChannels(query: String) async -> [YouTubeChannel] {
        guard !query.isEmpty, !AppPreferences.apiKeys.isEmpty else { return [] }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q=\(encoded)&maxResults=20&key=\(apiKey)")
            }
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            return response.items
                .map { item in
                    YouTubeChannel(
                        id: item.snippet.channelId ?? item.id.channelId ?? "",
                        title: item.snippet.title,
                        description: item.snippet.description,
                        thumbnailURL: item.snippet.thumbnails.best
                    )
                }
                .filter { !$0.id.isEmpty }
        } catch {
            logger.error("Channel search failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func validateAndAddChannel(id: String) async -> Bool {
        guard !id.isEmpty, !AppPreferences.apiKeys.isEmpty else { return false }

        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,brandingSettings,topicDetails,status,contentDetails,localizations&id=\(id)&key=\(apiKey)")
            }
            let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
            guard response.items.first != nil else {
                logger.info("Channel ID not found: \(id, privacy: .public)")
                return false
            }
            addChannel(id: id)
            return true
        } catch {
            logger.error("Validate channel failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Private fetch

    private func fetchChannelBatch(ids: [String]) async -> [YouTubeChannel] {
        let idsString = ids.joined(separator: ",")
        do {
            let data = try await NetworkService.fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics,brandingSettings,topicDetails,status,contentDetails,localizations&id=\(idsString)&key=\(apiKey)")
            }
            let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
            return response.items.map { item in
                YouTubeChannel(fromItem: item)
            }
        } catch {
            logger.error("Channel batch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - Array helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Response Models

struct ChannelResponse: Decodable {
    let items: [ChannelResponseItem]
}

struct ChannelResponseItem: Decodable {
    let id: String
    let snippet: ChannelResponseSnippet
    let statistics: ChannelResponseStatistics?
    let brandingSettings: ChannelResponseBrandingSettings?
    let contentDetails: ChannelResponseContentDetails?
    let topicDetails: ChannelResponseTopicDetails?
    let status: ChannelResponseStatus?
    let auditDetails: ChannelResponseAuditDetails?
    let contentOwnerDetails: ChannelResponseContentOwnerDetails?
    let localizations: [String: ChannelResponseLocalization]?
}

struct ChannelResponseContentOwnerDetails: Decodable {
    let contentOwner: String?
    let timeLinked: String?
}

struct ChannelResponseContentDetails: Decodable {
    let relatedPlaylists: [String: String]?
}

struct ChannelResponseTopicDetails: Decodable {
    let topicIds: [String]?
    let topicCategories: [String]?
}

struct ChannelResponseStatus: Decodable {
    let privacyStatus: String?
    let isLinked: Bool?
    let longUploadsStatus: String?
    let madeForKids: Bool?
    let selfDeclaredMadeForKids: Bool?
}

struct ChannelResponseAuditDetails: Decodable {
    let overallGoodStanding: Bool?
    let communityGuidelinesGoodStanding: Bool?
    let copyrightStrikesGoodStanding: Bool?
    let contentIdClaimsGoodStanding: Bool?
}

struct ChannelResponseSnippet: Decodable {
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
    let customUrl: String?
    let publishedAt: String?
    let country: String?
    let defaultLanguage: String?
    let localized: ChannelResponseLocalization?
}

struct ChannelResponseLocalization: Decodable {
    let title: String?
    let description: String?
}

struct ChannelResponseStatistics: Decodable {
    let viewCount: String?
    let subscriberCount: String?
    let hiddenSubscriberCount: Bool?
    let videoCount: String?
}

struct ChannelResponseBrandingSettings: Decodable {
    struct Channel: Decodable {
        let title: String?
        let description: String?
        let keywords: String?
        let trackingAnalyticsAccountId: String?
        let unsubscribedTrailer: String?
        let defaultLanguage: String?
        let country: String?
    }
    struct Watch: Decodable {
        let textColor: String?
        let backgroundColor: String?
        let featuredPlaylistId: String?
    }
    struct Image: Decodable {
        let bannerExternalUrl: URL?
    }
    let channel: Channel?
    let watch: Watch?
    let image: Image?
}

struct SearchResponse: Decodable {
    let items: [SearchItem]
}

struct SearchItem: Decodable {
    let id: SearchItemId
    let snippet: SearchSnippet
}

struct SearchItemId: Decodable {
    let channelId: String?
}

struct SearchSnippet: Decodable {
    let channelId: String?
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
}

struct ThumbnailSet: Decodable {
    let `default`: Thumbnail
    let medium: Thumbnail?
    let high: Thumbnail?

    var best: URL {
        high?.url ?? medium?.url ?? `default`.url
    }
}

struct Thumbnail: Decodable {
    let url: URL
}
