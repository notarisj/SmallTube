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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
