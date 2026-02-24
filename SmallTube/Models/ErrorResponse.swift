//
//  ErrorResponse.swift
//  SmallTube
//
//  Created by John Notaris on 12/11/24.
//

import Foundation

struct ErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let code: Int
        let message: String
    }

    let error: ErrorDetail
}
