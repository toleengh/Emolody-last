import SwiftUI
import AuthenticationServices

struct EnterPhoneNumberView: View {
    @State private var sending = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private let spotifyClientId = "eed651ce090a488499f6cfd9e6fc345d"
    private let spotifyRedirectUri = "toleen.emolody2://callback"

    let router: AppRouter
    let musicManager: EmolodyMusicManager
    var onContinue: (String) -> Void

    var body: some View {
        ZStack {

            // الخلفية البنفسجية
            Color(red: 0.96, green: 0.92, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                
                // ⭐ Emolody + الموسيقى — مع lody باللون الأسود
                HStack(spacing: 6) {

                    // Emo — بنفسجي
                    Text("Emo")
                        .foregroundColor(Color(red: 0.48, green: 0.36, blue: 1.0))
                        .font(.system(size: 34, weight: .bold))

                    // lody — أسود
                    Text("lody")
                        .foregroundColor(.black)
                        .font(.system(size: 34, weight: .bold))

                    // الموسيقى — بنفسجي
                    Image(systemName: "music.note")
                        .foregroundColor(Color(red: 0.48, green: 0.36, blue: 1.0))
                        .font(.system(size: 26, weight: .bold))
                }
                .padding(.bottom, 10)

                // Welcome text
                Text("Welcome! Choose your preferred sign-in option.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                // زر Spotify الأخضر
                Button("Continue with Spotify") {
                    openSpotifyLogin()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                .cornerRadius(10)
                .padding(.horizontal)

                // زر Apple
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleSignInWithApple(result)
                }
                .frame(height: 50)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true) // This hides the back button
        .alert("Connection Status", isPresented: $showAlert) {
            Button("Continue") { router.resetTo(.mainTabs()) }
            Button("Stay Here", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpotifyCallback"))) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                handleSpotifyCallback(url: url)
            }
        }
    }

    private func openSpotifyLogin() {
        let scopes = "user-read-private user-read-email"
        let authURL = "https://accounts.spotify.com/authorize?response_type=code&client_id=\(spotifyClientId)&scope=\(scopes)&redirect_uri=\(spotifyRedirectUri)"
        
        if let url = URL(string: authURL) {
            UIApplication.shared.open(url)
        } else {
            alertMessage = "Failed to open Spotify login"
            showAlert = true
        }
    }
    
    private func handleSpotifyCallback(url: URL) {
        print("Spotify callback received: \(url)")
        
        if url.absoluteString.contains("code=") {
            alertMessage = "✅ Spotify connected successfully! Welcome to Emolody."
            UserDefaults.standard.set(true, forKey: "is_spotify_connected")
        } else {
            alertMessage = "❌ Spotify connection failed. Please try again."
        }
        showAlert = true
    }

    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        Task {
            let success = await musicManager.handleSignInWithApple(result)
            
            await MainActor.run {
                alertMessage = success
                    ? "✅ Welcome to Emolody, \(musicManager.appleUserName)!"
                    : "❌ Failed to connect Apple account"
                showAlert = true
            }
        }
    }
}
