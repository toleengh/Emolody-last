//
//  emolody2App.swift
//  emolody2
//

import SwiftUI

@main
struct EmolodyApp: App {
    @StateObject private var musicServiceManager = MusicServiceManager.shared
    @StateObject private var moodManager = MoodManager.shared
    // REMOVE: @StateObject private var userStore = UserStore() - Not needed with singleton
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(musicServiceManager)
                .environmentObject(moodManager)
                // REMOVE: .environmentObject(userStore) - Not needed with singleton
                .onOpenURL { url in
                    if url.absoluteString.contains("toleen.emolody2://callback") {
                        let success = musicServiceManager.handleSpotifyCallback(url: url)
                        
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SpotifyCallback"),
                            object: nil,
                            userInfo: ["url": url]
                        )
                        
                        print("Spotify callback handled by both systems: \(success ? "Success" : "Failed")")
                    }
                }
        }
    }
}
