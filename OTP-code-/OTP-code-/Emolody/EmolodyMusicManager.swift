import MusicKit
import SwiftUI
import Combine
import AuthenticationServices

class EmolodyMusicManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var userPlaylists: [Playlist] = []
    @Published var recentSongs: [Song] = []
    @Published var isLoading = false
    
    // User Info from Sign in with Apple
    @Published var appleUserName: String = ""
    @Published var appleUserEmail: String = ""
    @Published var appleUserID: String = ""
    
    // MARK: - Sign in with Apple
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async -> Bool {
        switch result {
        case .success(let authorization):
            return await handleAuthorizationSuccess(authorization)
        case .failure(let error):
            await handleAuthorizationFailure(error)
            return false
        }
    }
    
    private func handleAuthorizationSuccess(_ authorization: ASAuthorization) async -> Bool {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return false
        }
        
        await MainActor.run {
            // Get user's real name - FIXED: Check if we have real name data
            if let fullName = appleIDCredential.fullName {
                let firstName = fullName.givenName ?? ""
                let lastName = fullName.familyName ?? ""
                let realName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                
                // Only set name if we got real data, otherwise keep existing
                if !realName.isEmpty {
                    self.appleUserName = realName
                    print("✅ Got real Apple user name: \(realName)")
                }
                // If no name provided, don't set "Apple User" - keep existing
            }
            // If no fullName provided, don't change existing name
            
            // Get user's email - FIXED: Only update if we get real email
            if let realEmail = appleIDCredential.email, !realEmail.isEmpty {
                self.appleUserEmail = realEmail
                print("✅ Got real Apple user email: \(realEmail)")
            }
            // If no email provided, don't change existing email
            
            // Always update user ID
            self.appleUserID = appleIDCredential.user
            
            print("✅ Sign in with Apple Success:")
            print("   - Name: \(self.appleUserName)")
            print("   - Email: \(self.appleUserEmail)")
            print("   - User ID: \(self.appleUserID)")
            
            // Save the user data to UserDefaults so it persists
            self.saveAppleUserData()
        }
        
        // Now request Apple Music access
        return await requestAppleMusicAccess()
    }
    
    private func handleAuthorizationFailure(_ error: Error) async {
        await MainActor.run {
            print("❌ Sign in with Apple Failed: \(error.localizedDescription)")
            // Don't clear the data on failure - keep what we have
        }
    }
    
    // MARK: - Apple Music Authorization
    func requestAppleMusicAccess() async -> Bool {
        print("🎵 Requesting Apple Music authorization...")
        
        let status = await MusicAuthorization.request()
        
        await MainActor.run {
            self.isAuthorized = status == .authorized
            
            if self.isAuthorized {
                print("✅ Apple Music Authorized")
                // Load saved user data first
                self.loadAppleUserData()
                // Fetch user's music data
                Task {
                    await self.fetchUserMusicData()
                }
            } else {
                print("❌ Apple Music Not Authorized")
            }
        }
        
        return self.isAuthorized
    }
    
    // MARK: - Save and Load Apple User Data
    private func saveAppleUserData() {
        UserDefaults.standard.set(appleUserName, forKey: "apple_user_name")
        UserDefaults.standard.set(appleUserEmail, forKey: "apple_user_email")
        UserDefaults.standard.set(appleUserID, forKey: "apple_user_id")
        print("💾 Saved Apple user data to UserDefaults")
    }
    
    private func loadAppleUserData() {
        if let savedName = UserDefaults.standard.string(forKey: "apple_user_name"), !savedName.isEmpty {
            self.appleUserName = savedName
        }
        if let savedEmail = UserDefaults.standard.string(forKey: "apple_user_email"), !savedEmail.isEmpty {
            self.appleUserEmail = savedEmail
        }
        if let savedID = UserDefaults.standard.string(forKey: "apple_user_id"), !savedID.isEmpty {
            self.appleUserID = savedID
        }
        print("📱 Loaded Apple user data from UserDefaults:")
        print("   - Name: \(self.appleUserName)")
        print("   - Email: \(self.appleUserEmail)")
    }
    
    // Fetch user's music data after authorization
    private func fetchUserMusicData() async {
        do {
            let playlistRequest = MusicLibraryRequest<Playlist>()
            let playlistResponse = try await playlistRequest.response()
            
            await MainActor.run {
                self.userPlaylists = Array(playlistResponse.items)
                print("🎵 Loaded \(self.userPlaylists.count) playlists from Apple Music")
            }
        } catch {
            print("❌ Failed to fetch Apple Music data: \(error)")
        }
    }
    
    // MARK: - Music Functions
    func fetchUserPlaylists() async throws {
        let request = MusicLibraryRequest<Playlist>()
        let response = try await request.response()
        
        await MainActor.run {
            self.userPlaylists = Array(response.items)
        }
    }
    
    func searchSongsForMood(_ mood: String) async throws -> [Song] {
        let moodKeywords = getKeywordsForMood(mood)
        var allSongs: [Song] = []
        
        for keyword in moodKeywords {
            let request = MusicCatalogSearchRequest(
                term: "\(keyword) \(mood)",
                types: [Song.self]
            )
            let response = try await request.response()
            allSongs.append(contentsOf: Array(response.songs))
        }
        
        return Array(allSongs.prefix(20))
    }
    
    private func getKeywordsForMood(_ mood: String) -> [String] {
        let moodMap: [String: [String]] = [
            "happy": ["upbeat pop", "dance", "summer hits", "joyful"],
            "sad": ["comforting", "acoustic", "emotional", "healing"],
            "angry": ["cathartic rock", "intense", "powerful", "release"],
            "anxious": ["calming", "meditation", "peaceful", "ambient"],
            "tired": ["energy boost", "motivational", "uplifting", "wake up"],
            "relaxed": ["chill", "jazz", "lo-fi", "calm"]
        ]
        return moodMap[mood] ?? ["popular"]
    }
    
    // MARK: - NEW: Complete reset method
    func completeReset() {
        self.isAuthorized = false
        self.userPlaylists = []
        self.recentSongs = []
        self.appleUserName = ""
        self.appleUserEmail = ""
        self.appleUserID = ""
        
        // Clear all saved data
        UserDefaults.standard.removeObject(forKey: "apple_user_name")
        UserDefaults.standard.removeObject(forKey: "apple_user_email")
        UserDefaults.standard.removeObject(forKey: "apple_user_id")
        
        print("🧹 COMPLETE RESET: Cleared all Apple Music data")
    }
}
