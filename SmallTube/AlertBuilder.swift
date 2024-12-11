//
//  AlertBuilder.swift
//  SmallTube
//
//  Created by John Notaris on 12/11/24.
//

import SwiftUI

struct AlertBuilder {
    static func buildAlert(for alertType: AlertType) -> Alert {
        switch alertType {
        case .noResults:
            return Alert(
                title: Text("No Results"),
                message: Text("No results found."),
                dismissButton: .default(Text("OK"))
            )
        case .apiError:
            return Alert(
                title: Text("API Error"),
                message: Text("Unable to load data. Please check your API key and network connection."),
                dismissButton: .default(Text("OK"))
            )
        case .emptyQuery:
            return Alert(
                title: Text("Empty Query"),
                message: Text("Please enter a search term."),
                dismissButton: .default(Text("OK"))
            )
        case .quotaExceeded:
            return Alert(
                title: Text("Quota Exceeded"),
                message: Text("You have exceeded your YouTube API quota."),
                dismissButton: .default(Text("OK"))
            )
        case .credsMismatch:
            return Alert(
                title: Text("Credentials Mismatch"),
                message: Text("The API Key and the authentication credential are from different projects."),
                dismissButton: .default(Text("OK"))
            )
        case .unknownError:
            return Alert(
                title: Text("Unknown Error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
