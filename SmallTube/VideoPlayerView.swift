//
//  VideoPlayerView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import Foundation
import SwiftUI
import WebKit

struct VideoPlayerView: View {
    var video: CachedYouTubeVideo // Change from YouTubeVideo to CachedYouTubeVideo
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            WebView(url: URL(string: "https://www.youtube.com/embed/\(video.id)")!, isLoading: $isLoading)
            if isLoading {
                Color.black
                VStack {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        .scaleEffect(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView for YouTube embed playback
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        let embedUrl = "https://www.youtube.com/embed/\(url.lastPathComponent)?playsinline=1&autoplay=1&rel=0&modestbranding=1&origin=http://localhost"
        
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
            <iframe src="\(embedUrl)" width="100%" height="100%" frameborder="0" allow="autoplay; encrypted-media; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: URL(string: "http://localhost"))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}
