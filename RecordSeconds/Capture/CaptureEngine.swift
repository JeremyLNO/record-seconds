import Foundation
import AVFoundation
import Combine

/// Thin AVFoundation wrapper: configures a capture session for the back camera + mic,
/// and records fixed-duration clips via `AVCaptureMovieFileOutput.maxRecordedDuration`
/// (no manual stop timer needed). No camera exists in the Simulator — callers should
/// check `cameraAvailable` and fall back to importing a video from Photos.
///
/// Session configuration and recording run on a private queue (Apple's recommended
/// pattern); `@Published` properties are always updated back on the main queue.
final class CaptureEngine: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var cameraAvailable = true
    @Published var permissionDenied = false

    /// 0...1 progress through the current fixed-duration recording, for the on-screen
    /// recording indicator.
    @Published var recordingProgress: Double = 0

    private let movieOutput = AVCaptureMovieFileOutput()
    private var completion: ((URL?) -> Void)?
    private let queue = DispatchQueue(label: "company.lno.videoonesec.capture")
    private var progressTimer: Timer?
    private var recordingStartedAt: Date?
    private var recordingDuration: TimeInterval = 1

    func configureIfNeeded(quality: VideoQuality) {
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraAvailable = false
            return
        }
        Task {
            let videoOK = await requestAccess(for: .video)
            guard videoOK else {
                await MainActor.run { self.permissionDenied = true }
                return
            }
            let audioOK = await requestAccess(for: .audio)
            queue.async { [weak self] in
                self?.buildSession(quality: quality, includeAudio: audioOK)
            }
        }
    }

    private func requestAccess(for type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        default: return false
        }
    }

    /// Runs on `queue`.
    private func buildSession(quality: VideoQuality, includeAudio: Bool) {
        session.beginConfiguration()
        session.sessionPreset = quality.preset
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        if includeAudio, let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
            session.addInput(micInput)
        }
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        session.commitConfiguration()
        session.startRunning()
        DispatchQueue.main.async { self.isSessionRunning = true }
    }

    func stopSession() {
        queue.async { [weak self] in self?.session.stopRunning() }
    }

    func record(duration: TimeInterval, completion: @escaping (URL?) -> Void) {
        guard !isRecording else { return }
        self.completion = completion
        recordingDuration = duration
        movieOutput.maxRecordedDuration = CMTime(seconds: duration, preferredTimescale: 600)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        isRecording = true
        recordingProgress = 0
        recordingStartedAt = Date()
        startProgressTimer()
        queue.async { [weak self] in
            guard let self else { return }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let started = self.recordingStartedAt else { return }
            let elapsed = Date().timeIntervalSince(started)
            self.recordingProgress = min(1, elapsed / self.recordingDuration)
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        recordingStartedAt = nil
    }
}

extension CaptureEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Hitting `maxRecordedDuration` reports a non-nil error (AVError.maximumDurationReached)
        // even though the file is complete and usable — that's the normal end of every
        // fixed-duration clip here. AVFoundation flags a genuinely usable recording with
        // AVErrorRecordingSuccessfullyFinishedKey, so treating any error as failure would
        // silently discard every clip we record.
        var usable = true
        if let error = error as NSError? {
            usable = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        }
        DispatchQueue.main.async {
            self.stopProgressTimer()
            self.isRecording = false
            self.recordingProgress = 0
            self.completion?(usable ? outputFileURL : nil)
            self.completion = nil
        }
    }
}
