//
//  SavedSearchDetailView.swift
//  SmallTube
//
//  Created by John Notaris on 16/5/24.
//

import SwiftUI

struct SavedSearchDetailView: View {
    var videos: [YouTubeVideo]
    var query: String
    
    var body: some View {
        VideoListView(videos: videos)
            .navigationBarTitle(Text(query), displayMode: .inline)
    }
}
