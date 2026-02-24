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
                AppPreferences.totalApiQuotaUsed += quotaCost

                return data
            } catch let error as NetworkError {
                if case .httpError(let code) = error, code == 403 {
                    AppLogger.network.warning("API key quota exceeded: \(key.prefix(8))... Rotating.")
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
