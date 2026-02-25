//
//  CachedYouTubeVideo.swift
//  SmallTube
//
//  Created by John Notaris on 12/10/24.
//

import Foundation

struct CachedYouTubeVideo: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL
    let publishedAt: Date
    let durationSeconds: Int?
    let channelTitle: String
    let channelId: String
    var channelIconURL: URL?

    var formattedDuration: String? {
        guard let seconds = durationSeconds, seconds > 0 else { return nil }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}

extension CachedYouTubeVideo {
    // Convert from the API model to the cached model
    init(from apiVideo: YouTubeAPIVideo) {
        self.id = apiVideo.id
        self.title = apiVideo.title
        self.description = apiVideo.description
        self.thumbnailURL = apiVideo.thumbnailURL
        self.publishedAt = apiVideo.publishedAt
        self.durationSeconds = apiVideo.durationSeconds
        self.channelTitle = apiVideo.channelTitle
        self.channelId = apiVideo.channelId
        self.channelIconURL = nil
    }
}
