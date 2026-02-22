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

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 16:9 video container
                ZStack {
                    if let embedURL = URL(string: "https://www.youtube.com/embed/\(video.id)") {
                        WebView(url: embedURL, isLoading: $isLoading)
                    }
                    if isLoading {
                        Color.black
                        ProgressView("Loading…")
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .scaleEffect(2)
                    }
                }
                .frame(height: geo.size.width * 9 / 16)
                .background(Color.black)

                // Scrollable description
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(video.title)
                            .font(.headline)
                            .padding(.top)

                        Text(video.description)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(video.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

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
