//
//  YouTubeChannel.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import Foundation

struct YouTubeChannel: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    let thumbnailURL: URL
    
    // MARK: - Snippet Details
    var customUrl: String?
    var publishedAt: Date?
    var country: String?
    var defaultLanguage: String?
    var localizedTitle: String?
    var localizedDescription: String?

    // MARK: - Statistics
    var viewCount: Int?
    var subscriberCount: Int?
    var hiddenSubscriberCount: Bool?
    var videoCount: Int?

    // MARK: - Branding Settings (Channel & Watch)
    var bannerURL: URL?
    var keywords: String?
    var trackingAnalyticsAccountId: String?
    var unsubscribedTrailer: String?
    var brandingDefaultLanguage: String?
    var brandingCountry: String?
    
    var watchTextColor: String?
    var watchBackgroundColor: String?
    var watchFeaturedPlaylistId: String?
    
    // MARK: - Content Details
    var relatedPlaylists: [String: String]?
    
    // MARK: - Topic Details
    var topicIds: [String]?
    var topicCategories: [String]?
    
    // MARK: - Status
    var privacyStatus: String?
    var isLinked: Bool?
    var longUploadsStatus: String?
    var madeForKids: Bool?
    var selfDeclaredMadeForKids: Bool?
    
    // MARK: - Audit Details
    var overallGoodStanding: Bool?
    var communityGuidelinesGoodStanding: Bool?
    var copyrightStrikesGoodStanding: Bool?
    var contentIdClaimsGoodStanding: Bool?
    
    // MARK: - Content Owner Details
    var contentOwner: String?
    var timeLinked: Date?
    
    // MARK: - Localizations
    // Instead of a full dictionary, we might only expose a check or store it if needed.
    var hasLocalizations: Bool?
    
    // Add default initializer for compatibility
    init(id: String, title: String, description: String, thumbnailURL: URL, customUrl: String? = nil, publishedAt: Date? = nil, country: String? = nil, viewCount: Int? = nil, subscriberCount: Int? = nil, hiddenSubscriberCount: Bool? = nil, videoCount: Int? = nil, bannerURL: URL? = nil, keywords: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        
        self.customUrl = customUrl
        self.publishedAt = publishedAt
        self.country = country
        
        self.viewCount = viewCount
        self.subscriberCount = subscriberCount
        self.hiddenSubscriberCount = hiddenSubscriberCount
        self.videoCount = videoCount
        
        self.bannerURL = bannerURL
        self.keywords = keywords
    }
}

// MARK: - Network Response Mapping
extension YouTubeChannel {
    private static let isoFormatter = ISO8601DateFormatter()
    
    init(fromItem item: ChannelResponseItem) {
        var viewCount: Int?
        var subCount: Int?
        var videoCount: Int?
        if let stats = item.statistics {
            viewCount = Int(stats.viewCount ?? "")
            subCount = Int(stats.subscriberCount ?? "")
            videoCount = Int(stats.videoCount ?? "")
        }
        
        let pubDate = Self.isoFormatter.date(from: item.snippet.publishedAt ?? "")
        
        self.init(
            id: item.id,
            title: item.snippet.title,
            description: item.snippet.description,
            thumbnailURL: item.snippet.thumbnails.best,
            customUrl: item.snippet.customUrl,
            publishedAt: pubDate,
            country: item.snippet.country,
            viewCount: viewCount,
            subscriberCount: subCount,
            hiddenSubscriberCount: item.statistics?.hiddenSubscriberCount,
            videoCount: videoCount,
            bannerURL: item.brandingSettings?.image?.bannerExternalUrl,
            keywords: item.brandingSettings?.channel?.keywords
        )
        
        self.defaultLanguage = item.snippet.defaultLanguage
        self.localizedTitle = item.snippet.localized?.title
        self.localizedDescription = item.snippet.localized?.description
        
        self.trackingAnalyticsAccountId = item.brandingSettings?.channel?.trackingAnalyticsAccountId
        self.unsubscribedTrailer = item.brandingSettings?.channel?.unsubscribedTrailer
        self.brandingDefaultLanguage = item.brandingSettings?.channel?.defaultLanguage
        self.brandingCountry = item.brandingSettings?.channel?.country
        
        self.watchTextColor = item.brandingSettings?.watch?.textColor
        self.watchBackgroundColor = item.brandingSettings?.watch?.backgroundColor
        self.watchFeaturedPlaylistId = item.brandingSettings?.watch?.featuredPlaylistId
        
        self.relatedPlaylists = item.contentDetails?.relatedPlaylists
        self.topicIds = item.topicDetails?.topicIds
        self.topicCategories = item.topicDetails?.topicCategories
        self.privacyStatus = item.status?.privacyStatus
        self.isLinked = item.status?.isLinked
        self.longUploadsStatus = item.status?.longUploadsStatus
        self.madeForKids = item.status?.madeForKids
        self.selfDeclaredMadeForKids = item.status?.selfDeclaredMadeForKids
        self.overallGoodStanding = item.auditDetails?.overallGoodStanding
        self.communityGuidelinesGoodStanding = item.auditDetails?.communityGuidelinesGoodStanding
        self.copyrightStrikesGoodStanding = item.auditDetails?.copyrightStrikesGoodStanding
        self.contentIdClaimsGoodStanding = item.auditDetails?.contentIdClaimsGoodStanding

        self.contentOwner = item.contentOwnerDetails?.contentOwner
        if let tl = item.contentOwnerDetails?.timeLinked {
            self.timeLinked = Self.isoFormatter.date(from: tl)
        }
        
        self.hasLocalizations = item.localizations != nil && !(item.localizations!.isEmpty)
    }
}
