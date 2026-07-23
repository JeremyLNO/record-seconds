import AVFoundation
import CoreGraphics

/// Builds an `AVMutableComposition` + `AVMutableVideoComposition` from an ordered list
/// of video segments (intro card, clips, end card), applying either a hard cut or a
/// cross-dissolve between every consecutive pair.
///
/// Cross-dissolve uses two alternating composition tracks with overlapping time ranges
/// and opacity ramps — the standard AVFoundation technique, no custom `AVVideoCompositing`
/// needed. Segment durations are always >= 1s and the dissolve is 0.35s, so no more than
/// two segments ever overlap at once.
enum TransitionEngine {
    struct Result {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition
        let duration: CMTime
    }

    private struct Placement {
        let track: AVMutableCompositionTrack
        let transform: CGAffineTransform
        let start: CMTime
        let duration: CMTime
    }

    static func build(segmentURLs: [URL], transition: TransitionType) async throws -> Result {
        precondition(!segmentURLs.isEmpty)

        let composition = AVMutableComposition()
        guard
            let trackA = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let trackB = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw CocoaError(.fileWriteUnknown) }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let renderSize = await Self.renderSize(forFirstAssetAt: segmentURLs[0])
        let dissolve = CMTime(seconds: transition.duration, preferredTimescale: 600)
        let overlap = transition == .dissolve ? dissolve : .zero

        var placements: [Placement] = []
        var cursor = CMTime.zero

        for (i, url) in segmentURLs.enumerated() {
            let asset = AVURLAsset(url: url)
            guard let videoAssetTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
            let assetDuration = try await asset.load(.duration)
            let track = (i % 2 == 0) ? trackA : trackB
            let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
            try track.insertTimeRange(timeRange, of: videoAssetTrack, at: cursor)
            if let audioTrack, let audioAssetTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: audioAssetTrack, at: cursor)
            }
            let transform = await layerTransform(for: videoAssetTrack, renderSize: renderSize)
            placements.append(Placement(track: track, transform: transform, start: cursor, duration: assetDuration))

            if i < segmentURLs.count - 1 {
                cursor = cursor + assetDuration - overlap
            } else {
                cursor = cursor + assetDuration
            }
        }

        var instructions: [AVMutableVideoCompositionInstruction] = []
        for (i, placement) in placements.enumerated() {
            let segEnd = placement.start + placement.duration
            let hasIncoming = i > 0 && overlap > .zero
            let hasOutgoing = i < placements.count - 1 && overlap > .zero
            let soloStart = hasIncoming ? placement.start + overlap : placement.start
            let soloEnd = hasOutgoing ? segEnd - overlap : segEnd

            if soloEnd > soloStart {
                instructions.append(soloInstruction(placement: placement, range: CMTimeRange(start: soloStart, end: soloEnd)))
            }
            if hasOutgoing {
                let next = placements[i + 1]
                let range = CMTimeRange(start: segEnd - overlap, end: segEnd)
                instructions.append(crossfadeInstruction(outgoing: placement, incoming: next, range: range))
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions

        return Result(composition: composition, videoComposition: videoComposition, duration: cursor)
    }

    // MARK: - Instructions

    private static func soloInstruction(placement: Placement, range: CMTimeRange) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: placement.track)
        layer.setTransform(placement.transform, at: range.start)
        instruction.layerInstructions = [layer]
        return instruction
    }

    private static func crossfadeInstruction(outgoing: Placement, incoming: Placement, range: CMTimeRange) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = range

        let inLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: incoming.track)
        inLayer.setTransform(incoming.transform, at: range.start)
        inLayer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: 1, timeRange: range)

        let outLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: outgoing.track)
        outLayer.setTransform(outgoing.transform, at: range.start)
        outLayer.setOpacityRamp(fromStartOpacity: 1, toEndOpacity: 0, timeRange: range)

        instruction.layerInstructions = [inLayer, outLayer]
        return instruction
    }

    // MARK: - Orientation / fit

    private static func renderSize(forFirstAssetAt url: URL) async -> CGSize {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return CGSize(width: 1080, height: 1920) }
        let natural = (try? await track.load(.naturalSize)) ?? CGSize(width: 1080, height: 1920)
        let transform = (try? await track.load(.preferredTransform)) ?? .identity
        let rotated = CGRect(origin: .zero, size: natural).applying(transform)
        let size = CGSize(width: abs(rotated.width), height: abs(rotated.height))
        return size.width > 0 && size.height > 0 ? size : CGSize(width: 1080, height: 1920)
    }

    /// Rotates via the track's own `preferredTransform`, then uniformly scales to fit
    /// (letterboxed, never cropped) inside `renderSize`, then centers.
    private static func layerTransform(for track: AVAssetTrack, renderSize: CGSize) async -> CGAffineTransform {
        let natural = (try? await track.load(.naturalSize)) ?? renderSize
        let preferred = (try? await track.load(.preferredTransform)) ?? .identity
        let rotatedRect = CGRect(origin: .zero, size: natural).applying(preferred)
        let rotatedSize = CGSize(width: abs(rotatedRect.width), height: abs(rotatedRect.height))
        guard rotatedSize.width > 0, rotatedSize.height > 0 else { return preferred }

        let scale = min(renderSize.width / rotatedSize.width, renderSize.height / rotatedSize.height)
        let scaledWidth = rotatedSize.width * scale
        let scaledHeight = rotatedSize.height * scale
        let tx = (renderSize.width - scaledWidth) / 2
        let ty = (renderSize.height - scaledHeight) / 2

        let normalize = CGAffineTransform(translationX: -rotatedRect.origin.x, y: -rotatedRect.origin.y)
        return preferred
            .concatenating(normalize)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }
}
