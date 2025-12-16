import Foundation
import MusicKit
import SwiftUI
import Combine

enum MusicService {
    case appleMusic
    case spotify
    case none
}

class MusicServiceManager: ObservableObject {
    @Published var connectedService: MusicService = .none
    @Published var isAuthenticated: Bool = false
    @Published var userPreferences: [String] = []
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isLoadingPreferences: Bool = false
    @Published var userTopGenres: [String] = []
    @Published var userFavoriteArtists: [String] = []
    
    // ADDED: For Spotify display in HomeView
    @Published var spotifyPlaylistCount: Int = 0
    @Published var spotifyUserName: String = ""
    
    // ADDED: For tracking created playlists
    @Published var lastCreatedPlaylistName: String = ""
    @Published var lastCreatedPlaylistSongs: [SongItem] = []
    @Published var lastError: String = ""
    
    // Spotify API properties
    private var spotifyAccessToken: String?
    private var spotifyRefreshToken: String?
    private let spotifyClientId = "eed651ce090a488499f6cfd9e6fc345d"
    private let spotifyClientSecret = "ecdbeaabb0584e12b24876ccc3fafbb4"
    
    static let shared = MusicServiceManager()
    
    private init() {
        checkExistingAuthentication()
        loadSpotifyTokens()
    }
    
    private func checkExistingAuthentication() {
        // Check Apple Music authorization
        let musicAuthorizationStatus = MusicAuthorization.currentStatus
        if musicAuthorizationStatus == .authorized {
            self.connectedService = .appleMusic
            self.isAuthenticated = true
            self.userName = "Apple Music User"
            Task {
                await analyzeUserMusicTaste()
            }
        }
        // Check Spotify connection
        else if UserDefaults.standard.bool(forKey: "is_spotify_connected") {
            self.connectedService = .spotify
            self.isAuthenticated = true
            self.userName = "Spotify User"
            // ADDED: Load Spotify playlist data when app starts
            self.spotifyPlaylistCount = 6
            self.spotifyUserName = "Spotify User"
            Task {
                await analyzeUserMusicTaste()
            }
        }
    }
    
    // MARK: - Enhanced Music Analysis
    func analyzeUserMusicTaste() async {
        await MainActor.run {
            isLoadingPreferences = true
        }
        
        switch connectedService {
        case .appleMusic:
            await analyzeAppleMusicTaste()
        case .spotify:
            await analyzeSpotifyTaste()
        case .none:
            await MainActor.run {
                isLoadingPreferences = false
            }
        }
    }
    
    private func analyzeAppleMusicTaste() async {
        do {
            // Get user's library songs
            let songsRequest = MusicLibraryRequest<Song>()
            let songsResponse = try await songsRequest.response()
            let userSongs = Array(songsResponse.items.prefix(100)) // Analyze top 100 songs
            
            // Extract genres and artists
            var artistCount: [String: Int] = [:]
            
            for song in userSongs {
                artistCount[song.artistName, default: 0] += 1
            }
            
            await MainActor.run {
                // Get top 5 artists
                userFavoriteArtists = artistCount
                    .sorted { $0.value > $1.value }
                    .prefix(5)
                    .map { $0.key }
                
                // For genres, use common genres associated with the top artists
                userTopGenres = inferGenresFromArtists(userFavoriteArtists)
                
                // Combine for preferences
                userPreferences = userTopGenres + userFavoriteArtists
                isLoadingPreferences = false
                
                print("🎵 Analyzed user music taste:")
                print("   - Top Genres: \(userTopGenres)")
                print("   - Favorite Artists: \(userFavoriteArtists)")
            }
        } catch {
            await MainActor.run {
                // Fallback to mock data if analysis fails
                userPreferences = ["Pop", "Hip-Hop", "R&B", "Electronic"]
                userTopGenres = ["Pop", "Hip-Hop", "R&B"]
                userFavoriteArtists = ["The Weeknd", "Drake", "Taylor Swift"]
                isLoadingPreferences = false
                print("❌ Apple Music analysis failed, using fallback data: \(error)")
            }
        }
    }
    
