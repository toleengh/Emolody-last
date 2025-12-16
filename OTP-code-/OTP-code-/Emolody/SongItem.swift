import Foundation

struct SongItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: String
    var appleMusicID: String? = nil
    var appleMusicURL: URL? = nil
    var spotifyID: String? = nil      // ADD THIS
    var spotifyURL: URL? = nil        // ADD THIS
    
    init(title: String, artist: String, duration: String,
         appleMusicID: String? = nil, appleMusicURL: URL? = nil,
         spotifyID: String? = nil, spotifyURL: URL? = nil) {  // UPDATE INIT
        self.title = title
        self.artist = artist
        self.duration = duration
        self.appleMusicID = appleMusicID
        self.spotifyID = spotifyID
        
        // Ensure Apple Music URL is properly set
        if let appleMusicID = appleMusicID, appleMusicURL == nil {
            self.appleMusicURL = URL(string: "https://music.apple.com/song/\(appleMusicID)")
        } else {
            self.appleMusicURL = appleMusicURL
        }
        
        // Ensure Spotify URL is properly set
        if let spotifyID = spotifyID, spotifyURL == nil {
            self.spotifyURL = URL(string: "https://open.spotify.com/track/\(spotifyID)")
        } else {
            self.spotifyURL = spotifyURL
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    static func == (lhs: SongItem, rhs: SongItem) -> Bool {
        lhs.id == rhs.id
    }
}
