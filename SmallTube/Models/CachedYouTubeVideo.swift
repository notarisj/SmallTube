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
    let viewCount: Int?
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
    
    var formattedViewCount: String? {
        guard let views = viewCount else { return nil }
        
        switch views {
        case ..<1_000:
            return "\(views)"
        case 1_000..<1_000_000:
            return String(format: "%.1fK", Double(views) / 1_000.0).replacingOccurrences(of: ".0K", with: "K")
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1fM", Double(views) / 1_000_000.0).replacingOccurrences(of: ".0M", with: "M")
        default:
            return String(format: "%.1fB", Double(views) / 1_000_000_000.0).replacingOccurrences(of: ".0B", with: "B")
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
        self.viewCount = apiVideo.viewCount
        self.channelTitle = apiVideo.channelTitle
        self.channelId = apiVideo.channelId
        self.channelIconURL = nil
    }
}
