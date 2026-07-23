import SwiftUI
import AVFoundation
import UIKit

/// Renders a project's intro/end screen (text over a solid color) as a still image,
/// and — for export — as a short static-image video segment that splices into the
/// composition exactly like any other clip.
enum TitleCardRenderer {
    @MainActor
    static func image(for style: TitleCardStyle, size: CGSize) -> UIImage {
        let content = TitleCardContentView(style: style).frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }

    /// Writes `image` repeated for `style.duration` seconds into a new .mov file.
    static func video(for style: TitleCardStyle, size: CGSize, fps: Int32 = 30) async throws -> URL {
        let image = await image(for: style, size: size)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let pixelAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelAttrs)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        guard let pixelBuffer = makePixelBuffer(from: image, size: size) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let totalFrames = max(1, Int(Double(fps) * style.duration))
        var frame = 0
        while frame < totalFrames {
            if input.isReadyForMoreMediaData {
                let time = CMTime(value: CMTimeValue(frame), timescale: fps)
                adaptor.append(pixelBuffer, withPresentationTime: time)
                frame += 1
            } else {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return outputURL
    }

    private static func makePixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ), let cgImage = image.cgImage else { return nil }
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}

private struct TitleCardContentView: View {
    let style: TitleCardStyle
    var body: some View {
        ZStack {
            Color(hex: style.colorHex)
            Text(style.text)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(24)
        }
    }
}
