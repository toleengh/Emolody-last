//
//  CameraService.swift
//  emolody2
//

import SwiftUI
import AVFoundation
import CoreImage
import UIKit
import Combine

@MainActor
final class CameraService: NSObject, ObservableObject {

    // MARK: - Published (UI state)
    @Published var session = AVCaptureSession()
    @Published var isRunning = false
    @Published var moodText: String = "Your mood will appear here"
    @Published var isAuthorized: Bool = false
    @Published var isProcessingShot: Bool = false   // أثناء استدعاء الـ API

    // MARK: - Queues
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    nonisolated let videoQueue = DispatchQueue(label: "camera.video.queue")

    // MARK: - Devices & IO
    private var deviceInput: AVCaptureDeviceInput?
    private var frontCamera: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()

    // آخر فريم من الكاميرا – بنستخدمه لما يضغط الزر
    nonisolated(unsafe) private var lastSampleBuffer: CMSampleBuffer?

    // لتحويل الـ PixelBuffer إلى صورة
    private let ciContext = CIContext()

    // ✅ API Key from Info.plist
    private var openAIAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.hasPrefix("YOUR_") else {
            fatalError("❌ OPENAI_API_KEY is missing/empty in Info.plist")
        }
        return key
    }

    // MARK: - Init
    override init() {
        super.init()
        // تجهيز الكاميرا
        sessionQueue.async { [weak self] in
            Task { await self?.configureSession() }
        }

        // حالة التفويض الحالية
        isAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    // MARK: - Public control
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor in self.isRunning = true }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in self.isRunning = false }
            }
        }
    }

    // MARK: - Configure
    private func configureSession() async {
        session.beginConfiguration()
        session.sessionPreset = .high

        // كاميرا أمامية (لو TrueDepth موجودة خذيها، وإلا واسع الزاوية)
        if let cam = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = cam
        }

        guard let camera = frontCamera,
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        deviceInput = input

        // Video output
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // توجيه
        if let conn = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if conn.isVideoRotationAngleSupported(0) { conn.videoRotationAngle = 0 }
            } else {
                conn.videoOrientation = .portrait
            }
        }

        // Delegate على كيو خلفي
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)

        session.commitConfiguration()
    }
}

// MARK: - Permission
extension CameraService {
    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    self.isAuthorized = ok
                    completion(ok)
                }
            }
        case .denied, .restricted:
            isAuthorized = false
            completion(false)
        @unknown default:
            isAuthorized = false
            completion(false)
        }
    }
}

// MARK: - OpenAI Vision (Chat Completions)
extension CameraService {

    /// تُستدعى من زر "Capture My Mood"
    /// ترسل آخر فريم للـ OpenAI وتحدّث `moodText` بكلمة واحدة
    func detectMoodWithAPI() async {
        isProcessingShot = true
        moodText = "Detecting your mood..."

        // نتأكد إن عندنا فريم من الكاميرا
        guard let sampleBuffer = lastSampleBuffer,
              let imageData = jpegData(from: sampleBuffer) else {
            isProcessingShot = false
            moodText = "Please face the camera and try again."
            return
        }

        // نحول الصورة إلى base64
        let base64Image = imageData.base64EncodedString()

        let userPrompt = """
        Look at this person's face and return ONLY ONE WORD that best describes their emotion.
        Answer with exactly one of these words (English, capitalized): Happy, Sad, Angry, Neutral, Calm, Excited, Tired, Stressed.
        Do not write anything else.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an emotion classifier for faces. You always answer with exactly one word from a fixed list of emotions."
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userPrompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 20
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            isProcessingShot = false
            moodText = "Failed to build request."
            return
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            isProcessingShot = false
            moodText = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ✅ Here the key comes from Info.plist
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("OpenAI error: \(http.statusCode) – \(bodyString)")
                isProcessingShot = false
                moodText = "Failed to detect mood."
                return
            }

            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let rawContent = decoded.choices.first?.message.content ?? "Happy"
            let firstWord = Self.extractFirstWord(from: rawContent)

            moodText = firstWord.isEmpty ? "Happy" : firstWord
            isProcessingShot = false

        } catch {
            print("OpenAI request error:", error)
            isProcessingShot = false
            moodText = "Error detecting mood."
        }
    }

    // تحويل sampleBuffer → JPEG Data
    private func jpegData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }

    // استخراج أول كلمة نظيفة من الرد
    private static func extractFirstWord(from text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let components = cleaned.components(
            separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        )

        return components.first(where: { !$0.isEmpty }) ?? ""
    }
}

// MARK: - Response Models
private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - Delegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// نحفظ آخر فريم فقط، بدون تحليل
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        lastSampleBuffer = sampleBuffer
    }
}
