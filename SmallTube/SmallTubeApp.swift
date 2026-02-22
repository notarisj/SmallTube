//
//  SmallTubeApp.swift
//  SmallTube
//

import SwiftUI

@main
struct SmallTubeApp: App {
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
