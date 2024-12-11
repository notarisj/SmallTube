//
//  ErrorHandler.swift
//  SmallTube
//
//  Created by John Notaris on 12/11/24.
//

import Foundation

struct ErrorHandler {
    static func mapErrorToAlertType(data: Data?, error: Error) -> AlertType {
        // Attempt to decode the ErrorResponse
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            print("API error code: \(errorResponse.error.code)")
            print("Message: \(errorResponse.error.message)")
            
            switch errorResponse.error.code {
            case 403:
                return .quotaExceeded
            case 400:
                return .credsMismatch
            default:
                return .apiError
            }
        } else {
            // If decoding fails or data is nil, return unknownError
            print("Unknown error: \(error.localizedDescription)")
            return .unknownError
        }
    }
}
