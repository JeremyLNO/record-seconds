import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// Burns the watermark badge into an already-assembled movie, as a second pass.
///
/// The obvious route — `AVVideoCompositionCoreAnimationTool` on the main composition —
/// was tried and rejected: its offscreen `CARenderer` crashes in the Simulator (SIGTRAP
/// inside IOSurface creation), which makes the free tier impossible to verify. Core Image
/// per-frame compositing has no such dependency, and running it as a separate pass keeps
/// the transition composition in `TransitionEngine` untouched.
///
/// The extra pass costs one re-encode of a clip that is only a few seconds long.
enum WatermarkPass {
    /// Returns a new file with the badge composited over every frame. The input file is
    /// left alone; the caller owns both URLs.
    static func apply(to sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoExportError.exportFailed(L.t("export_error_generic"))
        }

        // Frame size after the track's own rotation, which is what CI sees.
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let rotated = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let frameSize = CGSize(width: abs(rotated.width), height: abs(rotated.height))

        let badge = await badgeImage(videoHeight: frameSize.height)
        guard let badgeCI = badge.flatMap({ CIImage(image: $0) }) else {
            throw VideoExportError.exportFailed(L.t("export_error_generic"))
        }

        // Core Image's origin is bottom-left, so the inset is measured from the bottom.
        let inset = frameSize.height * Watermark.bottomInsetRatio
        let origin = CGPoint(
            x: (frameSize.width - badgeCI.extent.width) / 2,
            y: inset
        )
        let positioned = badgeCI.transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))

        let composition = AVMutableVideoComposition(asset: asset) { request in
            let output = positioned.composited(over: request.sourceImage)
                .cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: nil)
        }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoExportError.exportFailed(L.t("export_error_generic"))
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wm-\(UUID().uuidString).mp4")
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = composition

        await session.export()
        guard session.status == .completed else {
            CompositionDiagnostics.logExportFailure(status: session.status, error: session.error)
            throw VideoExportError.exportFailed(session.error?.localizedDescription ?? L.t("export_error_generic"))
        }
        return outputURL
    }

    /// The badge rendered to a transparent bitmap, sized relative to the video height so
    /// it reads the same at any resolution.
    @MainActor
    private static func badgeImage(videoHeight: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: Watermark.Badge(cardHeight: videoHeight))
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.uiImage
    }
}
