//
//  SmallTubeApp.swift
//  SmallTube
//
//  Created by John Notaris on 12/5/24.
//

import SwiftUI

@main
struct SmallTubeApp: App {
    @StateObject var authManager = AuthManager()
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var showSettings = false
}
