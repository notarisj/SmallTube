//
//  YouTubeAPIVideo.swift
//  SmallTube
//

import Foundation

struct YouTubeAPIVideo: Decodable {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL
    let publishedAt: Date
    let durationSeconds: Int?

    enum APIKeys: String, CodingKey {
        case id, snippet, contentDetails
    }
    enum IDKeys: String, CodingKey { case videoId }
    enum SnippetKeys: String, CodingKey { case title, description, thumbnails, publishedAt }
    enum ContentDetailsKeys: String, CodingKey { case duration }
    enum ThumbnailKeys: String, CodingKey { case defaultThumbnail = "default" }
    enum DefaultThumbnailKeys: String, CodingKey { case url }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: APIKeys.self)

        // `id` may be a plain String (Video list) or an object containing `videoId` (Search list)
        if let directId = try? container.decode(String.self, forKey: .id) {
            self.id = directId
        } else {
            let idContainer = try container.nestedContainer(keyedBy: IDKeys.self, forKey: .id)
            self.id = try idContainer.decode(String.self, forKey: .videoId)
        }

        let snippetContainer = try container.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
        self.title = (try snippetContainer.decode(String.self, forKey: .title)).decodingHTMLEntities()
        self.description = try snippetContainer.decodeIfPresent(String.self, forKey: .description) ?? ""

        let publishedAtString = try snippetContainer.decode(String.self, forKey: .publishedAt)
        self.publishedAt = ISO8601DateFormatter().date(from: publishedAtString) ?? Date()

        let thumbnailContainer = try snippetContainer.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        let defaultContainer   = try thumbnailContainer.nestedContainer(keyedBy: DefaultThumbnailKeys.self, forKey: .defaultThumbnail)
        self.thumbnailURL = try defaultContainer.decode(URL.self, forKey: .url)

        if let cdContainer = try? container.nestedContainer(keyedBy: ContentDetailsKeys.self, forKey: .contentDetails),
           let durationString = try? cdContainer.decode(String.self, forKey: .duration) {
            self.durationSeconds = YouTubeAPIVideo.parseDuration(durationString)
        } else {
            self.durationSeconds = nil
        }
    }

    // MARK: - ISO 8601 Duration Parser  e.g. "PT1H30M15S" → seconds

    private static func parseDuration(_ string: String) -> Int {
        guard string.hasPrefix("PT") else { return 0 }
        var s = string.dropFirst(2)   // remove "PT"
        var hours = 0, minutes = 0, seconds = 0

        if let hIdx = s.firstIndex(of: "H") {
            hours = Int(s[..<hIdx]) ?? 0
            s = s[s.index(after: hIdx)...]
        }
        if let mIdx = s.firstIndex(of: "M") {
            minutes = Int(s[..<mIdx]) ?? 0
            s = s[s.index(after: mIdx)...]
        }
        if let sIdx = s.firstIndex(of: "S") {
            seconds = Int(s[..<sIdx]) ?? 0
        }
        return hours * 3600 + minutes * 60 + seconds
    }
}

// MARK: - Lightweight HTML entity decoder
// Replaces the NSAttributedString-based approach which allocates a full HTML parser
// for every video title. YouTube only emits a small, well-known set of entities.

extension String {
    /// Decodes the five standard HTML entities plus the numeric apostrophe YouTube uses.
    func decodingHTMLEntities() -> String {
        let table: [(String, String)] = [
            ("&amp;",  "&"),
            ("&lt;",   "<"),
            ("&gt;",   ">"),
            ("&quot;", "\""),
            ("&#39;",  "'"),
            ("&apos;", "'"),
        ]
        var result = self
        for (entity, char) in table {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}

struct YouTubeResponse: Decodable {
    let items: [YouTubeAPIVideo]
}

struct VideoListResponse: Decodable {
    let items: [YouTubeAPIVideo]
}
