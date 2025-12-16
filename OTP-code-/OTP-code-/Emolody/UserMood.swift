// In your UserMood enum file
import Foundation

enum UserMood: String, CaseIterable {
    case happy = "Happy"
    case sad = "Sad"
    case energetic = "Energetic"
    case calm = "Calm"
    case focused = "Focused"
    case romantic = "Romantic"
    case neutral = "Neutral"      // ADDED
    case angry = "Angry"          // ADDED
}
