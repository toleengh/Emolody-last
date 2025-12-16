//
//  MoodResultView.swift
//  Emolody
//

import SwiftUI

struct MoodResultView: View {
    let mood: String
    var onShowPlaylist: () -> Void
    var onDone: () -> Void
    
    @StateObject private var moodManager = MoodManager.shared

    var body: some View {
        ZStack {
            AppScreenBackground()

            VStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mood Detection")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.textPrimary)

                    Text("We detected your mood!")
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 120, height: 120)

                        // Dynamic emoji based on mood
                        Text(getMoodEmoji())
                            .font(.system(size: 56))
                    }

                    VStack(spacing: 6) {
                        Text("You are feeling")
                            .font(.system(size: 18))
                            .foregroundStyle(Brand.textPrimary)

                        Text(mood)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Brand.textPrimary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        // Save the detected mood first
                        saveDetectedMood()
                        // Then trigger the playlist navigation
                        onShowPlaylist()
                    } label: {
                        Text("Show Suggested Playlist")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Brand.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(radius: 8, y: 4)
                    }
                    .padding(.horizontal, 40)

                    Button {
                        // Save mood before going back to home
                        saveDetectedMood()
                        onDone()
                    } label: {
                        Text("Back to Home")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Brand.textSecondary)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Save mood when view appears
            saveDetectedMood()
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveDetectedMood() {
        // Convert string mood to UserMood enum
        if let userMood = convertStringToMood(mood) {
            moodManager.updateMood(userMood)
            
            // Save to UserStore for HomeView
            let userStore = UserStore.shared
            userStore.lastMood = mood
            userStore.saveLastMoodTimestamp()
            userStore.save()
        }
    }
    
    private func convertStringToMood(_ moodString: String) -> UserMood? {
        // Try to match the mood string to our enum cases
        let lowercasedMood = moodString.lowercased()
        
        for moodCase in UserMood.allCases {
            if moodCase.rawValue.lowercased() == lowercasedMood {
                return moodCase
            }
        }
        
        // Handle variations or similar mood names
        switch lowercasedMood {
        case "joyful", "excited", "content", "good", "positive":
            return .happy
        case "depressed", "melancholy", "unhappy", "gloomy":
            return .sad
        case "energized", "active", "lively":
            return .energetic
        case "relaxed", "peaceful", "serene":
            return .calm
        case "concentrated", "attentive", "alert":
            return .focused
        case "loving", "affectionate", "passionate":
            return .romantic
        case "mad", "furious", "irritated", "annoyed":
            return .angry
        case "neutral", "normal", "okay", "fine":
            return .neutral
        default:
            return .neutral  // Default for any unrecognized mood
        }
    }
    
    private func getMoodEmoji() -> String {
        let lowercasedMood = mood.lowercased()
        
        switch lowercasedMood {
        case "happy", "joyful", "excited":
            return "😊"
        case "sad", "depressed", "melancholy":
            return "😢"
        case "energetic", "active", "lively":
            return "⚡"
        case "calm", "relaxed", "peaceful":
            return "🌊"
        case "focused", "concentrated":
            return "🎯"
        case "romantic", "loving":
            return "❤️"
        case "neutral", "normal", "okay":
            return "😐"
        case "angry", "mad", "furious":
            return "😠"
        default:
            return "😊"
        }
    }
}

#Preview {
    MoodResultView(
        mood: "Happy",
        onShowPlaylist: {},
        onDone: {}
    )
}
