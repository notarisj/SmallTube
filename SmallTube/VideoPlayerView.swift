//
//  VideoPlayerView.swift
//  SmallTube
//

import Foundation
import SwiftUI
import WebKit

struct VideoPlayerView: View {
    var video: CachedYouTubeVideo
    @State private var isLoading = true
    @State private var isDescriptionExpanded = false

    // Formatted publish date
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: video.publishedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── 16:9 Player (fixed) ────────────────────────────────────────
            GeometryReader { geo in
                ZStack {
                    Color.black

                    if let embedURL = URL(string: "https://www.youtube.com/embed/\(video.id)") {
                        WebView(url: embedURL, isLoading: $isLoading)
                    }

                    if isLoading {
                        Color.black
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // ── Scrollable info card ───────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Title
                    Text(video.title)
                        .font(.system(.title3, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Publish date
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    // Description with expand/collapse
                    if !video.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(video.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(isDescriptionExpanded ? nil : 3)
                                .animation(.easeInOut(duration: 0.25), value: isDescriptionExpanded)

                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isDescriptionExpanded.toggle()
                                }
                            } label: {
                                Text(isDescriptionExpanded ? "Less" : "More")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(video.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ── WebView ────────────────────────────────────────────────────────────────

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false

        let embedPath = "https://www.youtube.com/embed/\(url.lastPathComponent)?playsinline=1&autoplay=1&rel=0&modestbranding=1&origin=http://localhost"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body, html { margin: 0; padding: 0; background-color: black; height: 100%; overflow: hidden; }
                iframe { width: 100%; height: 100%; border: 0; }
            </style>
        </head>
        <body>
            <iframe src="\(embedPath)" width="100%" height="100%" frameborder="0"
                allow="autoplay; encrypted-media; fullscreen" allowfullscreen
                referrerpolicy="strict-origin-when-cross-origin"></iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "http://localhost"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        init(_ parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
