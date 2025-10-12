//
//  AuthManager.swift
//  SmallTube
//
//  Created by John Notaris on 12/12/24.
//

import Foundation
import AuthenticationServices
import CommonCrypto
import SwiftUI

class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var userToken: String? {
        didSet {
            UserDefaults.standard.set(userToken, forKey: "userToken")
            if userToken != nil {
                // If we have a stored name, use it; else fetch
                if let storedName = UserDefaults.standard.string(forKey: "userDisplayName") {
                    self.userDisplayName = storedName
                } else {
                    fetchUserDisplayName()
                }
            } else {
                userDisplayName = nil
            }
        }
    }
    
    @Published var userDisplayName: String? {
        didSet {
            if let name = userDisplayName {
                UserDefaults.standard.set(name, forKey: "userDisplayName")
            } else {
                UserDefaults.standard.removeObject(forKey: "userDisplayName")
            }
        }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "refreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "refreshToken") }
    }

    private let clientID = "749795843940-854qs9malflls9b1dllks8p66ctv1jnd.apps.googleusercontent.com"
    private let redirectURI = "com.notaris.SmallTube:/oauthredirect"
    private let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private let scopes = "https://www.googleapis.com/auth/youtube.readonly"
    
    private var codeVerifier: String = ""
    private var codeChallenge: String = ""
    
    private let authCoordinator = AuthCoordinator()
    
    override init() {
        super.init()
        userToken = UserDefaults.standard.string(forKey: "userToken")
        // Attempt to refresh token on init if we have a refresh token but no access token
        if userToken == nil, refreshToken != nil {
            refreshAccessToken { success in
                if !success {
                    self.signOut()
                }
            }
        }
    }
    
    func signOut() {
        userToken = nil
        refreshToken = nil
        userDisplayName = nil
    }
    
    func startSignInFlow() {
        codeVerifier = generateCodeVerifier()
        codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authURL = components.url else { return }
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.notaris.SmallTube") { callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else {
                return
            }
            
            if let code = self.getQueryParam(from: callbackURL, param: "code") {
                self.exchangeCodeForToken(code: code)
            }
        }
        
        session.presentationContextProvider = authCoordinator
        session.start()
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: tokenEndpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = body.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    DispatchQueue.main.async {
                        self.userToken = accessToken
                        if let rt = json["refresh_token"] as? String {
                            self.refreshToken = rt
                        }
                    }
                }
            } catch {
                print("Failed to parse token response: \(error)")
            }
        }.resume()
    }
    
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken else {
            completion(false)
            return
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newAccessToken = json["access_token"] as? String {
                    DispatchQueue.main.async {
                        self.userToken = newAccessToken
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } catch {
                print("Failed to refresh token: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func fetchUserDisplayName() {
        guard let token = userToken else { return }
        let urlString = "https://www.googleapis.com/youtube/v3/channels?mine=true&part=snippet"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else { return }
            do {
                let channelResponse = try JSONDecoder().decode(ChannelListResponse.self, from: data)
                if let title = channelResponse.items.first?.snippet.title {
                    DispatchQueue.main.async {
                        self.userDisplayName = title
                    }
                }
            } catch {
                print("Failed to parse channel info: \(error)")
            }
        }.resume()
    }
    
    func ensureValidToken(completion: @escaping (Bool) -> Void) {
        if let _ = userToken {
            completion(true)
        } else if refreshToken != nil {
            refreshAccessToken(completion: completion)
        } else {
            completion(false)
        }
    }
    
    private func getQueryParam(from url: URL, param: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == param })?.value
    }

    private func generateCodeVerifier() -> String {
        let length = 32
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        let base64Url = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return base64Url
    }
    
    func makeAuthenticatedRequest(url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let token = userToken else {
            completion(nil, nil, NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "No token available"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Check if we got a 401 (unauthorized) response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                // Token expired, try to refresh
                self?.refreshAccessToken { success in
                    if success {
                        // Retry the request with new token
                        var retryRequest = URLRequest(url: url)
                        retryRequest.setValue("Bearer \(self?.userToken ?? "")", forHTTPHeaderField: "Authorization")
                        
                        URLSession.shared.dataTask(with: retryRequest) { retryData, retryResponse, retryError in
                            completion(retryData, retryResponse, retryError)
                        }.resume()
                    } else {
                        // Refresh failed, sign out user
                        DispatchQueue.main.async {
                            self?.signOut()
                        }
                        completion(nil, response, error)
                    }
                }
            } else {
                // Normal response, return as-is
                completion(data, response, error)
            }
        }.resume()
    }
}

// MARK: - AuthCoordinator
class AuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Models for Parsing Channel Info
struct YouTubeChannelResponse: Decodable {
    let items: [YouTubeChannelItem]
}

struct YouTubeChannelItem: Decodable {
    let snippet: YouTubeChannelSnippet
}

struct YouTubeChannelSnippet: Decodable {
    let title: String
}

// Models for channel response
struct ChannelListResponse: Decodable {
    let items: [ChannelItem]
}

struct ChannelItem: Decodable {
    let snippet: ChannelSnippet
}

struct ChannelSnippet: Decodable {
    let title: String
}