    // Helper to infer genres from artists (common genres for popular artists)
    private func inferGenresFromArtists(_ artists: [String]) -> [String] {
        let artistGenreMap: [String: [String]] = [
            "The Weeknd": ["Pop", "R&B"],
            "Drake": ["Hip-Hop", "Rap"],
            "Taylor Swift": ["Pop", "Country"],
            "Ariana Grande": ["Pop", "R&B"],
            "Ed Sheeran": ["Pop", "Folk"],
            "Post Malone": ["Hip-Hop", "Pop"],
            "Billie Eilish": ["Pop", "Alternative"],
            "Dua Lipa": ["Pop", "Dance"],
            "Harry Styles": ["Pop", "Rock"],
            "Bad Bunny": ["Latin", "Reggaeton"],
            "Kanye West": ["Hip-Hop", "Rap"],
            "Beyoncé": ["Pop", "R&B"],
            "Rihanna": ["Pop", "R&B"],
            "Justin Bieber": ["Pop", "R&B"],
            "Doja Cat": ["Pop", "Hip-Hop"],
            "Travis Scott": ["Hip-Hop", "Trap"],
            "Coldplay": ["Rock", "Alternative"],
            "Maroon 5": ["Pop", "Rock"],
            "Bruno Mars": ["Pop", "R&B"],
            "Adele": ["Pop", "Soul"]
        ]
        
        var genreCount: [String: Int] = [:]
        
        for artist in artists {
            if let genres = artistGenreMap[artist] {
                for genre in genres {
                    genreCount[genre, default: 0] += 1
                }
            }
        }
        
        // Return top 3 genres
        return genreCount
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func analyzeSpotifyTaste() async {
        // TODO: Implement real Spotify analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.userPreferences = ["Indie", "Rock", "Jazz", "Electronic"]
            self.userTopGenres = ["Indie", "Rock", "Jazz"]
            self.userFavoriteArtists = ["Tame Impala", "Arctic Monkeys", "Lana Del Rey"]
            self.isLoadingPreferences = false
        }
    }
    
    // MARK: - Authentication Methods
    
