import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Full-screen capture flow: live camera, one-tap fixed-duration recording, a
/// confirm/retake step, then save into `project`. The Simulator has no camera, so
/// `cameraAvailable == false` swaps in a "import a video from Photos" fallback that
/// trims the picked video to the configured duration — this keeps the whole capture
/// flow testable without a physical device.
struct CameraCaptureView: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = CaptureEngine()
    @ObservedObject private var settings = AppSettings.shared

    @State private var reviewURL: URL?
    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let reviewURL {
                reviewStep(url: reviewURL)
            } else if engine.cameraAvailable {
                liveCaptureStep
            } else {
                simulatorFallbackStep
            }

            VStack {
                HStack {
                    Button {
                        engine.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: Circle())
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear { engine.configureIfNeeded(quality: settings.videoQuality) }
        .onDisappear { engine.stopSession() }
        .task(id: pickerItem) { await handlePickerSelection() }
    }

    // MARK: - Live camera

    private var liveCaptureStep: some View {
        ZStack {
            CameraPreviewView(session: engine.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button {
                    engine.record(duration: settings.clipDuration) { url in
                        reviewURL = url
                    }
                } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                        Circle()
                            .fill(engine.isRecording ? .red : .white)
                            .frame(width: engine.isRecording ? 34 : 62, height: engine.isRecording ? 34 : 62)
                            .animation(.easeInOut(duration: 0.15), value: engine.isRecording)
                    }
                }
                .disabled(engine.isRecording || !engine.isSessionRunning)
                .padding(.bottom, 48)
            }

            if engine.permissionDenied {
                permissionDeniedOverlay
            }
        }
    }

    private var permissionDeniedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill").font(.system(size: 40)).foregroundStyle(.white)
            Text(L.t("capture_permission_denied"))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Review / retake

    private func reviewStep(url: URL) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ClipPlayerView(url: url)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .cornerRadius(16)
                .padding(.horizontal, 24)
            Spacer()
            HStack(spacing: 32) {
                Button {
                    try? FileManager.default.removeItem(at: url)
                    reviewURL = nil
                } label: {
                    Label(L.t("capture_retake"), systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.white)
                }
                Button {
                    saveClip(from: url)
                } label: {
                    Label(L.t("capture_use_clip"), systemImage: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Simulator fallback

    private var simulatorFallbackStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.white)
            Text(L.t("capture_simulator_no_camera"))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            PhotosPicker(selection: $pickerItem, matching: .videos) {
                Label(L.t("capture_import_from_photos"), systemImage: "photo.on.rectangle")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            if isImporting {
                ProgressView().tint(.white)
            }
            if let importError {
                Text(importError).foregroundStyle(.red).font(.caption)
            }
        }
    }

    private func handlePickerSelection() async {
        guard let pickerItem else { return }
        isImporting = true
        importError = nil
        defer { isImporting = false }
        do {
            guard let movie = try await pickerItem.loadTransferable(type: TransferableMovie.self) else { return }
            let trimmed = try await VideoTrimmer.trim(sourceURL: movie.url, to: settings.clipDuration)
            reviewURL = trimmed
        } catch {
            importError = error.localizedDescription
        }
        self.pickerItem = nil
    }

    // MARK: - Save

    private func saveClip(from url: URL) {
        do {
            try VideoStore.saveCapturedClip(from: url, into: project, duration: settings.clipDuration, modelContext: modelContext)
            engine.stopSession()
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }
}

/// Wraps a picked Photos video as a file `Transferable`, copying it to a temp URL we
/// own (the system-provided URL is only valid for the duration of the callback).
struct TransferableMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}
