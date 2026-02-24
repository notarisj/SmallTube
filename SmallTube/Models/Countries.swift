//
//  Countries.swift
//  SmallTube
//

import Foundation

struct Country: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
}

@Observable
final class CountryStore {
    private(set) var countries: [Country] = []

    init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "Countries", withExtension: "json") else {
            AppLogger.data.error("Countries.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: [Country]].self, from: data)
            countries = (decoded["countries"] ?? []).sorted { $0.name < $1.name }
        } catch {
            AppLogger.data.error("Failed to load countries: \(error.localizedDescription, privacy: .public)")
        }
    }
}
