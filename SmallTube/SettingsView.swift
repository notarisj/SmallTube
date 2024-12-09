import SwiftUI
import AuthenticationServices
import CommonCrypto

struct SettingsView: View {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("resultsCount") var resultsCount: Int = 10
    @AppStorage("userToken") var userToken: String?
    @AppStorage("countryCode") var countryCode: String = "US" // Default country code

    // OAuth Configuration
    let clientID = "CLIENT_ID"
    let redirectURI = "com.smalltube:/oauthredirect"
    let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    let tokenEndpoint = "https://oauth2.googleapis.com/token"
    let scopes = "https://www.googleapis.com/auth/youtube.readonly"
    
    @Environment(\.presentationMode) var presentationMode
    
    // Create a coordinator instance
    private let authCoordinator = AuthCoordinator()

    @StateObject var countryStore = CountryStore()

    // PKCE variables
    @State private var codeVerifier: String = ""
    @State private var codeChallenge: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Authentication")) {
                    if let token = userToken {
                        Text("Signed In: \(token.prefix(10))...")
                        Button("Sign Out") {
                            userToken = nil
                        }
                    } else {
                        Button("Sign In with Google") {
                            startSignInFlow()
                        }
                    }
                }
                
                Section(header: Text("API Key")) {
                    TextField("Enter API Key", text: $apiKey)
                }
                
                Section(header: Text("Results Count")) {
                    Picker("Results Count", selection: $resultsCount) {
                        ForEach(1...100, id: \.self) {
                            Text("\($0)")
                        }
                    }
                }
                
                // New section for country code
                Section(header: Text("Country Code")) {
                    Menu {
                        ForEach(countryStore.countries) { country in
                            Button(country.name) {
                                countryCode = country.code
                            }
                        }
                    } label: {
                        Text("Selected: \(countryCode)")
                    }
                }
                
                Section {
                    Button("Save") {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationBarTitle("Settings")
        }
    }
    
    private func startSignInFlow() {
        // Generate PKCE code verifier and code challenge
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
        
        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "com.smalltube") { callbackURL, error in
            guard error == nil, let callbackURL = callbackURL else {
                return
            }
            
            if let code = getQueryParam(from: callbackURL, param: "code") {
                exchangeCodeForToken(code: code)
            }
        }
        
        // Assign the presentation context provider to the class-based coordinator
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
                    }
                }
            } catch {
                print("Failed to parse token response: \(error)")
            }
        }.resume()
    }
    
    private func getQueryParam(from url: URL, param: String) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == param })?.value
    }

    // MARK: - PKCE Helpers
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
}

// MARK: - AuthCoordinator
class AuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Find a suitable window from the scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
