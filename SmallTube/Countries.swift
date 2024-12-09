//
//  Countries.swift
//  SmallTube
//
//  Created by John Notaris on 12/9/24.
//

import Foundation

struct Country: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
}

class CountryStore: ObservableObject {
    @Published var countries: [Country] = []
    
    init() {
        loadCountries()
    }
    
    private func loadCountries() {
        guard let url = Bundle.main.url(forResource: "Countries", withExtension: "json") else {
            print("Countries.json not found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: [Country]].self, from: data)
            if let countryArray = decoded["countries"] {
                // Sort countries by name or code if desired
                self.countries = countryArray.sorted(by: { $0.name < $1.name })
            }
        } catch {
            print("Error loading or decoding countries: \(error)")
        }
    }
}
