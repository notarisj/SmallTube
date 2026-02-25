//
//  SubscriptionManager.swift
//  SmallTube
//
//  Single source of truth for stored subscription IDs.
//  Mutations always write to UserDefaults synchronously since the array is small.
//

import Foundation
import OSLog

final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private let key = "storedSubscriptionIds"
    private let favoritesKey = "favoriteChannelIds"
    private let logger = AppLogger.data

    @Published private(set) var subscriptionIds: [String] = []
    @Published private(set) var favoriteChannelIds: [String] = []

    private init() { load() }

    // MARK: - Persistence

    private func load() {
        subscriptionIds = UserDefaults.standard.stringArray(forKey: key) ?? []
        favoriteChannelIds = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
    }

    private func persist() {
        UserDefaults.standard.set(subscriptionIds, forKey: key)
        UserDefaults.standard.set(favoriteChannelIds, forKey: favoritesKey)
    }

    // MARK: - Public mutations

    func addSubscription(id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !subscriptionIds.contains(trimmed) else { return }
        subscriptionIds.append(trimmed)
        persist()
        logger.info("Added subscription: \(trimmed, privacy: .public)")
    }

    func removeSubscriptionIds(_ ids: [String]) {
        subscriptionIds.removeAll { ids.contains($0) }
        favoriteChannelIds.removeAll { ids.contains($0) }
        persist()
    }

    func removeSubscriptions(at offsets: IndexSet) {
        let idsToRemove = offsets.map { subscriptionIds[$0] }
        subscriptionIds.remove(atOffsets: offsets)
        favoriteChannelIds.removeAll { idsToRemove.contains($0) }
        persist()
    }

    func clearSubscriptions() {
        subscriptionIds = []
        favoriteChannelIds = []
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: favoritesKey)
        logger.info("All subscriptions cleared")
    }

    // MARK: - Favorites

    func toggleFavorite(id: String) {
        if let index = favoriteChannelIds.firstIndex(of: id) {
            favoriteChannelIds.remove(at: index)
        } else {
            favoriteChannelIds.append(id)
        }
        persist()
    }

    func isFavorite(id: String) -> Bool {
        favoriteChannelIds.contains(id)
    }

    // MARK: - CSV Import

    @discardableResult
    func parseCSV(url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            logger.error("Failed to access security-scoped resource: \(url.lastPathComponent, privacy: .public)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines)
            let newIds: [String] = rows.enumerated().compactMap { index, row in
                guard index != 0 else { return nil }   // skip header
                let columns = row.components(separatedBy: ",")
                let id = columns.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return id.count > 5 ? id : nil
            }
            guard !newIds.isEmpty else {
                logger.warning("CSV parsed but no valid channel IDs found")
                return false
            }
            subscriptionIds = newIds
            persist()
            logger.info("CSV import: \(newIds.count) channel IDs imported")
            return true
        } catch {
            logger.error("CSV parse error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
