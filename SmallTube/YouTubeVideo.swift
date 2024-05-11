//
//  YouTubeVideo.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import Foundation

struct YouTubeVideo: Identifiable, Decodable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL
    
    enum CodingKeys: String, CodingKey {
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
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idContainer = try container.nestedContainer(keyedBy: IDKeys.self, forKey: .id)
        id = try idContainer.decode(String.self, forKey: .videoId)
        
        let snippetContainer = try container.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
        let rawTitle = try snippetContainer.decode(String.self, forKey: .title)
        title = rawTitle.stringByDecodingHTMLEntities
        description = try snippetContainer.decode(String.self, forKey: .description)
        
        let thumbnailContainer = try snippetContainer.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let defaultThumbnailContainer = try thumbnailContainer.nestedContainer(keyedBy: DefaultThumbnailKeys.self, forKey: .defaultThumbnail)
        thumbnailURL = try defaultThumbnailContainer.decode(URL.self, forKey: .url)
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
