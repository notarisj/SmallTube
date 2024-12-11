//
//  YouTubeAPIVideo.swift
//  SmallTube
//
//  Created by John Notaris on 12/10/24.
//

import Foundation

struct YouTubeAPIVideo: Decodable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL
    let publishedAt: Date
    
    enum APIKeys: String, CodingKey {
        case id, snippet
    }
    
    enum IDKeys: String, CodingKey {
        case videoId
    }
    
    enum SnippetKeys: String, CodingKey {
        case title, description, thumbnails, publishedAt
    }
    
    enum ThumbnailKeys: String, CodingKey {
        case defaultThumbnail = "default"
    }
    
    enum DefaultThumbnailKeys: String, CodingKey {
        case url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: APIKeys.self)
        
        // Decode `id`
        if let directId = try? container.decode(String.self, forKey: .id) {
            self.id = directId
        } else {
            let idContainer = try container.nestedContainer(keyedBy: IDKeys.self, forKey: .id)
            self.id = try idContainer.decode(String.self, forKey: .videoId)
        }
        
        // Decode `snippet`
        let snippetContainer = try container.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
        let rawTitle = try snippetContainer.decode(String.self, forKey: .title)
        self.title = rawTitle.stringByDecodingHTMLEntities
        self.description = try snippetContainer.decodeIfPresent(String.self, forKey: .description) ?? ""
        
        // Decode `thumbnails`
        let publishedAtString = try snippetContainer.decode(String.self, forKey: .publishedAt)
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: publishedAtString) {
            self.publishedAt = date
        } else {
            // If parsing fails, use current date as fallback.
            self.publishedAt = Date()
        }
        
        // Decode thumbnails
        let thumbnailContainer = try snippetContainer.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let defaultThumbnailContainer = try thumbnailContainer.nestedContainer(keyedBy: DefaultThumbnailKeys.self, forKey: .defaultThumbnail)
        self.thumbnailURL = try defaultThumbnailContainer.decode(URL.self, forKey: .url)
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

struct YouTubeResponse: Decodable {
    let items: [YouTubeAPIVideo]
}
