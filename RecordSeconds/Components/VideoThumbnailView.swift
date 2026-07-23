import SwiftUI
import AVFoundation

/// Async thumbnail for a clip's video file, generated on demand via
/// `AVAssetImageGenerator` (first frame). Falls back to a placeholder glyph while
/// loading or if the file is missing.
struct VideoThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
                Image(systemName: "video.fill").foregroundStyle(.secondary)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            image = UIImage(cgImage: cgImage)
        }
    }
}
