//
//  ChannelDetailView.swift
//  SmallTube
//

import SwiftUI

struct ChannelDetailView: View {
    let channel: YouTubeChannel

    var body: some View {
        List {
            Section {
                if !channel.description.isEmpty {
                    Text(channel.description)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("No description available.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("About")
            }
            
            Section {
                DetailRow(icon: "person.2.fill", title: "Subscribers", value: formattedSubscriberCount(channel.subscriberCount, isHidden: channel.hiddenSubscriberCount))
                DetailRow(icon: "play.tv.fill", title: "Videos", value: formattedCount(channel.videoCount))
                DetailRow(icon: "eye.fill", title: "Total Views", value: formattedCount(channel.viewCount))
            } header: {
                Text("Statistics")
            }
            
            Section {
                if let customUrl = channel.customUrl {
                    DetailRow(icon: "at", title: "Handle", value: customUrl)
                }
                if let country = channel.country {
                    DetailRow(icon: "globe", title: "Country", value: country)
                }
                if let joined = channel.publishedAt {
                    DetailRow(icon: "calendar", title: "Joined", value: joined.formatted(date: .long, time: .omitted))
                }
                if let defaultLang = channel.defaultLanguage {
                    DetailRow(icon: "character.bubble", title: "Language", value: defaultLang)
                }
                if channel.hasLocalizations == true {
                    DetailRow(icon: "globe.americas", title: "Translated", value: "Available")
                }
            } header: {
                Text("Details")
            }
            
            if let keywords = channel.keywords, !keywords.isEmpty {
                Section {
                    Text(keywords)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Keywords")
                }
            }
            
            if let categories = channel.topicCategories, !categories.isEmpty {
                Section {
                    ForEach(categories, id: \.self) { categoryUrl in
                        if let name = categoryUrl.components(separatedBy: "/").last {
                            Text(name.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Topics")
                }
            }
            
            // Contains newly added branding info and links
            Section {
                if let bCountry = channel.brandingCountry {
                    DetailRow(icon: "map", title: "Branding Country", value: bCountry)
                }
                if let bDefaultLang = channel.brandingDefaultLanguage {
                    DetailRow(icon: "character", title: "Branding Language", value: bDefaultLang)
                }
                if let trackingId = channel.trackingAnalyticsAccountId {
                    DetailRow(icon: "chart.line.uptrend.xyaxis", title: "Analytics ID", value: trackingId)
                }
                if let trailer = channel.unsubscribedTrailer {
                    DetailRow(icon: "film", title: "Trailer Video ID", value: trailer)
                }
                if let colorText = channel.watchTextColor {
                    DetailRow(icon: "textformat", title: "Text Color", value: colorText)
                }
                if let bgText = channel.watchBackgroundColor {
                    DetailRow(icon: "paintpalette", title: "Background Color", value: bgText)
                }
                if let featPlaylistId = channel.watchFeaturedPlaylistId {
                    DetailRow(icon: "list.dash.header.rectangle", title: "Featured Playlist", value: featPlaylistId)
                }
            } header: {
                Text("Branding Details")
            }
            
            if let related = channel.relatedPlaylists, !related.isEmpty {
                Section {
                    ForEach(related.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        DetailRow(icon: "list.bullet.rectangle", title: key.capitalized, value: value)
                    }
                } header: {
                    Text("Related Playlists")
                }
            }
            
            Section {
                if let privacy = channel.privacyStatus {
                    DetailRow(icon: "lock.fill", title: "Privacy", value: privacy.capitalized)
                }
                if let isLinked = channel.isLinked {
                    DetailRow(icon: "link", title: "Linked Account", value: isLinked ? "Yes" : "No")
                }
                if let uploadsStatus = channel.longUploadsStatus {
                    DetailRow(icon: "video.badge.plus", title: "Long Uploads", value: uploadsStatus.capitalized)
                }
                if let madeForKids = channel.madeForKids {
                    DetailRow(icon: "figure.child", title: "Made for Kids", value: madeForKids ? "Yes" : "No")
                }
                if let selfDeclared = channel.selfDeclaredMadeForKids {
                    DetailRow(icon: "figure.child.circle", title: "Self Declared Kids", value: selfDeclared ? "Yes" : "No")
                }
            } header: {
                Text("Channel Status")
            }

            
            if channel.contentOwner != nil || channel.timeLinked != nil {
                Section {
                    if let owner = channel.contentOwner {
                        DetailRow(icon: "building.2.fill", title: "Network/Owner", value: owner)
                    }
                    if let date = channel.timeLinked {
                        DetailRow(icon: "clock.fill", title: "Linked On", value: date.formatted(date: .abbreviated, time: .omitted))
                    }
                } header: {
                    Text("Network Affiliation")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Formats integers like "1.2M", "45K", etc., or returns large precise number string if preferred.
    // Given the context of the detailed "About" page, exact numbers are preferred for views.
    private func formattedCount(_ count: Int?) -> String {
        guard let count = count else { return "-" }
        return count.formatted(.number)
    }

    private func formattedSubscriberCount(_ count: Int?, isHidden: Bool?) -> String {
        if isHidden == true { return "Hidden" }
        guard let count = count else { return "-" }
        
        return count.formatted(.number.notation(.compactName))
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var iconColor: Color? = nil
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor ?? .primary)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
