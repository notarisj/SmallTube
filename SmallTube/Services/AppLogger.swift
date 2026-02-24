//
//  AppLogger.swift
//  SmallTube
//
//  Centralised os.Logger instances.
//  Filter by subsystem in Console.app during development.
//

import OSLog

enum AppLogger {
    /// Network requests, responses, and decoding errors.
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Network")
    /// Disk / file-system cache reads and writes.
    static let cache   = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Cache")
    /// User-facing data operations (subscriptions, search history).
    static let data    = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Data")
    /// UI-level events (settings, file import).
    static let ui      = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UI")
}
