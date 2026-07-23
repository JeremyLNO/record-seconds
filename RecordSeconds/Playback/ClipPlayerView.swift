import SwiftUI
import AVFoundation
import AVKit

/// Loops a single video file — used for the capture confirm step and for tapping a
/// clip in a project's grid.
struct ClipPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: url)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}

    final class LoopingPlayerUIView: UIView {
        private var looper: AVPlayerLooper?
        private let queuePlayer = AVQueuePlayer()

        init(url: URL) {
            super.init(frame: .zero)
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            let layer = AVPlayerLayer(player: queuePlayer)
            layer.videoGravity = .resizeAspect
            self.layer.addSublayer(layer)
            queuePlayer.play()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.first?.frame = bounds
        }
    }
}
