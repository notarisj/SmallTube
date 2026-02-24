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
    private let logger = AppLogger.data

    @Published private(set) var subscriptionIds: [String] = []

    private init() { load() }

    // MARK: - Persistence

    private func load() {
        subscriptionIds = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    private func persist() {
        UserDefaults.standard.set(subscriptionIds, forKey: key)
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
        persist()
    }

    func removeSubscriptions(at offsets: IndexSet) {
        subscriptionIds.remove(atOffsets: offsets)
        persist()
    }

    func clearSubscriptions() {
        subscriptionIds = []
        UserDefaults.standard.removeObject(forKey: key)
        logger.info("All subscriptions cleared")
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
