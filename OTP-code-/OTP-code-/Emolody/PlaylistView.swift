import SwiftUI
import MusicKit

struct PlaylistView: View {
    @StateObject private var moodManager = MoodManager.shared
    @StateObject private var musicServiceManager = MusicServiceManager.shared
    @StateObject private var playlistGenerator = PlaylistGenerator()
    
    @State private var showingServiceSelection = false
    @State private var showingMoodSelection = false
    @State private var isGenerating = false
    
    // Define the purple color
    private let purpleColor = Color(hex: "8167EC")
    private let darkTextColor = Color(red: 0.15, green: 0.05, blue: 0.25)
    
    // ✅ Beige like Home
    private let beigeBackground = Color(hex: "F3EEF9")
    
    var body: some View {
        NavigationView{
            ZStack {
                
                AppScreenBackground()
                
                VStack(spacing: 0) {
                    // Header with "Your Playlist" title
                    VStack(spacing: 8) {
                        Text("Your Playlist")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(darkTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                    // ✅ header background beige
                    .background(beigeBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header with mood
                            moodHeaderCard
                            
                            // Music Service Status
                            serviceStatusCard
                            
                            // Generate Button
                            generateButtonCard
                            
                            // Playlist Content
                            if !playlistGenerator.generatedPlaylist.isEmpty {
                                playlistContentCard
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)// Hide the default navigation bar
        .sheet(isPresented: $showingServiceSelection) {
            ServiceSelectionView()
        }
        .sheet(isPresented: $showingMoodSelection) {
            MoodSelectionView()
        }
    }
    
    // MARK: - Beautiful Card Components
    
    private var moodHeaderCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mood Playlist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(darkTextColor)
                    
                    Text("You are feeling:")
                        .font(.subheadline)
                        .foregroundColor(darkTextColor.opacity(0.7))
                    
                    HStack {
                        Image(systemName: getMoodIcon())
                            .font(.title2)
                            .foregroundColor(getMoodColor())
                        
                        Text(moodManager.currentMood.rawValue)
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundColor(getMoodColor())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingMoodSelection = true
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(purpleColor)
                        .padding(12)
                        .background(purpleColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // ✅ card background beige instead of white
                .fill(beigeBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(purpleColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var serviceStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: getServiceIcon())
                    .font(.title2)
                    .foregroundColor(getServiceColor())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getServiceStatusText())
                        .font(.headline)
                        .foregroundColor(darkTextColor)
                    
                    if !musicServiceManager.userName.isEmpty {
                        Text(musicServiceManager.userName)
                            .font(.subheadline)
                            .foregroundColor(darkTextColor.opacity(0.7))
                    }
                }
                
                Spacer()
                
            }
            
            if musicServiceManager.isAuthenticated {
                if musicServiceManager.isLoadingPreferences {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: purpleColor))
                        Text("Loading your music preferences...")
                            .font(.caption)
                            .foregroundColor(darkTextColor.opacity(0.7))
                    }
                } else if !musicServiceManager.userPreferences.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Music Preferences:")
                            .font(.caption)
                            .foregroundColor(darkTextColor.opacity(0.7))
                        
                        FlexibleTagView(tags: musicServiceManager.userPreferences)
                    }
                }
            } else {
                Text("Connect a music service to generate personalized playlists")
                    .font(.caption)
                    .foregroundColor(darkTextColor.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // ✅ card background beige instead of white
                .fill(beigeBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(purpleColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var generateButtonCard: some View {
        Button(action: {
            Task {
                isGenerating = true
                await playlistGenerator.generatePlaylist(for: moodManager.currentMood)
                isGenerating = false
            }
        }) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Text(playlistGenerator.generatedPlaylist.isEmpty ? "Generate Mood Playlist" : "Regenerate Playlist")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(purpleColor)
            .cornerRadius(16)
            .shadow(color: purpleColor.opacity(0.4), radius: 10, y: 5)
        }
        .disabled(isGenerating || !musicServiceManager.isAuthenticated)
        .opacity(musicServiceManager.isAuthenticated ? 1.0 : 0.6)
    }
    
    private var playlistContentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Your Generated Playlist")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(darkTextColor)
                
                Spacer()
                
                Button(action: playlistGenerator.sharePlaylist) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(purpleColor)
                        .padding(8)
                        .background(purpleColor.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // Instruction header
            if musicServiceManager.connectedService != .none {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(getServiceColor())
                        .font(.caption)
                    
                    Text("Tap the play button next to any song to open it in \(getServiceName())")
                        .font(.caption)
                        .foregroundColor(darkTextColor.opacity(0.7))
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(purpleColor.opacity(0.05))
                .cornerRadius(8)
            }
            
            LazyVStack(spacing: 10) {
                ForEach(Array(playlistGenerator.generatedPlaylist.enumerated()), id: \.element.id) { index, song in
                    SongRow(
                        song: song,
                        index: index + 1,
                        musicService: musicServiceManager.connectedService,
                        purpleColor: purpleColor,
                        darkTextColor: darkTextColor
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // ✅ card background beige instead of white
                .fill(beigeBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(purpleColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func getMoodIcon() -> String {
        switch moodManager.currentMood {
        case .happy: return "face.smiling"
        case .sad: return "face.dashed"
        case .energetic: return "bolt.heart"
        case .calm: return "leaf"
        case .focused: return "brain.head.profile"
        case .romantic: return "heart"
        case .neutral: return "face.smiling.inverse"
        case .angry: return "flame"
        }
    }
    
    private func getMoodColor() -> Color {
        switch moodManager.currentMood {
        case .happy: return .yellow
        case .sad: return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .energetic: return .orange
        case .calm: return Color(red: 0.4, green: 0.8, blue: 0.4)
        case .focused: return purpleColor
        case .romantic: return Color(red: 1.0, green: 0.4, blue: 0.6)
        case .neutral: return .gray
        case .angry: return .red
        }
    }
    
    private func getServiceIcon() -> String {
        switch musicServiceManager.connectedService {
        case .appleMusic: return "applelogo"
        case .spotify: return "music.note"
        case .none: return "music.note"
        }
    }
    
    private func getServiceColor() -> Color {
        switch musicServiceManager.connectedService {
        case .appleMusic: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .spotify: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .none: return .gray
        }
    }
    
    private func getServiceStatusText() -> String {
        if musicServiceManager.isAuthenticated {
            switch musicServiceManager.connectedService {
            case .appleMusic: return "Connected to Apple Music"
            case .spotify: return "Connected to Spotify"
            case .none: return "Not Connected"
            }
        } else {
            return "Connect to Music Service"
        }
    }
    
    private func getServiceName() -> String {
        switch musicServiceManager.connectedService {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .none: return "Music Service"
        }
    }
}

// MARK: - Beautiful Song Row
struct SongRow: View {
    let song: SongItem
    let index: Int
    let musicService: MusicService
    let purpleColor: Color
    let darkTextColor: Color
    @State private var isOpening = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Track number
            Text("\(index)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(darkTextColor.opacity(0.6))
                .frame(width: 20)
            
            // Song info
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(darkTextColor)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(darkTextColor.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration and Play button
            HStack(spacing: 12) {
                Text(song.duration)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(darkTextColor.opacity(0.6))
                
                // Play button based on service
                if hasServiceURL() {
                    Button(action: {
                        playSongInService()
                    }) {
                        if isOpening {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: getServiceColor()))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(getServiceColor())
                        }
                    }
                    .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(purpleColor.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func hasServiceURL() -> Bool {
        switch musicService {
        case .appleMusic:
            return song.appleMusicURL != nil
        case .spotify:
            return song.spotifyURL != nil
        case .none:
            return false
        }
    }
    
    private func getServiceColor() -> Color {
        switch musicService {
        case .appleMusic:
            return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .spotify:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .none:
            return .gray
        }
    }
    
    private func playSongInService() {
        let url: URL?
        
        switch musicService {
        case .appleMusic:
            url = song.appleMusicURL
        case .spotify:
            url = song.spotifyURL
        case .none:
            return
        }
        
        guard let serviceURL = url else { return }
        
        isOpening = true
        
        Task {
            // Small delay to show loading state
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                if UIApplication.shared.canOpenURL(serviceURL) {
                    UIApplication.shared.open(serviceURL) { success in
                        isOpening = false
                        if success {
                            print("✅ Opened song in \(musicService == .appleMusic ? "Apple Music" : "Spotify"): \(song.title)")
                        } else {
                            print("❌ Failed to open \(musicService == .appleMusic ? "Apple Music" : "Spotify")")
                        }
                    }
                } else {
                    // Fallback: Open the service app
                    let fallbackURL: URL?
                    switch musicService {
                    case .appleMusic:
                        fallbackURL = URL(string: "music://")
                    case .spotify:
                        fallbackURL = URL(string: "spotify://")
                    case .none:
                        fallbackURL = nil
                    }
                    
                    if let fallback = fallbackURL {
                        UIApplication.shared.open(fallback) { _ in
                            isOpening = false
                        }
                    } else {
                        isOpening = false
                    }
                }
            }
        }
    }
}

struct FlexibleTagView: View {
    let tags: [String]
    private let purpleColor = Color(hex: "8167EC")
    
    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(purpleColor.opacity(0.1))
                    .foregroundColor(purpleColor)
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
