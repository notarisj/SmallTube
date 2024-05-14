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
    var video: YouTubeVideo
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
        .edgesIgnoringSafeArea(.all) // Add this line
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
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
