//
//  MainTabView.swift
//  emolody2
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var user: UserStore
    @ObservedObject var musicManager: EmolodyMusicManager
    @StateObject private var moodManager = MoodManager.shared
    @StateObject private var musicServiceManager = MusicServiceManager.shared

    var openPlaylist: (String) -> Void
    var startMoodDetection: () -> Void
    var openPreferences: () -> Void
    var logout: () -> Void
    
    @State private var selectedTab: Int  // Remove = 0
    
    // Add this initializer
    init(user: UserStore,
         musicManager: EmolodyMusicManager,
         openPlaylist: @escaping (String) -> Void,
         startMoodDetection: @escaping () -> Void,
         openPreferences: @escaping () -> Void,
         logout: @escaping () -> Void,
         initialTab: Int = 0) {
        
        self.user = user
        self.musicManager = musicManager
        self.openPlaylist = openPlaylist
        self.startMoodDetection = startMoodDetection
        self.openPreferences = openPreferences
        self.logout = logout
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                user: user,
                musicManager: musicManager,
                startMoodDetection: startMoodDetection,
                openPlaylist: { mood in
                    if let userMood = UserMood.allCases.first(where: { $0.rawValue == mood }) {
                        moodManager.updateMood(userMood)
                    }
                    selectedTab = 1
                }
            )
            .environmentObject(moodManager)
            .environmentObject(musicServiceManager)
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            NavigationView {
                PlaylistView()
                    .environmentObject(moodManager)
                    .environmentObject(musicServiceManager)
            }
            .tabItem {
                Image(systemName: "music.note.list")
                Text("Playlists")
            }
            .tag(1)

            PodcastsView()
                .tabItem {
                    Image(systemName: "mic.fill")
                    Text("Podcasts")
                }
                .tag(2)

            ProfileView(
                user: user,
                musicManager: musicManager,
                openPreferences: openPreferences,
                onLogout: logout
            )
            .tabItem {
                Image(systemName: "person.fill")
                Text("Profile")
            }
            .tag(3)
        }
        .onAppear {
            syncMusicManagers()
        }
    }
    
    private func syncMusicManagers() {
        if musicManager.isAuthorized {
            musicServiceManager.connectedService = .appleMusic
            musicServiceManager.isAuthenticated = true
            musicServiceManager.userName = musicManager.appleUserName
            musicServiceManager.userEmail = musicManager.appleUserEmail
            Task {
                await musicServiceManager.analyzeUserMusicTaste()
            }
        }
        
        if UserDefaults.standard.bool(forKey: "is_spotify_connected") {
            musicServiceManager.connectedService = .spotify
            musicServiceManager.isAuthenticated = true
            musicServiceManager.userName = "Spotify User"
            Task {
                await musicServiceManager.analyzeUserMusicTaste()
            }
        }
    }
}
