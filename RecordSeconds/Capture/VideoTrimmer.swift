import Foundation
import AVFoundation

/// Trims a source video down to at most `duration` seconds, used both for the
/// Simulator's "import from Photos" capture fallback and anywhere else a clip needs
/// to be normalized to the configured 1-3s length.
enum VideoTrimmer {
    static func trim(sourceURL: URL, to duration: TimeInterval) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let assetDuration = try await asset.load(.duration).seconds
        let clippedDuration = min(duration, assetDuration.isFinite ? assetDuration : duration)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: clippedDuration, preferredTimescale: 600))

        await exportSession.export()
        if let error = exportSession.error { throw error }
        return outputURL
    }
}
