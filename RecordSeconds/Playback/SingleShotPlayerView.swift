import SwiftUI
import AVFoundation

/// Plays a video file once from the start (no looping) — used by the sequential
/// project preview, where each clip advances to the next item after its duration.
struct SingleShotPlayerView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(url: url)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    final class PlayerUIView: UIView {
        private let player: AVPlayer

        init(url: URL) {
            player = AVPlayer(url: url)
            super.init(frame: .zero)
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            self.layer.addSublayer(layer)
            player.play()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.first?.frame = bounds
        }
    }
}
