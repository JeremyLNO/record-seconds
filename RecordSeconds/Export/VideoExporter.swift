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

/// What a given export actually contains, once the license tier has had its say.
/// The free trial always gets the intro/end cards and the watermark, whatever the
/// project's own flags say — the flags are a paid feature, so they are resolved here
/// rather than trusted straight from the model.
struct ExportPlan {
    let includesIntro: Bool
    let includesEnd: Bool
    let showsWatermark: Bool

    init(project: Project, isPaid: Bool) {
        includesIntro = isPaid ? project.includesIntroCard : true
        includesEnd = isPaid ? project.includesEndCard : true
        showsWatermark = !isPaid
    }
}

/// Renders a project's intro screen, clips, and end screen into one movie file
/// (via `TransitionEngine`), then saves it to Photos.
enum VideoExporter {
    /// Renders the project, saves the result to Photos, and returns the exported
    /// file's URL (kept around so the caller can also present the Share Sheet).
    static func exportAndSaveToPhotos(project: Project, progress: @escaping (Double) -> Void) async throws -> URL {
        guard !project.orderedClips.isEmpty else { throw VideoExportError.noClips }

        // Free trial: watermark burned in, and the intro/end cards are not optional.
        // Read once up front so a license check can't flip mid-export.
        let isPaid = await MainActor.run { AppLicense.isPaid }
        let plan = ExportPlan(project: project, isPaid: isPaid)

        progress(0.05)
        let renderSize = CGSize(width: 1080, height: 1920)
        async let introVideo = plan.includesIntro
            ? TitleCardRenderer.video(for: project.introCard, size: renderSize)
            : nil
        async let endVideo = plan.includesEnd
            ? TitleCardRenderer.video(for: project.endCard, size: renderSize)
            : nil
        let (introURL, endURL) = try await (introVideo, endVideo)
        progress(0.25)

        let cardURLs = [introURL, endURL].compactMap { $0 }
        defer { cardURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let segmentURLs = [introURL].compactMap { $0 }
            + project.orderedClips.map(\.fileURL)
            + [endURL].compactMap { $0 }
        let built = try await TransitionEngine.build(segmentURLs: segmentURLs, transition: project.transition)
        progress(0.5)

        // AVAssetExportSession reports any bad composition as the opaque "Operation
        // Stopped" (-11841). Validate first so the log names the actual offender.
        await CompositionDiagnostics.log(built: built, segmentURLs: segmentURLs)

        guard let exportSession = AVAssetExportSession(asset: built.composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.exportFailed(L.t("export_error_generic"))
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.name)-\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = built.videoComposition

        await exportSession.export()

        guard exportSession.status == .completed else {
            // AVFoundation's user-facing strings here are famously vague ("Operation
            // Stopped"), so record domain/code/underlying error for diagnosis.
            CompositionDiagnostics.logExportFailure(status: exportSession.status, error: exportSession.error)
            throw VideoExportError.exportFailed(exportSession.error?.localizedDescription ?? L.t("export_error_generic"))
        }
        progress(0.7)

        // Free tier: second pass to burn in the badge over the whole movie, cards included.
        var finalURL = outputURL
        if plan.showsWatermark {
            finalURL = try await WatermarkPass.apply(to: outputURL)
            try? FileManager.default.removeItem(at: outputURL)
        }
        progress(0.85)

        try await saveToPhotos(url: finalURL)
        progress(1.0)
        return finalURL
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
