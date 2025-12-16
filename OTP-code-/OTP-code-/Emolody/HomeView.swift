//
//  HomeView.swift
//  emolody2
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var user: UserStore
    var musicManager: EmolodyMusicManager?
    var startMoodDetection: () -> Void
    var openPlaylist: (String) -> Void
    
    @EnvironmentObject private var moodManager: MoodManager
    @EnvironmentObject private var musicServiceManager: MusicServiceManager

    var body: some View {
        ZStack {
            AppScreenBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Greeting - moved closer to top with adjusted padding
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hello\(getUserName())!")
                            .font(.title).bold()
                            .foregroundStyle(Brand.textPrimary)
                            .padding(.top, 8) // Reduced top padding
                        Text("How are you feeling today?")
                            .font(.subheadline)
                            .foregroundStyle(Brand.textSecondary)
                        
                        if isMusicServiceConnected() {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(getConnectionStatusText())
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 20) // Reduced from 40 to 20

                    // Mood Detection Button (bigger & centered)
                    Button(action: startMoodDetection) {
                        ZStack {
                            Circle()
                                .fill(Brand.primary)
                                .frame(width: 220, height: 220)
                                .shadow(radius: 12)
                            Text("Start\nMood Detection")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 10) // Added vertical padding

                    // LAST DETECTED MOOD
                    if !user.lastMood.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LAST DETECTED MOOD")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Brand.textSecondary)
                                .padding(.horizontal)

                            Button(action: {
                                openPlaylistWithMood(user.lastMood)
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 44, height: 44)
                                        Text("😊")
                                            .font(.system(size: 26))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.lastMood)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(Brand.textPrimary)

                                        Text(lastMoodTimeText())
                                            .font(.caption)
                                            .foregroundColor(Brand.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Brand.textSecondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.orange.opacity(0.5),
                                                    Color.pink.opacity(0.5)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                    }

                    // Music Stats
                    if isMusicServiceConnected() {
                        VStack(spacing: 10) {
                            Text("Your Music")
                                .font(.headline)
                                .foregroundStyle(Brand.textPrimary)
                            
                            HStack {
                                VStack {
                                    Text("\(getPlaylistCount())")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(getServiceColor())
                                    Text("Playlists")
                                        .font(.caption)
                                        .foregroundColor(Brand.textSecondary)
                                }
                                Spacer()
                                VStack {
                                    Image(systemName: getServiceIcon())
                                        .font(.title2)
                                        .foregroundColor(getServiceColor())
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(Brand.textSecondary)
                                }
                                Spacer()
                                VStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(Brand.textSecondary)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // The Suggested Playlists section has been removed
                }
                .padding(.bottom, 30) // Extra bottom padding for safe area
            }
        }
        .navigationBarBackButtonHidden(true) // This hides the back button
        .onAppear {
            syncMusicServices()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getUserName() -> String {
        if let musicManager = musicManager, musicManager.isAuthorized && !musicManager.appleUserName.isEmpty {
            return ", \(musicManager.appleUserName)"
        } else if musicServiceManager.connectedService == .spotify && !musicServiceManager.spotifyUserName.isEmpty {
            return ", \(musicServiceManager.spotifyUserName)"
        } else if !musicServiceManager.userName.isEmpty && musicServiceManager.userName != "Spotify User" {
            return ", \(musicServiceManager.userName)"
        } else if !user.name.isEmpty {
            return ", \(user.name)"
        } else {
            return ""
        }
    }
    
    private func openPlaylistWithMood(_ mood: String) {
        if let userMood = UserMood.allCases.first(where: { $0.rawValue == mood }) {
            moodManager.updateMood(userMood)
        }
        openPlaylist(mood)
    }
    
    private func isMusicServiceConnected() -> Bool {
        return musicServiceManager.isAuthenticated || (musicManager?.isAuthorized == true)
    }
    
    private func getConnectionStatusText() -> String {
        if musicServiceManager.connectedService == .appleMusic || musicManager?.isAuthorized == true {
            return "Connected to Apple Music"
        } else if musicServiceManager.connectedService == .spotify {
            return "Connected to Spotify"
        } else {
            return "Music Service Connected"
        }
    }
    
    private func getServiceIcon() -> String {
        if musicServiceManager.connectedService == .appleMusic || musicManager?.isAuthorized == true {
            return "applelogo"
        } else if musicServiceManager.connectedService == .spotify {
            return "music.note"
        } else {
            return "music.note"
        }
    }
    
    private func getServiceColor() -> Color {
        if musicServiceManager.connectedService == .appleMusic || musicManager?.isAuthorized == true {
            return .red
        } else if musicServiceManager.connectedService == .spotify {
            return .green
        } else {
            return .gray
        }
    }
    
    private func getPlaylistCount() -> Int {
        if musicServiceManager.connectedService == .appleMusic || musicManager?.isAuthorized == true {
            return musicManager?.userPlaylists.count ?? 0
        } else if musicServiceManager.connectedService == .spotify {
            return musicServiceManager.getPlaylistCount()
        } else {
            return musicServiceManager.userPreferences.count
        }
    }
    
    private func syncMusicServices() {
        if let musicManager = musicManager,
           musicManager.isAuthorized &&
           !musicServiceManager.isAuthenticated {
            
            musicServiceManager.connectedService = .appleMusic
            musicServiceManager.isAuthenticated = true
            musicServiceManager.userName = musicManager.appleUserName
            musicServiceManager.userEmail = musicManager.appleUserEmail
            Task {
                await musicServiceManager.analyzeUserMusicTaste()
            }
        }
    }

    private func lastMoodTimeText() -> String {
        let key = "lastMoodTimestamp"
        guard let ts = UserDefaults.standard.object(forKey: key) as? Double else {
            return "Last detected recently"
        }
        let date = Date(timeIntervalSince1970: ts)
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "Last detected just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "Last detected \(minutes) min ago"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "Last detected \(hours) hour\(hours > 1 ? "s" : "") ago"
        }
        let days = hours / 24
        return "Last detected \(days) day\(days > 1 ? "s" : "") ago"
    }
}

// The SuggestedRow struct can also be removed since it's no longer used
// But I'll leave it commented in case you need it elsewhere

/*
struct SuggestedRow: View {
    let title: String
    let type: String
    var onOpen: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundStyle(Brand.textPrimary)
                Text(type).font(.caption).foregroundStyle(Brand.textSecondary)
            }
            Spacer()

            Button("Open", action: onOpen)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(20)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
*/
