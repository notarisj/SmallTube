//
//  SidebarSelection.swift
//  SmallTube
//
//  Created by John Notaris on 12/14/24.
//

import SwiftUI

enum SidebarItem: String, Hashable, Identifiable {
    var id: String { self.rawValue }
    
    case home
    case trending
    case search
    case subscriptions
}
