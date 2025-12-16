//
//  MoodDetectionView.swift
//  emolody2
//

import SwiftUI
import AVFoundation

struct MoodDetectionView: View {
    @ObservedObject var camera: CameraService
    var onMoodDetected: (String) -> Void = { _ in }

    @State private var showPermissionAlert = false

    var body: some View {
        ZStack {
            AppScreenBackground()

            VStack(alignment: .leading, spacing: 18) {
                Text("Mood Detection")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.textPrimary)

                Text("Align your face in the frame and tap the button to capture your mood.")
                    .font(.system(size: 16))
                    .foregroundStyle(Brand.textSecondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(.white.opacity(0.15))

                    if camera.isAuthorized {
                        CameraPreviewView(session: camera.session)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Brand.primary)
                            Text("Camera access is required to detect your mood.")
                                .multilineTextAlignment(.center)
                                .font(.system(size: 16))
                                .foregroundColor(Brand.textPrimary)
                        }
                        .padding()
                    }
                }
                .frame(height: 360)

                Text(camera.moodText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)

                if camera.isProcessingShot {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing...")
                            .font(.system(size: 15))
                            .foregroundColor(Brand.textSecondary)
                    }
                }

                Spacer()

                Button {
                    Task {
                        await camera.detectMoodWithAPI()
                        let mood = camera.moodText.isEmpty ? "Happy" : camera.moodText
                        onMoodDetected(mood)
                    }
                } label: {
                    Text("Capture My Mood")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Brand.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .opacity(camera.isProcessingShot ? 0.6 : 1.0)
                }
                .disabled(camera.isProcessingShot)

                Button("Skip for Now") {
                    onMoodDetected("Happy")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.gray)
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            camera.requestAccess { ok in
                if ok {
                    camera.start()
                } else {
                    showPermissionAlert = true
                }
            }
        }
        .onDisappear {
            camera.stop()
        }
        .alert("Camera access is required", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings > Privacy > Camera.")
        }
    }
}
