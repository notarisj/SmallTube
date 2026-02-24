//
//  CacheService.swift
//  SmallTube
//
//  Generic, filesystem-backed cache that serialises Codable values as JSON
//  into the OS Caches directory and respects a configurable TTL.
//
//  Usage (example):
//      let cache = CacheService<[CachedYouTubeVideo]>(filename: "trending.json", ttl: 300)
//      try? cache.save(videos)
//      if let cached = cache.load(), !cache.isExpired { use(cached) }
//

import Foundation
import OSLog

final class CacheService<T: Codable> {

    // MARK: - Public
    let filename: String
    let ttl: TimeInterval                // seconds

    // MARK: - Private
    private let fileURL: URL
    private let metaURL: URL            // stores the write-timestamp as a Double
    private let logger = AppLogger.cache

    init(filename: String, ttl: TimeInterval) {
        self.filename = filename
        self.ttl = ttl

        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.fileURL = cachesDir.appendingPathComponent(filename)
        self.metaURL = cachesDir.appendingPathComponent(filename + ".meta")
    }

    // MARK: - Save

    func save(_ value: T) {
        guard ttl > 0 else { return }
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
            let timestamp = Data(Date().timeIntervalSince1970.bitPattern.bigEndian.bytes)
            try timestamp.write(to: metaURL, options: .atomic)
            logger.debug("Cache saved: \(self.filename, privacy: .public)")
        } catch {
            logger.error("Cache save failed [\(self.filename, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Load

    /// Returns decoded value if the cache file exists and can be decoded.
    /// Does NOT enforce TTL — call `isExpired` separately.
    func load() -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.debug("Cache miss (no file): \(self.filename, privacy: .public)")
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let value = try JSONDecoder().decode(T.self, from: data)
            logger.debug("Cache hit: \(self.filename, privacy: .public)")
            return value
        } catch {
            logger.error("Cache decode failed [\(self.filename, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Expiry

    var isExpired: Bool {
        guard ttl > 0 else { return true }
        guard FileManager.default.fileExists(atPath: metaURL.path),
              let metaData = try? Data(contentsOf: metaURL),
              metaData.count == 8 else {
            logger.debug("Cache expired (no meta): \(self.filename, privacy: .public)")
            return true
        }
        let bits = UInt64(bigEndian: metaData.withUnsafeBytes { $0.load(as: UInt64.self) })
        let timestamp = TimeInterval(bitPattern: bits)
        let expired = Date().timeIntervalSince1970 - timestamp > ttl
        logger.debug("Cache '\(self.filename, privacy: .public)' expired: \(expired)")
        return expired
    }

    // MARK: - Invalidate

    func invalidate() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: metaURL)
        logger.debug("Cache invalidated: \(self.filename, privacy: .public)")
    }
}

// MARK: - FixedWidthInteger byte helpers

private extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self) { Array($0) }
    }
}
