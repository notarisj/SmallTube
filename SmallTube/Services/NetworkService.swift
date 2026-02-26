//
//  NetworkService.swift
//  SmallTube
//
//  Shared URLSession with sane timeouts and a lightweight async fetch helper.
//

import Foundation
import OSLog

enum NetworkError: Error {
    case invalidURL
    case httpError(statusCode: Int)
    case noData
}

struct NetworkService {

    // MARK: - Shared session

    /// 15 s request / 60 s resource timeouts — replaces the implicit infinite-wait of `.shared`.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - Fetch

    private static let thumbnailsCache = CacheService<[String: URL]>(filename: "channelThumbnails.json", ttl: 86400 * 30) // 30 days cache

    /// Fetches channel thumbnails in bulk. Returns a dictionary mapping channel ID to thumbnail URL.
    /// Only fetches thumbnails that are not already cached.
    static func fetchChannelThumbnails(for channelIds: [String]) async throws -> [String: URL] {
        guard !channelIds.isEmpty else { return [:] }
        let uniqueIds = Array(Set(channelIds))
        
        var cachedMap = thumbnailsCache.load() ?? [:]
        var result: [String: URL] = [:]
        var idsToFetch: [String] = []

        for id in uniqueIds {
            if let cachedURL = cachedMap[id] {
                result[id] = cachedURL
            } else {
                idsToFetch.append(id)
            }
        }

        if idsToFetch.isEmpty {
            AppLogger.network.debug("Channel thumbnails: all \(result.count) loaded from cache")
            return result
        }

        AppLogger.network.debug("Channel thumbnails: \(result.count) loaded from cache, fetching \(idsToFetch.count) from API")

        // Chunk into max 50 ids per request (YouTube API limit)
        let chunkedIds = stride(from: 0, to: idsToFetch.count, by: 50).map {
            Array(idsToFetch[$0..<min($0 + 50, idsToFetch.count)])
        }
        for chunk in chunkedIds {
            let idsString = chunk.joined(separator: ",")
            let data = try await fetchYouTube { apiKey in
                URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet&id=\(idsString)&key=\(apiKey)")
            }
            let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
            for item in response.items {
                let bestURL = item.snippet.thumbnails.best
                result[item.id] = bestURL
                cachedMap[item.id] = bestURL
            }
        }
        
        thumbnailsCache.save(cachedMap)
        return result
    }

    /// Performs a GET request and returns raw `Data`. Throws `NetworkError` on HTTP failures.
    static func fetch(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        let bytesReceived = Int64(data.count)
        AppPreferences.totalDataBytesUsed += bytesReceived

        guard let http = response as? HTTPURLResponse else { throw NetworkError.noData }
        guard (200...299).contains(http.statusCode) else {
            throw NetworkError.httpError(statusCode: http.statusCode)
        }
        return data
    }

    /// Fetches data from YouTube API. Automatically rotates through `AppPreferences.apiKeys` on 403 errors.
    static func fetchYouTube(urlBuilder: (String) -> URL?) async throws -> Data {
        let keys = AppPreferences.apiKeys
        guard !keys.isEmpty else {
            throw NetworkError.noData
        }

        var currentIndex = AppPreferences.currentApiKeyIndex
        if currentIndex >= keys.count { currentIndex = 0 }

        var lastError: Error?

        for i in 0..<keys.count {
            let index = (currentIndex + i) % keys.count
            let key = keys[index]
            
            let used = AppPreferences.apiQuotaUsage[key] ?? 0
            let limit = AppPreferences.apiQuotaLimits[key] ?? 10000
            
            // If we have other keys, skip this one if it's over the limit.
            // If all are over, this function will fall through to throwing lastError.
            if used >= limit {
                continue
            }

            guard let url = urlBuilder(key) else { continue }

            do {
                let data = try await fetch(url: url)
                if index != AppPreferences.currentApiKeyIndex {
                    AppPreferences.currentApiKeyIndex = index
                }

                // Estimate quota usage
                // Simple assumption: fetch is cost 1 by default, but search is 100.
                let urlString = url.absoluteString
                var quotaCost = 1
                if urlString.contains("/search") {
                    quotaCost = 100
                }
                AppPreferences.incrementApiQuotaUsage(for: key, cost: quotaCost)

                return data
            } catch let error as NetworkError {
                if case .httpError(let code) = error, code == 403 {
                    AppLogger.network.warning("API key quota exceeded: \(key.prefix(8))... Rotating.")
                    AppPreferences.setApiQuotaExceeded(for: key)
                    lastError = error
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }

        if let lastError { throw lastError }
        throw NetworkError.noData
    }
}
