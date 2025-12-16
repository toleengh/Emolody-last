import SwiftUI

struct ProfileView: View {
    @ObservedObject var user: UserStore
    var musicManager: EmolodyMusicManager?
    @EnvironmentObject private var musicServiceManager: MusicServiceManager

    var openPreferences: () -> Void = {}
    var onLogout: () -> Void = {}

    var body: some View {
        NavigationView {
            ZStack {
                AppScreenBackground()

                ScrollView {
                    VStack(spacing: 16) {

                        // USER CARD
                        AppCard {
                            HStack(spacing: 12) {

                                if let musicManager = musicManager, musicManager.isAuthorized {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.blue, .purple]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 70, height: 70)

                                        Image(systemName: "person.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }

                                } else if musicServiceManager.connectedService == .spotify {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.green, .green.opacity(0.7)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 70, height: 70)

                                        Image(systemName: "music.note")
                                            .font(.system(size: 30))
                                            .foregroundColor(.white)
                                    }

                                } else {
                                    Circle()
                                        .fill(Brand.primary.opacity(0.2))
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 32))
                                                .foregroundColor(Brand.primary)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(getUserName())
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(Brand.textPrimary)

                                    if let musicManager = musicManager,
                                       musicManager.isAuthorized,
                                       !musicManager.appleUserEmail.isEmpty {
                                        Text(musicManager.appleUserEmail)
                                            .font(.subheadline)
                                            .foregroundColor(Brand.textSecondary)

                                    } else if musicServiceManager.connectedService == .spotify {
                                        Text("Spotify User")
                                            .font(.subheadline)
                                            .foregroundColor(Brand.textSecondary)

                                    } else {
                                        Text(user.phone.isEmpty ? "—" : user.phone)
                                            .font(.subheadline)
                                            .foregroundColor(Brand.textSecondary)
                                    }

                                    if let musicManager = musicManager, musicManager.isAuthorized {
                                        HStack {
                                            Image(systemName: "applelogo")
                                            Text("Apple ID Account")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(12)

                                    } else if musicServiceManager.connectedService == .spotify {
                                        HStack {
                                            Image(systemName: "music.note")
                                            Text("Spotify Account")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.green)
                                        .cornerRadius(12)
                                    }
                                }

                                Spacer()
                            }
                        }

                        // Preferences
                        Button(action: openPreferences) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(Brand.primary)
                                Text("Music & Podcast Preferences")
                                    .font(.headline)
                                    .foregroundColor(Brand.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Brand.textSecondary)
                            }
                        }
                        .appCard()

                        // Connected Accounts
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connected Accounts")
                                .font(.headline)
                                .foregroundColor(Brand.textPrimary)
                                .padding(.horizontal)

                            AppCard {
                                HStack {
                                    Image("spotify")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)

                                    Text("Spotify")
                                        .font(.headline)
                                        .foregroundColor(Brand.textPrimary)

                                    Spacer()

                                    Toggle(
                                        "",
                                        isOn: .constant(musicServiceManager.connectedService == .spotify)
                                    )
                                    .labelsHidden()
                                    .disabled(true)
                                    .tint(.green)
                                }
                            }

                            AppCard {
                                HStack {
                                    Image(systemName: "applelogo")
                                        .foregroundColor(.red)

                                    Text("Apple Music")
                                        .font(.headline)
                                        .foregroundColor(Brand.textPrimary)

                                    Spacer()

                                    Toggle(
                                        "",
                                        isOn: .constant(musicManager?.isAuthorized ?? false)
                                    )
                                    .labelsHidden()
                                    .disabled(true)
                                    .tint(.red)
                                }
                            }

                            // Apple Account Details (STATUS ONLY)
                            if let musicManager = musicManager, musicManager.isAuthorized {
                                AppCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Apple Account Details")
                                            .font(.headline)
                                            .foregroundColor(Brand.textPrimary)

                                        HStack {
                                            Text("Status:")
                                                .foregroundColor(Brand.textSecondary)

                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                Text("Connected")
                                            }
                                            .foregroundColor(.green)

                                            Spacer()
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }

                            // Spotify Account Details
                            if musicServiceManager.connectedService == .spotify {
                                AppCard {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Spotify Account Details")
                                            .font(.headline)
                                            .foregroundColor(Brand.textPrimary)

                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Name:")
                                                Text(
                                                    musicServiceManager.spotifyUserName.isEmpty
                                                    ? "Spotify User"
                                                    : musicServiceManager.spotifyUserName
                                                )
                                                .bold()
                                                Spacer()
                                            }

                                            HStack {
                                                Text("Playlists:")
                                                Text("\(musicServiceManager.spotifyPlaylistCount) playlists")
                                                Spacer()
                                            }

                                            HStack {
                                                Text("Status:")
                                                HStack {
                                                    Image(systemName: "checkmark.circle.fill")
                                                    Text("Connected")
                                                }
                                                .foregroundColor(.green)
                                                Spacer()
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(Brand.textSecondary)
                                    }
                                }
                            }
                        }

                        // Logout
                        Button(role: .destructive, action: onLogout) {
                            HStack {
                                Image(systemName: "arrow.right.square.fill")
                                Text("Logout")
                                Spacer()
                            }
                        }
                        .appCard()
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func getUserName() -> String {
        if let musicManager = musicManager,
           musicManager.isAuthorized,
           !musicManager.appleUserName.isEmpty {
            return musicManager.appleUserName
        } else if musicServiceManager.connectedService == .spotify,
                  !musicServiceManager.spotifyUserName.isEmpty {
            return musicServiceManager.spotifyUserName
        } else if !user.name.isEmpty {
            return user.name
        } else {
            return "User"
        }
    }
}
