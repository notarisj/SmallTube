//
//  SmallTubeApp.swift
//  SmallTube
//

import SwiftUI

@main
struct SmallTubeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
