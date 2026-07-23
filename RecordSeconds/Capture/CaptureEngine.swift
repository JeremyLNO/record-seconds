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

    private let movieOutput = AVCaptureMovieFileOutput()
    private var completion: ((URL?) -> Void)?
    private let queue = DispatchQueue(label: "company.lno.recordseconds.capture")

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
        movieOutput.maxRecordedDuration = CMTime(seconds: duration, preferredTimescale: 600)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        isRecording = true
        queue.async { [weak self] in
            guard let self else { return }
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }
}

extension CaptureEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.completion?(error == nil ? outputFileURL : nil)
            self.completion = nil
        }
    }
}
