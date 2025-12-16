import Foundation
import SwiftUI
import Combine
import MusicKit

class PlaylistGenerator: ObservableObject {
    @Published var generatedPlaylist: [SongItem] = []
    @Published var isLoading: Bool = false
    @Published var lastGenerationMood: UserMood? = nil
    
    private let musicServiceManager = MusicServiceManager.shared
    
    func generatePlaylist(for mood: UserMood) async {
        await MainActor.run {
            isLoading = true
            generatedPlaylist = []
        }
        
        // Use both user preferences and mood analysis
        let userPreferences = musicServiceManager.userPreferences
        let songs = await musicServiceManager.searchSongsForMood(mood, preferences: userPreferences)
        
        // Enhance songs with service-specific data
        var enhancedSongs = songs
        if musicServiceManager.connectedService != .none {
            enhancedSongs = await enhanceSongsWithServiceData(songs: songs, mood: mood)
        }
        
        await MainActor.run {
            generatedPlaylist = enhancedSongs
            isLoading = false
            lastGenerationMood = mood
            print("🎵 Generated \(enhancedSongs.count) songs for \(mood.rawValue) mood")
            print("   - User preferences: \(userPreferences)")
        }
    }
    
    private func enhanceSongsWithServiceData(songs: [SongItem], mood: UserMood) async -> [SongItem] {
        var enhancedSongs: [SongItem] = []
        
        for song in songs {
            // Check if we already have service data for this song
            if (musicServiceManager.connectedService == .appleMusic && song.appleMusicURL != nil) ||
               (musicServiceManager.connectedService == .spotify && song.spotifyURL != nil) {
                enhancedSongs.append(song)
                continue
            }
            
            // Search based on connected service
            switch musicServiceManager.connectedService {
            case .appleMusic:
                if let enhancedSong = await searchAppleMusicSong(song: song) {
                    enhancedSongs.append(enhancedSong)
                } else {
                    enhancedSongs.append(song)
                }
                
            case .spotify:
                if let enhancedSong = await searchSpotifySong(song: song) {
                    enhancedSongs.append(enhancedSong)
                } else {
                    enhancedSongs.append(song)
                }
                
            case .none:
                enhancedSongs.append(song)
            }
        }
        
        return enhancedSongs
    }
    
    private func searchAppleMusicSong(song: SongItem) async -> SongItem? {
        do {
            let searchTerm = "\(song.title) \(song.artist)"
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
            request.limit = 1
            
            let response = try await request.response()
            
            if let appleMusicSong = response.songs.first {
                let enhancedSong = SongItem(
                    title: song.title,
                    artist: song.artist,
                    duration: song.duration,
                    appleMusicID: appleMusicSong.id.rawValue,
                    appleMusicURL: URL(string: "https://music.apple.com/song/\(appleMusicSong.id.rawValue)")
                )
                print("✅ Found Apple Music song: \(song.title)")
                return enhancedSong
            } else {
                print("⚠️ Could not find Apple Music song: \(song.title)")
                return nil
            }
        } catch {
            print("❌ Error searching for Apple Music song '\(song.title)': \(error)")
            return nil
        }
    }
    
    private func searchSpotifySong(song: SongItem) async -> SongItem? {
        // Mock implementation - in a real app, use Spotify Web API
        let mockSpotifyIDs: [String: String] = [
            "Blinding Lights": "0VjIjW4GlUZAMYd2vXMi3b",
            "Levitating": "0WIr2S2FvA2vLwQN2pihzU",
            "Watermelon Sugar": "6UelLqGlWMcVH1E5c4H7lY",
            "Don't Start Now": "3PfIrDoz19wz7qK7tYeu62",
            "Save Your Tears": "5QO79kh1waicV47BqGRL3g",
            "SICKO MODE": "2xLMifQCjDGFmkHkpNLD9h",
            "God's Plan": "6DCZcSspjsKoFjzjrWoCdn",
            "Wow.": "6MWtB6iiXyIwun0YzU6DFP",
            "Rockstar": "0e7ipj03S05BNilyu5bRzt",
            "Life Is Good": "0eIwNYmwf5uB3Idf5xykGy",
            "Bohemian Rhapsody": "3z8h0TU7ReDPLIbEnYhWZb",
            "Happy": "60nZcImufyMA1MKQY3dcCH",
            "Someone Like You": "1zwMYTA5nlNjZxYrvBB2pV",
            "Eye of the Tiger": "2HHtWyy5CgaQbC7XSoOb0e",
            "Perfect": "0tgVpDi06FyKpA1z0VMD4v",
            "Midnight City": "1eyzqe2QqGZUmfcPZtrIyt",
            "Break Stuff": "2YC6ET3q1F29B0V7UcPV70"
        ]
        
        // Try to find a mock Spotify ID
        if let spotifyID = mockSpotifyIDs[song.title] {
            let enhancedSong = SongItem(
                title: song.title,
                artist: song.artist,
                duration: song.duration,
                spotifyID: spotifyID,
                spotifyURL: URL(string: "https://open.spotify.com/track/\(spotifyID)")
            )
            print("✅ Found Spotify song: \(song.title) - ID: \(spotifyID)")
            return enhancedSong
        } else {
            print("⚠️ Could not find Spotify song: \(song.title)")
            return nil
        }
    }
    
    func sharePlaylist() {
        guard !generatedPlaylist.isEmpty else { return }
        
        let playlistText = generatedPlaylist.enumerated().map { (index, song) in
            "\(index + 1). \(song.title) - \(song.artist) (\(song.duration))"
        }.joined(separator: "\n")
        
        let shareText = """
        🎵 My Emolody Playlist - \(lastGenerationMood?.rawValue ?? "Mood") 🎵
        
        \(playlistText)
        
        Generated with Emolody App
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}
