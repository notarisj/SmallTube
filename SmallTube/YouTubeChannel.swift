//
//  YouTubeChannel.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import Foundation

struct YouTubeChannel: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL
}
