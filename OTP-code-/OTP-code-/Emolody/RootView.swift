//
//  RootView.swift
//  emolody2
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Routes
enum Route: Hashable {
    case splash
    case enterPhone
    case verifyPhone(number: String)
    case onboardingProfile
    case moodDetection
    case mainTabs(selectedTab: Int = 0)
    case moodResult(mood: String)
    case settings
    case profile
}

// MARK: - Router
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()

    func go(_ r: Route) { path.append(r) }

    func resetTo(_ r: Route) {
        path = NavigationPath()
        path.append(r)
    }

    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeLast(path.count) }
}

// MARK: - RootView
struct RootView: View {
    @StateObject private var router = AppRouter()
    @StateObject private var camera = CameraService()
    @StateObject private var musicManager = EmolodyMusicManager()
    @State private var mainTabInitialTab: Int = 0  // ADD THIS: Store initial tab for MainTabView

    var body: some View {
        NavigationStack(path: $router.path) {
            
            SplashView(onFinished: { router.go(.enterPhone) })
                .navigationDestination(for: Route.self) { route in
                    switch route {

                    case .splash:
                        SplashView(onFinished: { router.go(.enterPhone) })

                    case .enterPhone:
                        EnterPhoneNumberView(
                            router: router,
                            musicManager: musicManager,
                            onContinue: { number in
                                router.go(.verifyPhone(number: number))
                            }
                        )

                    case .verifyPhone(_):
                        Color.clear

                    case .onboardingProfile:
                        OnboardingProfileView(user: UserStore.shared) {
                            router.resetTo(.mainTabs(selectedTab: 0))
                        }

                    case .moodDetection:
                        MoodDetectionView(camera: camera) { detectedMood in
                            let mood = detectedMood.isEmpty ? "Happy" : detectedMood
                            let userStore = UserStore.shared
                            userStore.lastMood = mood
                            userStore.save()

                            UserDefaults.standard.set(
                                Date().timeIntervalSince1970,
                                forKey: "lastMoodTimestamp"
                            )

                            router.go(.moodResult(mood: mood))
                        }
                        .navigationBarTitleDisplayMode(.inline)

                    case .mainTabs(let selectedTab):
                        // Update the stored initial tab
                        MainTabView(
                            user: UserStore.shared,
                            musicManager: musicManager,
                            openPlaylist: { mood in
                                // Update MoodManager with the mood
                                if let userMood = UserMood.allCases.first(where: { $0.rawValue == mood }) {
                                    MoodManager.shared.updateMood(userMood)
                                }
                                // Switch to playlist tab (this will work from HomeView)
                            },
                            startMoodDetection: { router.go(.moodDetection) },
                            openPreferences: { router.go(.onboardingProfile) },
                            logout: {
                                UserStore.shared.clear()
                                router.resetTo(.enterPhone)
                            },
                            initialTab: selectedTab  // Pass the selected tab
                        )
                        .id(selectedTab)  // ADD THIS: Force recreation when tab changes

                    case .moodResult(let mood):
                        MoodResultView(
                            mood: mood,
                            onShowPlaylist: {
                                // Save the mood to MoodManager
                                if let userMood = UserMood.allCases.first(where: { $0.rawValue == mood }) {
                                    MoodManager.shared.updateMood(userMood)
                                }
                                // Save to UserStore
                                let userStore = UserStore.shared
                                userStore.lastMood = mood
                                userStore.save()
                                
                                // Go to main tabs with playlist tab selected (tab 1)
                                router.resetTo(.mainTabs(selectedTab: 1))
                            },
                            onDone: {
                                // Go to main tabs with home tab selected (tab 0)
                                router.resetTo(.mainTabs(selectedTab: 0))
                            }
                        )

                    case .settings:
                        SettingsPlaceholder()

                    case .profile:
                        ProfileView(
                            user: UserStore.shared,
                            musicManager: musicManager,
                            openPreferences: { router.go(.onboardingProfile) },
                            onLogout: {
                                UserStore.shared.clear()
                                router.resetTo(.enterPhone)
                            }
                        )
                    }
                }
        }
    }
}

// MARK: - Settings Placeholder
struct SettingsPlaceholder: View {
    var body: some View {
        ZStack {
            AppScreenBackground()
            VStack(spacing: 16) {
                Text("Settings")
                    .font(.title2.bold())
                    .foregroundStyle(Brand.textPrimary)

                Button {
                    // Settings action
                } label: {
                    Text("Edit preferences")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Brand.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