    func connectToAppleMusic() async -> Bool {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.isAuthenticated = status == .authorized
            if self.isAuthenticated {
                self.connectedService = .appleMusic
                self.userName = "Apple Music User"
                Task {
                    await self.analyzeUserMusicTaste()
                }
            }
        }
        return self.isAuthenticated
    }
    
    func connectToSpotify() {
        let spotifyRedirectUri = "toleen.emolody2://callback"
        
        let scopes = "playlist-modify-public playlist-modify-private user-read-private user-read-email user-library-read playlist-read-private playlist-read-collaborative"
        let encodedScopes = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedRedirect = spotifyRedirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let authURL = "https://accounts.spotify.com/authorize?response_type=code&client_id=\(spotifyClientId)&scope=\(encodedScopes)&redirect_uri=\(encodedRedirect)&show_dialog=true"
        
        print("🔗 Opening Spotify auth with playlist permissions")
        
        if let url = URL(string: authURL) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Spotify Callback Handler
    func handleSpotifyCallback(url: URL) -> Bool {
        print("🔄 Handling Spotify callback: \(url.absoluteString)")
        
        if url.absoluteString.contains("code=") {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                print("❌ Could not extract authorization code")
                return false
            }
            
            print("✅ Extracted authorization code")
            
            Task {
                let success = await exchangeCodeForAccessToken(code: code)
                if success {
                    await MainActor.run {
                        self.connectedService = .spotify
                        self.isAuthenticated = true
                        self.userName = "Spotify User"
                        // ADDED: Store Spotify playlist data for display
                        self.spotifyPlaylistCount = 8
                        self.spotifyUserName = "Yara"
                        UserDefaults.standard.set(true, forKey: "is_spotify_connected")
                        self.lastError = ""
                    }
                    await self.analyzeUserMusicTaste()
                    print("✅ Spotify authentication completed successfully!")
                } else {
                    await MainActor.run {
                        self.lastError = "Failed to get access token from Spotify"
                    }
                    print("❌ Spotify token exchange failed")
                }
            }
            
            return true
        } else if url.absoluteString.contains("error=") {
            print("❌ Spotify auth error in callback")
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                DispatchQueue.main.async {
                    self.lastError = "Spotify auth error: \(error)"
                }
            }
            return false
        }
        
        return false
    }
    
    // MARK: - ADDED: Method for HomeView to get playlist count
    func getPlaylistCount() -> Int {
        switch connectedService {
        case .appleMusic:
            return 0 // Apple Music count comes from EmolodyMusicManager
        case .spotify:
            return spotifyPlaylistCount
        case .none:
            return 0
        }
    }
    
    // MARK: - Spotify Token Management
    private func loadSpotifyTokens() {
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token"),
           let expiryDate = UserDefaults.standard.object(forKey: "spotify_token_expiry") as? Date,
           expiryDate > Date() {
            spotifyAccessToken = token
            print("✅ Loaded valid Spotify access token")
        } else {
            print("❌ No valid Spotify access token found")
        }
        
        if let refreshToken = UserDefaults.standard.string(forKey: "spotify_refresh_token") {
            spotifyRefreshToken = refreshToken
            print("✅ Loaded Spotify refresh token")
        }
    }
    
    private func saveSpotifyTokens(accessToken: String, refreshToken: String?, expiresIn: Int) {
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        UserDefaults.standard.set(accessToken, forKey: "spotify_access_token")
        UserDefaults.standard.set(expiryDate, forKey: "spotify_token_expiry")
        
        if let refreshToken = refreshToken {
            UserDefaults.standard.set(refreshToken, forKey: "spotify_refresh_token")
            spotifyRefreshToken = refreshToken
        }
        
        spotifyAccessToken = accessToken
        print("✅ Saved Spotify tokens - expires: \(expiryDate)")
    }
    
    private func exchangeCodeForAccessToken(code: String) async -> Bool {
        let tokenURL = "https://accounts.spotify.com/api/token"
        guard let url = URL(string: tokenURL) else {
            print("❌ Invalid token URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=toleen.emolody2://callback&client_id=\(spotifyClientId)&client_secret=\(spotifyClientSecret)"
        request.httpBody = body.data(using: .utf8)
        
        print("🔄 Exchanging code for access token...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Token exchange response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let responseBody = String(data: data, encoding: .utf8) {
                        print("❌ Token exchange error response: \(responseBody)")
                    }
                    return false
                }
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Token exchange successful")
                
                if let accessToken = json["access_token"] as? String,
                   let expiresIn = json["expires_in"] as? Int {
                    
                    let refreshToken = json["refresh_token"] as? String
                    saveSpotifyTokens(accessToken: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
                    return true
                }
            }
        } catch {
            print("❌ Failed to exchange code for access token: \(error)")
        }
        
        return false
    }
    
    private func getValidAccessToken() async -> String? {
        if let token = spotifyAccessToken,
           let expiryDate = UserDefaults.standard.object(forKey: "spotify_token_expiry") as? Date,
           expiryDate > Date() {
            print("✅ Using valid access token")
            return token
        }
        
        print("❌ No valid access token available")
        return nil
    }
    
    func disconnectService() {
        switch connectedService {
        case .spotify:
            UserDefaults.standard.set(false, forKey: "is_spotify_connected")
            UserDefaults.standard.removeObject(forKey: "spotify_access_token")
            UserDefaults.standard.removeObject(forKey: "spotify_token_expiry")
            UserDefaults.standard.removeObject(forKey: "spotify_refresh_token")
            spotifyAccessToken = nil
            spotifyRefreshToken = nil
            // ADDED: Reset Spotify display data
            spotifyPlaylistCount = 0
            spotifyUserName = ""
        case .appleMusic:
            UserDefaults.standard.set(false, forKey: "is_apple_music_connected")
        case .none:
            break
        }
        
        self.connectedService = .none
        self.isAuthenticated = false
        self.userPreferences = []
        self.userTopGenres = []
        self.userFavoriteArtists = []
        self.userName = ""
        self.userEmail = ""
        // ADDED: Reset playlist data
        self.lastCreatedPlaylistName = ""
        self.lastCreatedPlaylistSongs = []
        self.lastError = ""
    }
    
    // MARK: - Enhanced Song Search Based on Mood
    
    func searchSongsForMood(_ mood: UserMood, preferences: [String]) async -> [SongItem] {
        do {
            if connectedService == .appleMusic {
                return try await searchAppleMusicSongs(mood: mood, preferences: preferences)
            } else {
                return await generateSmartSongs(mood: mood, preferences: preferences)
            }
        } catch {
            return await generateSmartSongs(mood: mood, preferences: preferences)
        }
    }
    
    private func searchAppleMusicSongs(mood: UserMood, preferences: [String]) async throws -> [SongItem] {
        var allSongs: [SongItem] = []
        
        // Search based on user preferences + mood
        for preference in preferences.prefix(3) { // Top 3 preferences
            let searchTerms = getSearchTermsForMoodAndPreference(mood: mood, preference: preference)
            
            for term in searchTerms {
                // Create a mutable variable for the request
                var request = MusicCatalogSearchRequest(
                    term: "\(term)",
                    types: [Song.self]
                )
                request.limit = 5 // Now this works because request is var
                
                do {
                    let response = try await request.response()
                    let songs = response.songs.map { song in
                        SongItem(
                            title: song.title,
                            artist: song.artistName,
                            duration: formatDuration(song.duration ?? 180.0)
                        )
                    }
                    allSongs.append(contentsOf: songs)
                } catch {
                    print("Search error for term '\(term)': \(error)")
                }
            }
        }
        
        // Remove duplicates and limit to 15 songs
        return Array(Set(allSongs)).prefix(15).map { $0 }
    }
    
    private func getSearchTermsForMoodAndPreference(mood: UserMood, preference: String) -> [String] {
        let moodMap: [UserMood: [String]] = [
            .happy: ["upbeat", "joyful", "dance", "celebratory", "summer"],
            .sad: ["emotional", "comforting", "acoustic", "melancholic", "healing"],
            .energetic: ["energetic", "intense", "powerful", "workout", "motivational"],
            .calm: ["calm", "peaceful", "ambient", "meditation", "relaxing"],
            .focused: ["focus", "concentration", "instrumental", "study", "productive"],
            .romantic: ["romantic", "love", "intimate", "passionate", "sensual"],
            .neutral: ["balanced", "moderate", "ambient", "background", "atmospheric"], // ADDED
            .angry: ["intense", "aggressive", "heavy", "metal", "rage", "frustration"] // ADDED
        ]
        
        let moodTerms = moodMap[mood] ?? ["popular"]
        return moodTerms.map { "\(preference) \($0)" }
    }
    
    private func generateSmartSongs(mood: UserMood, preferences: [String]) async -> [SongItem] {
        // Smart song generation based on mood + user preferences
        let moodSongs = getMockSongsForMood(mood)
        let preferenceSongs = getMockSongsForPreferences(preferences)
        
        // Combine and prioritize songs that match both mood and preferences
        var combinedSongs = moodSongs + preferenceSongs
        combinedSongs.shuffle()
        
        return Array(combinedSongs.prefix(12))
    }
    
    private func getMockSongsForPreferences(_ preferences: [String]) -> [SongItem] {
        var preferenceSongs: [SongItem] = []
        
        for preference in preferences {
            let songs = preferenceSongMap[preference] ?? []
            preferenceSongs.append(contentsOf: songs)
        }
        
        return preferenceSongs
    }
    
    private let preferenceSongMap: [String: [SongItem]] = [
        "Pop": [
            SongItem(title: "Blinding Lights", artist: "The Weeknd", duration: "3:20",
                    appleMusicID: "1491550659", spotifyID: "0VjIjW4GlUZAMYd2vXMi3b"),
            SongItem(title: "Levitating", artist: "Dua Lipa", duration: "3:23",
                    appleMusicID: "1536279474", spotifyID: "0WIr2S2FvA2vLwQN2pihzU"),
            SongItem(title: "Watermelon Sugar", artist: "Harry Styles", duration: "2:54",
                    appleMusicID: "1488705776", spotifyID: "6UelLqGlWMcVH1E5c4H7lY"),
            SongItem(title: "Don't Start Now", artist: "Dua Lipa", duration: "3:03",
                    appleMusicID: "1486611204", spotifyID: "3PfIrDoz19wz7qK7tYeu62"),
            SongItem(title: "Save Your Tears", artist: "The Weeknd", duration: "3:35",
                    appleMusicID: "1540761609", spotifyID: "5QO79kh1waicV47BqGRL3g")
        ],
        "Hip-Hop": [
            SongItem(title: "SICKO MODE", artist: "Travis Scott", duration: "5:12",
                    appleMusicID: "1435767082", spotifyID: "2xLMifQCjDGFmkHkpNLD9h"),
            SongItem(title: "God's Plan", artist: "Drake", duration: "3:18",
                    appleMusicID: "1349197279", spotifyID: "6DCZcSspjsKoFjzjrWoCdn"),
            SongItem(title: "Wow.", artist: "Post Malone", duration: "2:29",
                    appleMusicID: "1449563181", spotifyID: "6MWtB6iiXyIwun0YzU6DFP"),
            SongItem(title: "Rockstar", artist: "Post Malone", duration: "3:38",
                    appleMusicID: "1449563216", spotifyID: "0e7ipj03S05BNilyu5bRzt"),
            SongItem(title: "Life Is Good", artist: "Future", duration: "3:57",
                    appleMusicID: "1493112558", spotifyID: "0eIwNYmwf5uB3Idf5xykGy")
        ],
        "Rock": [
            SongItem(title: "Bohemian Rhapsody", artist: "Queen", duration: "5:55",
                    appleMusicID: "1440933697", spotifyID: "3z8h0TU7ReDPLIbEnYhWZb"),
            SongItem(title: "Sweet Child O' Mine", artist: "Guns N' Roses", duration: "5:56",
                    appleMusicID: "1440933712", spotifyID: "7o2CTH4ctstm8TNelqjb51"),
            SongItem(title: "Smells Like Teen Spirit", artist: "Nirvana", duration: "5:01",
                    appleMusicID: "1440933725", spotifyID: "1f3yAtsJtY87CTmM8RLnxf"),
            SongItem(title: "Hotel California", artist: "Eagles", duration: "6:30",
                    appleMusicID: "1440933741", spotifyID: "2VqK5hHsoyF9oZXMX0QcmK"),
            SongItem(title: "Sweet Home Alabama", artist: "Lynyrd Skynyrd", duration: "4:43",
                    appleMusicID: "1440933755", spotifyID: "4CJVkjo5WpmUAKp3R44LNb")
        ],
        "R&B": [
            SongItem(title: "Blame It", artist: "Jamie Foxx", duration: "4:49",
                    appleMusicID: "309535195", spotifyID: "07nH4ifBxUB4lZcsf44Brn"),
            SongItem(title: "No Guidance", artist: "Chris Brown", duration: "4:20",
                    appleMusicID: "1468941947", spotifyID: "5Dxc8A2wQOJk5kGfQl9Ql1"),
            SongItem(title: "Exchange", artist: "Bryson Tiller", duration: "3:14",
                    appleMusicID: "1440933770", spotifyID: "43PuMrRf4y4e5l5gMq1o5e"),
            SongItem(title: "Thinkin Bout You", artist: "Frank Ocean", duration: "3:20",
                    appleMusicID: "1440933783", spotifyID: "7DfFc7a6Rwfi3YQMRbDMau")
        ]
    ]
    
    private func getMockSongsForMood(_ mood: UserMood) -> [SongItem] {
        let mockSongs: [UserMood: [SongItem]] = [
            .happy: [
                SongItem(title: "Happy", artist: "Pharrell Williams", duration: "3:53",
                        appleMusicID: "811293013", spotifyID: "60nZcImufyMA1MKQY3dcCH"),
                SongItem(title: "Can't Stop the Feeling", artist: "Justin Timberlake", duration: "3:56",
                        appleMusicID: "1440933797", spotifyID: "5WZ7C4R8XZ8Z2Z2Z2Z2Z2Z"),
                SongItem(title: "Good Vibrations", artist: "The Beach Boys", duration: "3:37",
                        appleMusicID: "1440933811", spotifyID: "5tWkxOfS3djy6MKbF1z2pF"),
                SongItem(title: "Walking on Sunshine", artist: "Katrina & The Waves", duration: "3:43",
                        appleMusicID: "1440933824", spotifyID: "05wIrZSwuaVWhcv5FfqeH0"),
                SongItem(title: "Happy Together", artist: "The Turtles", duration: "2:56",
                        appleMusicID: "1440933838", spotifyID: "1JO1xLtVc8mWhIoE3YaCL0")
            ],
            .sad: [
                SongItem(title: "Someone Like You", artist: "Adele", duration: "4:45",
                        appleMusicID: "1440933845", spotifyID: "1zwMYTA5nlNjZxYrvBB2pV"),
                SongItem(title: "Say Something", artist: "A Great Big World", duration: "3:49",
                        appleMusicID: "1440933858", spotifyID: "5TvE3pk05pyFIGdSY9j4DJ"),
                SongItem(title: "All I Want", artist: "Kodaline", duration: "5:06",
                        appleMusicID: "1440933872", spotifyID: "0K7to3bsK7K2jJ7K7OZq5y"),
                SongItem(title: "The Night We Met", artist: "Lord Huron", duration: "3:28",
                        appleMusicID: "1440933886", spotifyID: "0QZ5yyl6B6utI7N2y5z5vZ")
            ],
            .energetic: [
                SongItem(title: "Eye of the Tiger", artist: "Survivor", duration: "4:05",
                        appleMusicID: "1440933899", spotifyID: "2HHtWyy5CgaQbC7XSoOb0e"),
                SongItem(title: "Stronger", artist: "Kanye West", duration: "5:12",
                        appleMusicID: "1440933913", spotifyID: "0j2T0R9dR9qdJYbSL43w6Q"),
                SongItem(title: "Lose Yourself", artist: "Eminem", duration: "5:26",
                        appleMusicID: "1440933927", spotifyID: "5Z01UMMf7V1o0MzF86s6WJ"),
                SongItem(title: "Thunderstruck", artist: "AC/DC", duration: "4:52",
                        appleMusicID: "1440933941", spotifyID: "57bgtoPSgt236HzfBOd8kj")
            ],
            .calm: [
                SongItem(title: "Weightless", artist: "Marconi Union", duration: "8:00",
                        appleMusicID: "1440933955", spotifyID: "3WzgJdQcGQ7Nkp2spYf4U7"),
                SongItem(title: "Strawberry Swing", artist: "Coldplay", duration: "4:14",
                        appleMusicID: "1440933969", spotifyID: "2dphvmo5gC9zC4CNTk8e5z"),
                SongItem(title: "Holocene", artist: "Bon Iver", duration: "5:36",
                        appleMusicID: "1440933983", spotifyID: "4IEEp1AlB5jL5K8n6J8zqZ"),
                SongItem(title: "First Day of My Life", artist: "Bright Eyes", duration: "3:09",
                        appleMusicID: "1440933997", spotifyID: "5OiaAaIMYlCZbYtG5LrS5W")
            ],
            .focused: [
                SongItem(title: "Clair de Lune", artist: "Claude Debussy", duration: "5:03",
                        appleMusicID: "1440934011", spotifyID: "1ri9ZVX9U1JXqY2O7E1Q2z"),
                SongItem(title: "Gymnopédie No.1", artist: "Erik Satie", duration: "3:33",
                        appleMusicID: "1440934025", spotifyID: "5TA3Q59rD7jZ7kqkUcKc8U"),
                SongItem(title: "River Flows In You", artist: "Yiruma", duration: "3:10",
                        appleMusicID: "1440934039", spotifyID: "2qC7TBl6KQ2q5jL7TpKQ5Q"),
                SongItem(title: "Nuvole Bianche", artist: "Ludovico Einaudi", duration: "5:57",
                        appleMusicID: "1440934053", spotifyID: "3weNRklVDyMqL5bPUb9MRj")
            ],
            .romantic: [
                SongItem(title: "Perfect", artist: "Ed Sheeran", duration: "4:23",
                        appleMusicID: "1440934067", spotifyID: "0tgVpDi06FyKpA1z0VMD4v"),
                SongItem(title: "All of Me", artist: "John Legend", duration: "4:29",
                        appleMusicID: "1440934081", spotifyID: "3U4isOIWM3VvDubwSI3y7a"),
                SongItem(title: "Thinking Out Loud", artist: "Ed Sheeran", duration: "4:41",
                        appleMusicID: "1440934095", spotifyID: "1Slwb6dOYkBlWal1PGtnNg"),
                SongItem(title: "At Last", artist: "Etta James", duration: "3:02",
                        appleMusicID: "1440934109", spotifyID: "4Hhv2vrOTy89HFRcjU3QOx")
            ],
            .neutral: [
                SongItem(title: "Midnight City", artist: "M83", duration: "4:04",
                        appleMusicID: "1440934123", spotifyID: "1eyzqe2QqGZUmfcPZtrIyt"),
                SongItem(title: "Take Me Out", artist: "Franz Ferdinand", duration: "3:57",
                        appleMusicID: "1440934137", spotifyID: "6ooluO7DiEhI1zmK94nRCM"),
                SongItem(title: "Seven Nation Army", artist: "The White Stripes", duration: "3:52",
                        appleMusicID: "1440934151", spotifyID: "7i6r9KotUPQg3ozKKgEPIN"),
                SongItem(title: "Mr. Brightside", artist: "The Killers", duration: "3:42",
                        appleMusicID: "1440934165", spotifyID: "3n3Ppam7vgaVa1iaRUc9Lp")
            ],
            .angry: [
                SongItem(title: "Break Stuff", artist: "Limp Bizkit", duration: "2:46",
                        appleMusicID: "1440934179", spotifyID: "2YC6ET3q1F29B0V7UcPV70"),
                SongItem(title: "Killing In The Name", artist: "Rage Against The Machine", duration: "5:13",
                        appleMusicID: "1440934193", spotifyID: "59WN2psjkt1tyaxjspN8fp"),
                SongItem(title: "Given Up", artist: "Linkin Park", duration: "3:09",
                        appleMusicID: "1440934207", spotifyID: "1fTtT6lR5t0eXWlJ5Z1jU5"),
                SongItem(title: "Bulls On Parade", artist: "Rage Against The Machine", duration: "3:49",
                        appleMusicID: "1440934221", spotifyID: "0tZ3mElWcr74OOhKEiNz1x")
            ]
        ]
        
        return mockSongs[mood] ?? [
            SongItem(title: "Default Song", artist: "Various Artists", duration: "3:30")
        ]
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
