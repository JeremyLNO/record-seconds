import AVFoundation
import os

/// `AVAssetExportSession` collapses every structural problem in a video composition into
/// the same opaque failure ("Operation Stopped", -11841). This runs AVFoundation's own
/// validator first and logs what it actually objects to, plus the shape of each input
/// segment — enough to tell a bad generated title card from a bad instruction timeline.
enum CompositionDiagnostics {
    private static let log = Logger(subsystem: "company.lno.videoonesec", category: "export")

    static func log(built: TransitionEngine.Result, segmentURLs: [URL]) async {
        for (index, url) in segmentURLs.enumerated() {
            let asset = AVURLAsset(url: url)
            let duration = (try? await asset.load(.duration).seconds) ?? -1
            let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
            let size = (try? await videoTracks.first?.load(.naturalSize)) ?? .zero
            let nominalFPS = (try? await videoTracks.first?.load(.nominalFrameRate)) ?? -1
            Self.log.notice("""
            segment \(index): duration=\(duration, format: .fixed(precision: 3))s \
            videoTracks=\(videoTracks.count) size=\(size.width, format: .fixed(precision: 0))x\
            \(size.height, format: .fixed(precision: 0)) fps=\(nominalFPS, format: .fixed(precision: 1)) \
            file=\(url.lastPathComponent, privacy: .public)
            """)
        }

        Self.log.notice("""
        composition: duration=\(built.duration.seconds, format: .fixed(precision: 3))s \
        renderSize=\(built.videoComposition.renderSize.width, format: .fixed(precision: 0))x\
        \(built.videoComposition.renderSize.height, format: .fixed(precision: 0)) \
        instructions=\(built.videoComposition.instructions.count)
        """)
        for instruction in built.videoComposition.instructions {
            let layers = (instruction as? AVVideoCompositionInstruction)?.layerInstructions.map(\.trackID) ?? []
            Self.log.notice("""
            instruction \(instruction.timeRange.start.seconds, format: .fixed(precision: 3)) → \
            \(instruction.timeRange.end.seconds, format: .fixed(precision: 3)) layers=\(layers)
            """)
        }

        let validator = Validator()
        let valid = (try? await built.videoComposition.isValid(
            for: built.composition,
            timeRange: CMTimeRange(start: .zero, duration: built.duration),
            validationDelegate: validator
        )) ?? false
        Self.log.notice("composition isValid=\(valid)")
        for problem in validator.problems {
            Self.log.error("composition problem: \(problem, privacy: .public)")
        }
    }

    static func logExportFailure(status: AVAssetExportSession.Status, error: Error?) {
        Self.log.error("export failed: status=\(status.rawValue)")
        guard let error = error as NSError? else { return }
        Self.log.error("""
        export error: domain=\(error.domain, privacy: .public) code=\(error.code) \
        desc=\(error.localizedDescription, privacy: .public)
        """)
        for (key, value) in error.userInfo {
            Self.log.error("export error info: \(key, privacy: .public) = \(String(describing: value), privacy: .public)")
        }
    }

    /// Collects every complaint instead of stopping at the first, so one run reports all.
    private final class Validator: NSObject, AVVideoCompositionValidationHandling {
        var problems: [String] = []

        func videoComposition(_ videoComposition: AVComposition, shouldContinueValidatingAfterFindingInvalidValueForKey key: String) -> Bool {
            problems.append("invalid value for key \(key)")
            return true
        }

        func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingEmptyTimeRange timeRange: CMTimeRange) -> Bool {
            problems.append(String(format: "empty time range %.3f→%.3f", timeRange.start.seconds, timeRange.end.seconds))
            return true
        }

        func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingInvalidTimeRangeIn instruction: any AVVideoCompositionInstructionProtocol) -> Bool {
            problems.append(String(format: "invalid time range %.3f→%.3f", instruction.timeRange.start.seconds, instruction.timeRange.end.seconds))
            return true
        }

        func videoComposition(_ videoComposition: AVVideoComposition, shouldContinueValidatingAfterFindingInvalidTrackIDIn instruction: any AVVideoCompositionInstructionProtocol, layerInstruction: AVVideoCompositionLayerInstruction, asset: AVAsset) -> Bool {
            problems.append(String(format: "invalid trackID %d at %.3f→%.3f", layerInstruction.trackID, instruction.timeRange.start.seconds, instruction.timeRange.end.seconds))
            return true
        }
    }
}
