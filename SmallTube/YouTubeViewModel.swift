//
//  YouTubeViewModel.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import Foundation
import SwiftUI

enum AlertType: Identifiable {
    case noResults, apiError, emptyQuery, quotaExceeded
    var id: Int {
        switch self {
        case .noResults:
            return 0
        case .apiError:
            return 1
        case .emptyQuery:
            return 2
        case .quotaExceeded:
            return 3
        }
    }
}

class YouTubeViewModel: ObservableObject {
    @Published var videos = [YouTubeVideo]()
    @Published var currentAlert: AlertType?
    
    var lastSearches: [String] {
        get {
            return UserDefaults.standard.array(forKey: "lastSearches") as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastSearches")
        }
    }
    
    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }
    
    var resultsCount: String {
        get { UserDefaults.standard.string(forKey: "resultsCount") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "resultsCount") }
    }
    
    func searchVideos(query: String) {
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .emptyQuery
            }
            return
        }
        // Save the search query
        var searches = lastSearches
        if !searches.contains(query) {
            searches.insert(query, at: 0)
            if searches.count > 10 {
                searches = Array(searches.prefix(10))
            }
            lastSearches = searches
        }
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.currentAlert = .apiError
            }
            return
        }
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&q=\(query)&maxResults=\(resultsCount)&key=\(apiKey)&type=video"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data {
                do {
                    let response = try JSONDecoder().decode(YouTubeResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.videos = response.items
                        self.currentAlert = self.videos.isEmpty ? .noResults : nil
                    }
                } catch {
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
                       errorResponse.error.code == 403 {
                        DispatchQueue.main.async {
                            self.currentAlert = .quotaExceeded
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.currentAlert = .apiError
                        }
                    }
                }
            }
        }.resume()
    }
    
    func searchSuggestions(query: String) -> [String] {
        return lastSearches
    }
    
    func deleteSearches(at offsets: IndexSet) {
        lastSearches.remove(atOffsets: offsets)
        lastSearches = lastSearches
    }
}

struct YouTubeResponse: Decodable {
    let items: [YouTubeVideo]
}

struct ErrorResponse: Decodable {
    let error: APIError
}

struct APIError: Decodable {
    let code: Int
    let message: String
    let errors: [ErrorDetail]
}

struct ErrorDetail: Decodable {
    let message: String
    let domain: String
    let reason: String
}
