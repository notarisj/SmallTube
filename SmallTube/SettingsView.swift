//
//  SettingsView.swift
//  SmallTube
//
//  Created by John Notaris on 11/5/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("resultsCount") var resultsCount: Int = 10
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
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
            Section {
                Button("Save") {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .navigationBarTitle("Settings")
    }
}
