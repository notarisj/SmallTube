//
//  AlertBuilder.swift
//  SmallTube
//

import SwiftUI

enum AlertBuilder {
    static func buildAlert(for alertType: AlertType) -> Alert {
        switch alertType {
        case .noResults:
            return Alert(
                title: Text("No Results"),
                message: Text("No videos found for this query."),
                dismissButton: .default(Text("OK"))
            )
        case .apiError:
            return Alert(
                title: Text("API Error"),
                message: Text("Unable to load content. Please check your API key and network connection."),
                dismissButton: .default(Text("OK"))
            )
        case .emptyQuery:
            return Alert(
                title: Text("Empty Search"),
                message: Text("Please enter a search term."),
                dismissButton: .default(Text("OK"))
            )
        case .quotaExceeded:
            return Alert(
                title: Text("Quota Exceeded"),
                message: Text("Your YouTube API quota has been exceeded. Try again tomorrow."),
                dismissButton: .default(Text("OK"))
            )
        case .credsMismatch:
            return Alert(
                title: Text("Credentials Mismatch"),
                message: Text("The API key and authentication credential are from different projects."),
                dismissButton: .default(Text("OK"))
            )
        case .unknownError:
            return Alert(
                title: Text("Something Went Wrong"),
                message: Text("An unexpected error occurred. Please try again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
