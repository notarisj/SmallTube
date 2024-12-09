//
//  YouTubeVideo.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import Foundation

struct YouTubeVideo: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL

    // Flat keys for cached data
    enum FlatKeys: String, CodingKey {
        case id, title, description, thumbnailURL
    }

    // API-based keys
    enum APIKeys: String, CodingKey {
        case id
        case snippet
    }

    enum IDKeys: String, CodingKey {
        case videoId
    }

    enum SnippetKeys: String, CodingKey {
        case title
        case description
        case thumbnails
    }

    enum ThumbnailKeys: String, CodingKey {
        case defaultThumbnail = "default"
    }

    enum DefaultThumbnailKeys: String, CodingKey {
        case url
    }

    init(from decoder: Decoder) throws {
        // First, try decoding using the flat structure (cached data)
        if let flatContainer = try? decoder.container(keyedBy: FlatKeys.self) {
            self.id = try flatContainer.decode(String.self, forKey: .id)
            self.title = try flatContainer.decode(String.self, forKey: .title)
            self.description = try flatContainer.decode(String.self, forKey: .description)
            self.thumbnailURL = try flatContainer.decode(URL.self, forKey: .thumbnailURL)
            return
        }

        // If flat decoding fails, decode using the API structure
        let container = try decoder.container(keyedBy: APIKeys.self)

        // Try decoding id from search-style response first (id.videoId)
        if let idContainer = try? container.nestedContainer(keyedBy: IDKeys.self, forKey: .id),
           let videoId = try? idContainer.decode(String.self, forKey: .videoId) {
            self.id = videoId
        } else {
            // If that fails, try decoding directly as a string (videos endpoint)
            self.id = try container.decode(String.self, forKey: .id)
        }

        let snippetContainer = try container.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
        let rawTitle = try snippetContainer.decode(String.self, forKey: .title)
        self.title = rawTitle.stringByDecodingHTMLEntities
        self.description = try snippetContainer.decode(String.self, forKey: .description)

        let thumbnailContainer = try snippetContainer.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let defaultThumbnailContainer = try thumbnailContainer.nestedContainer(keyedBy: DefaultThumbnailKeys.self, forKey: .defaultThumbnail)
        self.thumbnailURL = try defaultThumbnailContainer.decode(URL.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        // Encode into the flat structure for caching
        var container = encoder.container(keyedBy: FlatKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(thumbnailURL, forKey: .thumbnailURL)
    }
}

extension String {
    var stringByDecodingHTMLEntities: String {
        guard let data = self.data(using: .utf8) else { return self }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else { return self }
        return attributedString.string
    }
}
