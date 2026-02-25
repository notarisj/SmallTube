//
//  AppPreferences.swift
//  SmallTube
//
//  Single source of truth for all persisted user preferences.
//  Use the typed constants throughout the app instead of raw string keys.
//

import Foundation

/// Namespace for all UserDefaults-backed user preferences.
/// Centralises key strings and provides typed accessors for non-`@AppStorage` contexts
/// (e.g. `@MainActor` ViewModels where property wrappers are not available).
enum AppPreferences {

    // MARK: - Keys (never used directly outside this file)

    private enum Key {
        static let apiKey       = "apiKey"
        static let currentApiKeyIndex = "currentApiKeyIndex"
        static let resultsCount = "resultsCount"
        static let homeFeedChannelCount = "homeFeedChannelCount"
        static let countryCode  = "countryCode"
        static let lastSearches = "lastSearches"
        static let autoplay     = "autoplay"
        static let thumbnailQuality = "thumbnailQuality"
        static let cacheTimeout = "cacheTimeout"
        static let totalDataBytesUsed = "totalDataBytesUsed"
        static let totalApiQuotaUsed = "totalApiQuotaUsed"
    }

    // MARK: - Typed accessors

    static var autoplay: Bool {
        get { UserDefaults.standard.bool(forKey: Key.autoplay) }
        set { UserDefaults.standard.set(newValue, forKey: Key.autoplay) }
    }

    static var apiKeys: [String] {
        apiKey.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static var currentApiKeyIndex: Int {
        get { UserDefaults.standard.integer(forKey: Key.currentApiKeyIndex) }
        set { UserDefaults.standard.set(newValue, forKey: Key.currentApiKeyIndex) }
    }

    static var apiKey: String {
        get {
            if let key = KeychainManager.get(key: Key.apiKey) {
                return key
            }
            if let legacy = UserDefaults.standard.string(forKey: Key.apiKey), !legacy.isEmpty {
                KeychainManager.save(key: Key.apiKey, value: legacy)
                UserDefaults.standard.removeObject(forKey: Key.apiKey)
                return legacy
            }
            return ""
        }
        set {
            KeychainManager.save(key: Key.apiKey, value: newValue)
        }
    }

    /// Number of results to fetch per request. Defaults to 10.
    static var resultsCount: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: Key.resultsCount)
            return value > 0 ? value : 10
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.resultsCount) }
    }

    /// Number of channels to randomly pick for the home feed. Defaults to 15.
    static var homeFeedChannelCount: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: Key.homeFeedChannelCount)
            return value > 0 ? value : 15
        }
        set { UserDefaults.standard.set(newValue, forKey: Key.homeFeedChannelCount) }
    }

    static var countryCode: String {
        get { UserDefaults.standard.string(forKey: Key.countryCode) ?? "US" }
        set { UserDefaults.standard.set(newValue, forKey: Key.countryCode) }
    }

    static var lastSearches: [String] {
        get { UserDefaults.standard.stringArray(forKey: Key.lastSearches) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Key.lastSearches) }
    }

    static var thumbnailQuality: ThumbnailQuality {
        get {
            let value = UserDefaults.standard.string(forKey: Key.thumbnailQuality) ?? ThumbnailQuality.high.rawValue
            return ThumbnailQuality(rawValue: value) ?? .high
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.thumbnailQuality) }
    }

    static var cacheTimeout: CacheTimeout {
        get {
            if UserDefaults.standard.object(forKey: Key.cacheTimeout) == nil {
                return .fiveMinutes
            }
            let value = UserDefaults.standard.integer(forKey: Key.cacheTimeout)
            return CacheTimeout(rawValue: value) ?? .fiveMinutes
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Key.cacheTimeout) }
    }

    static var totalDataBytesUsed: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: Key.totalDataBytesUsed)) }
        set { UserDefaults.standard.set(Int(newValue), forKey: Key.totalDataBytesUsed) }
    }

    static var totalApiQuotaUsed: Int {
        get { UserDefaults.standard.integer(forKey: Key.totalApiQuotaUsed) }
        set { UserDefaults.standard.set(newValue, forKey: Key.totalApiQuotaUsed) }
    }
}

enum ThumbnailQuality: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum CacheTimeout: Int, CaseIterable, Identifiable {
    case disabled = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .disabled: return "Disabled"
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .tenMinutes: return "10 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .twoHours: return "2 Hours"
        }
    }
}
