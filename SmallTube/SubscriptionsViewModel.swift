//
//  SubscriptionsViewModel.swift
//  SmallTube
//

import Foundation
import SwiftUI
import OSLog

class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [YouTubeChannel] = []
    @Published var currentAlert: AlertType?

    @AppStorage("subscriptionsSortOption") var sortOption: SortOption = .az

    enum SortOption: String, CaseIterable, Identifiable {
        case az = "A-Z"
        case za = "Z-A"
        var id: String { rawValue }
    }

    private let logger = AppLogger.data

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }

    // MARK: - Load

    func loadImportedSubscriptions(completion: @escaping ([YouTubeChannel]) -> Void) {
        guard !apiKey.isEmpty else {
            logger.warning("loadImportedSubscriptions aborted: API key missing")
            DispatchQueue.main.async {
                self.currentAlert = .apiError
                completion([])
            }
            return
        }

        let channelIds = SubscriptionManager.shared.subscriptionIds
        guard !channelIds.isEmpty else {
            logger.info("No stored subscription IDs found")
            DispatchQueue.main.async {
                self.subscriptions = []
                completion([])
            }
            return
        }

        let batches = channelIds.chunked(into: 50)
        var allChannels: [YouTubeChannel] = []
        let accumQueue = DispatchQueue(label: "com.smalltube.subscriptions.accum")
        let group = DispatchGroup()

        for batch in batches {
            group.enter()
            let idsString = batch.joined(separator: ",")
            let urlString = "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=\(idsString)&key=\(apiKey)"
            guard let url = URL(string: urlString) else {
                logger.error("Invalid URL for channel batch")
                group.leave()
                continue
            }

            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                defer { group.leave() }
                guard let self else { return }
                if let error {
                    self.logger.error("Channel batch network error: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let data else { return }
                do {
                    let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                    let channels = response.items.map {
                        YouTubeChannel(id: $0.id, title: $0.snippet.title,
                                       description: $0.snippet.description,
                                       thumbnailURL: $0.snippet.thumbnails.default.url)
                    }
                    accumQueue.sync { allChannels.append(contentsOf: channels) }
                } catch {
                    self.logger.error("Channel batch decode error: \(error.localizedDescription, privacy: .public)")
                }
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.sortChannels(allChannels)
            completion(self.subscriptions)
        }
    }

    // MARK: - Sorting

    private func sortChannels(_ channels: [YouTubeChannel]) {
        switch sortOption {
        case .az:
            subscriptions = channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .za:
            subscriptions = channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
    }

    func updateSortOption(_ option: SortOption) {
        sortOption = option
        sortChannels(subscriptions)
    }

    // MARK: - Mutations

    func deleteChannel(at offsets: IndexSet) {
        let idsToRemove = offsets.map { subscriptions[$0].id }
        SubscriptionManager.shared.removeSubscriptionIds(idsToRemove)
        subscriptions.remove(atOffsets: offsets)
        logger.info("Removed \(idsToRemove.count) subscription(s)")
    }

    func addChannel(id: String) {
        SubscriptionManager.shared.addSubscription(id: id)
        loadImportedSubscriptions { _ in }
    }

    // MARK: - Search

    func searchYouTubeChannels(query: String, completion: @escaping ([YouTubeChannel]) -> Void) {
        guard !query.isEmpty, !apiKey.isEmpty else {
            completion([])
            return
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion([])
            return
        }

        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&q=\(encoded)&maxResults=20&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.logger.error("Channel search error: \(error.localizedDescription, privacy: .public)")
            }
            guard let data else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            do {
                let response = try JSONDecoder().decode(SearchResponse.self, from: data)
                let channels = response.items
                    .map { item in
                        YouTubeChannel(id: item.snippet.channelId ?? item.id.channelId ?? "",
                                       title: item.snippet.title,
                                       description: item.snippet.description,
                                       thumbnailURL: item.snippet.thumbnails.default.url)
                    }
                    .filter { !$0.id.isEmpty }
                DispatchQueue.main.async { completion(channels) }
            } catch {
                self.logger.error("Channel search decode error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }

    func validateAndAddChannel(id: String, completion: @escaping (Bool) -> Void) {
        guard !id.isEmpty, !apiKey.isEmpty else { completion(false); return }

        let urlString = "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=\(id)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { completion(false); return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.logger.error("Validate channel error: \(error.localizedDescription, privacy: .public)")
            }
            guard let data else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            do {
                let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                if response.items.first != nil {
                    DispatchQueue.main.async {
                        self.addChannel(id: id)
                        completion(true)
                    }
                } else {
                    self.logger.info("Channel ID not found: \(id, privacy: .public)")
                    DispatchQueue.main.async { completion(false) }
                }
            } catch {
                self.logger.error("Validate channel decode error: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion(false) }
            }
        }.resume()
    }
}

// MARK: - Array helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
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
}

struct ChannelResponseSnippet: Decodable {
    let title: String
    let description: String
    let thumbnails: ThumbnailSet
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
}

struct Thumbnail: Decodable {
    let url: URL
}

// MARK: - SubscriptionManager

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private let storedSubscriptionsKey = "storedSubscriptionIds"
    private let logger = AppLogger.data

    @Published var subscriptionIds: [String] = []

    init() { loadSubscriptions() }

    func parseCSV(url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("Failed to access security-scoped resource: \(url.lastPathComponent, privacy: .public)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines)
            var newIds: [String] = []

            for (index, row) in rows.enumerated() {
                guard index != 0 else { continue } // skip header
                let columns = row.components(separatedBy: ",")
                if let channelId = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                   channelId.count > 5 {
                    newIds.append(channelId)
                }
            }

            guard !newIds.isEmpty else {
                logger.warning("CSV parsed but no valid channel IDs found")
                return false
            }

            saveSubscriptions(newIds)
            logger.info("CSV import: \(newIds.count) channel IDs imported")
            return true
        } catch {
            logger.error("CSV parse error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func saveSubscriptions(_ ids: [String]) {
        subscriptionIds = ids
        UserDefaults.standard.set(ids, forKey: storedSubscriptionsKey)
    }

    private func loadSubscriptions() {
        subscriptionIds = UserDefaults.standard.stringArray(forKey: storedSubscriptionsKey) ?? []
    }

    func clearSubscriptions() {
        subscriptionIds = []
        UserDefaults.standard.removeObject(forKey: storedSubscriptionsKey)
        logger.info("All subscriptions cleared")
    }

    func addSubscription(id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !subscriptionIds.contains(trimmed) else { return }
        subscriptionIds.append(trimmed)
        UserDefaults.standard.set(subscriptionIds, forKey: storedSubscriptionsKey)
        logger.info("Added subscription: \(trimmed, privacy: .public)")
    }

    /// Remove specific IDs (used by SubscriptionsViewModel.deleteChannel).
    func removeSubscriptionIds(_ ids: [String]) {
        subscriptionIds.removeAll { ids.contains($0) }
        UserDefaults.standard.set(subscriptionIds, forKey: storedSubscriptionsKey)
    }

    func removeSubscriptions(at offsets: IndexSet) {
        subscriptionIds.remove(atOffsets: offsets)
        UserDefaults.standard.set(subscriptionIds, forKey: storedSubscriptionsKey)
    }
}
