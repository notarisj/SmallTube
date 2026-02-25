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
    let channelTitle: String
    let channelId: String
    var channelIconURL: URL?
}

extension CachedYouTubeVideo {
    // Convert from the API model to the cached model
    init(from apiVideo: YouTubeAPIVideo) {
        self.id = apiVideo.id
        self.title = apiVideo.title
        self.description = apiVideo.description
        self.thumbnailURL = apiVideo.thumbnailURL
        self.publishedAt = apiVideo.publishedAt
        self.channelTitle = apiVideo.channelTitle
        self.channelId = apiVideo.channelId
        self.channelIconURL = nil
    }
}
