//
//  VideoPlayerView.swift
//  SmallTube
//

import SwiftUI
import WebKit

struct VideoPlayerView: View {
    let video: CachedYouTubeVideo

    @State private var isLoading = true
    @State private var isDescriptionExpanded = false
    @State private var fullscreenTrigger = false
    @AppStorage("autoplay") private var autoplay = true

    // Static DateFormatter — allocated once, not on every render.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: video.publishedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── 16:9 Player ──────────────────────────────────────────────
            GeometryReader { geo in
                ZStack {
                    Color.black
                    if let embedURL = URL(string: "https://www.youtube.com/embed/\(video.id)") {
                        YouTubeWebView(url: embedURL, isLoading: $isLoading, fullscreenTrigger: $fullscreenTrigger, autoplay: autoplay)
                    }
                    if isLoading {
                        Color.black
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width * 9 / 16)
            }
            .aspectRatio(16 / 9, contentMode: .fit)

            // ── Fixed Info Header ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    NavigationLink(destination: ChannelVideosView(channel: YouTubeChannel(
                        id: video.channelId,
                        title: video.channelTitle,
                        description: "",
                        thumbnailURL: video.channelIconURL ?? URL(string: "https://youtube.com")!
                    ))) {
                        AsyncImage(url: video.channelIconURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.secondary)
                            default:
                                Color.secondary.opacity(0.15)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text(video.title)
                        .font(.system(.title3, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .background(Color(.systemBackground))

            // ── Scrollable Description ───────────────────────────────────
            ScrollView {
                if !video.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(isDescriptionExpanded ? nil : 4)
                        
                        HStack {
                            Spacer()
                            Text(isDescriptionExpanded ? "Show Less" : "Show More")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDescriptionExpanded.toggle()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(video.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    fullscreenTrigger = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.medium))
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - YouTube WebView

private struct YouTubeWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var fullscreenTrigger: Bool
    let autoplay: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = autoplay ? [] : .all

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false

        let embedPath = "https://www.youtube.com/embed/\(url.lastPathComponent)?playsinline=1&autoplay=\(autoplay ? 1 : 0)&rel=0&modestbranding=1&origin=http://localhost"
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
            <iframe id="player" src="\(embedPath)" width="100%" height="100%" frameborder="0"
                allow="autoplay; encrypted-media; fullscreen" allowfullscreen
                referrerpolicy="strict-origin-when-cross-origin"></iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "http://localhost"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if fullscreenTrigger {
            let js = "document.getElementById('player').webkitRequestFullscreen();"
            uiView.evaluateJavaScript(js)
            
            // Core logic: reset trigger on main thread to avoid state cycles
            DispatchQueue.main.async {
                fullscreenTrigger = false
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: YouTubeWebView
        init(_ parent: YouTubeWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
