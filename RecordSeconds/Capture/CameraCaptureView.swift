import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

/// Full-screen capture flow: live camera, one-tap fixed-duration recording, then the
/// clip is saved straight into `project` and the screen closes — filming a clip always
/// lands you back in the app. The Simulator has no camera, so `cameraAvailable == false`
/// swaps in a "import a video from Photos" fallback that trims the picked video to the
/// configured duration — this keeps the whole capture flow testable without a device.
struct CameraCaptureView: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = CaptureEngine()
    @ObservedObject private var settings = AppSettings.shared

    @State private var pickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importError: String?
    @State private var justSaved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.cameraAvailable {
                liveCaptureStep
            } else {
                simulatorFallbackStep
            }

            if justSaved { savedConfirmation }

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
                    if engine.isRecording { recordingBadge }
                    Spacer()
                    // Balances the close button so the REC badge stays centered.
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding()
                Spacer()
            }
        }
        .onAppear { engine.configureIfNeeded(quality: settings.videoQuality) }
        .onDisappear { engine.stopSession() }
        .task(id: pickerItem) { await handlePickerSelection() }
    }

    // MARK: - Recording indicator

    /// Pulsing "REC" pill shown at the top while filming.
    private var recordingBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
                .opacity(engine.isRecording ? 1 : 0.2)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: engine.isRecording)
            Text(L.t("capture_recording"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.black.opacity(0.55), in: Capsule())
        .transition(.opacity)
    }

    private var savedConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white)
            Text(L.t("capture_clip_saved"))
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(28)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.opacity)
    }

    // MARK: - Live camera

    private var liveCaptureStep: some View {
        ZStack {
            CameraPreviewView(session: engine.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.bottom, 12)
                }
                Button {
                    engine.record(duration: settings.clipDuration) { url in
                        guard let url else {
                            importError = L.t("capture_error_recording")
                            return
                        }
                        saveClip(from: url)
                    }
                } label: {
                    ZStack {
                        // Ring fills up as the fixed-duration recording elapses.
                        Circle().stroke(.white.opacity(0.45), lineWidth: 4).frame(width: 76, height: 76)
                        Circle()
                            .trim(from: 0, to: engine.recordingProgress)
                            .stroke(.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 76, height: 76)
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
            saveClip(from: trimmed)
        } catch {
            importError = error.localizedDescription
        }
        self.pickerItem = nil
    }

    // MARK: - Save

    /// Saves the clip into the project, flashes a confirmation, then closes the capture
    /// screen so the user lands back in the app with the clip already in the project.
    private func saveClip(from url: URL) {
        Task {
            do {
                try await VideoStore.saveCapturedClip(
                    from: url,
                    into: project,
                    duration: settings.clipDuration,
                    modelContext: modelContext
                )
                justSaved = true
                engine.stopSession()
                try? await Task.sleep(nanoseconds: 700_000_000)
                dismiss()
            } catch {
                importError = error.localizedDescription
            }
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
