//
//  ErrorHandler.swift
//  SmallTube
//

import Foundation
import OSLog

enum ErrorHandler {
    static func mapErrorToAlertType(data: Data?, error: Error) -> AlertType {
        let logger = AppLogger.network

        if let data,
           let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            logger.error("API error \(errorResponse.error.code): \(errorResponse.error.message, privacy: .public)")
            switch errorResponse.error.code {
            case 403:  return .quotaExceeded
            case 400:  return .credsMismatch
            default:   return .apiError
            }
        }

        if let networkError = error as? NetworkError,
           case .httpError(let code) = networkError {
            logger.error("HTTP error \(code)")
            switch code {
            case 403: return .quotaExceeded
            case 400: return .credsMismatch
            default:  return .apiError
            }
        }

        logger.error("Unknown error: \(error.localizedDescription, privacy: .public)")
        return .unknownError
    }
}
