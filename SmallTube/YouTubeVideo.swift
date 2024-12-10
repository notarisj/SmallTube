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

    enum FlatKeys: String, CodingKey {
        case id, title, description, thumbnailURL
    }

    enum APIKeys: String, CodingKey {
        case id, snippet
    }

    enum IDKeys: String, CodingKey {
        case videoId
    }

    enum SnippetKeys: String, CodingKey {
        case title, description, thumbnails
    }

    enum ThumbnailKeys: String, CodingKey {
        case defaultThumbnail = "default"
        case medium, high, standard, maxres
    }

    enum DefaultThumbnailKeys: String, CodingKey {
        case url
    }

    init(from decoder: Decoder) throws {
        // Try decoding for Search Response
        let container = try decoder.container(keyedBy: APIKeys.self)

        // Handle `id`
        if let directId = try? container.decode(String.self, forKey: .id) {
            self.id = directId
        } else {
            let idContainer = try container.nestedContainer(keyedBy: IDKeys.self, forKey: .id)
            self.id = try idContainer.decode(String.self, forKey: .videoId)
        }

        // Handle `snippet`
        let snippetContainer = try container.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
        let rawTitle = try snippetContainer.decode(String.self, forKey: .title)
        self.title = rawTitle.stringByDecodingHTMLEntities
        self.description = try snippetContainer.decodeIfPresent(String.self, forKey: .description) ?? ""

        // Handle `thumbnails`
        let thumbnailContainer = try snippetContainer.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        if let defaultThumbnailContainer = try? thumbnailContainer.nestedContainer(keyedBy: DefaultThumbnailKeys.self, forKey: .defaultThumbnail) {
            self.thumbnailURL = try defaultThumbnailContainer.decode(URL.self, forKey: .url)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "No valid thumbnail found"))
        }
    }


    func encode(to encoder: Encoder) throws {
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
