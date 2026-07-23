import AVFoundation
import Photos

enum VideoExportError: LocalizedError {
    case noClips
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .noClips: return L.t("export_error_no_clips")
        case .exportFailed(let reason): return reason
        }
    }
}

/// Renders a project's intro screen, clips, and end screen into one movie file
/// (via `TransitionEngine`), then saves it to Photos.
enum VideoExporter {
    /// Renders the project, saves the result to Photos, and returns the exported
    /// file's URL (kept around so the caller can also present the Share Sheet).
    static func exportAndSaveToPhotos(project: Project, progress: @escaping (Double) -> Void) async throws -> URL {
        guard !project.orderedClips.isEmpty else { throw VideoExportError.noClips }

        progress(0.05)
        let renderSize = CGSize(width: 1080, height: 1920)
        async let introVideo = TitleCardRenderer.video(for: project.introCard, size: renderSize)
        async let endVideo = TitleCardRenderer.video(for: project.endCard, size: renderSize)
        let (introURL, endURL) = try await (introVideo, endVideo)
        progress(0.25)

        let segmentURLs = [introURL] + project.orderedClips.map(\.fileURL) + [endURL]
        let built = try await TransitionEngine.build(segmentURLs: segmentURLs, transition: project.transition)
        progress(0.5)

        guard let exportSession = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.exportFailed(L.t("export_error_generic"))
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.name)-\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = built.videoComposition

        await exportSession.export()
        try? FileManager.default.removeItem(at: introURL)
        try? FileManager.default.removeItem(at: endURL)

        guard exportSession.status == .completed else {
            throw VideoExportError.exportFailed(exportSession.error?.localizedDescription ?? L.t("export_error_generic"))
        }
        progress(0.85)

        try await saveToPhotos(url: outputURL)
        progress(1.0)
        return outputURL
    }

    private static func saveToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw VideoExportError.exportFailed(L.t("export_error_photos_denied"))
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
