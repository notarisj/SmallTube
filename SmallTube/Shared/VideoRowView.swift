//
//  VideoRowView.swift
//  SmallTube
//
//  YouTube-style video card with native Apple design:
//  → Full-width 16:9 thumbnail with duration badge
//  → Channel avatar  |  Title (2 lines)  |  Channel · time ago
//

import SwiftUI

struct VideoRowView: View {
    let video: CachedYouTubeVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Thumbnail ──────────────────────────────────────────────────
            thumbnailSection

            // ── Metadata row ───────────────────────────────────────────────
            HStack(alignment: .top, spacing: 10) {
                channelAvatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        if !video.channelTitle.isEmpty {
                            Text(video.channelTitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        if !video.channelTitle.isEmpty {
                            Text("·")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        Text(video.publishedAt.relativeShortString)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)


            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        // No extra padding — the List row insets handle outer spacing
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailSection: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { geo in
                AsyncImage(url: video.thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    case .failure:
                        ZStack {
                            Color(uiColor: .systemGray5)
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                    default:
                        Color(uiColor: .systemGray5)
                            .overlay {
                                ProgressView()
                                    .tint(.secondary)
                            }
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
        }
    }

    // MARK: - Channel avatar (initials fallback)

    @ViewBuilder
    private var channelAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarGradient)
            Text(video.channelTitle.avatarInitials)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 34, height: 34)
    }

    private var avatarGradient: LinearGradient {
        let seed = abs(video.channelId.hashValue)
        let hue = Double(seed % 360) / 360.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.85),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1.0),
                      saturation: 0.75, brightness: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - String helpers

private extension String {
    /// Returns up to two capital initials for an avatar placeholder.
    var avatarInitials: String {
        let words = self.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let initials = words.prefix(2).compactMap { $0.first.map { String($0) } }
        return initials.joined().uppercased()
    }
}

// MARK: - Date helper

private extension Date {
    var relativeShortString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
