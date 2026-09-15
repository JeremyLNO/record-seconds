import SwiftUI
import UIKit

/// "made with Video One Sec" + app icon, shown at the bottom of exported movies and on
/// the intro/end cards for users on the free trial. A license removes it.
enum Watermark {
    static let text = "made with Video One Sec"

    /// Height of the badge as a fraction of the video height, so it reads the same on a
    /// 720p card and a 4K export.
    private static let heightRatio: CGFloat = 0.055
    /// Distance from the bottom edge, as a fraction of the video height. Callers place the
    /// badge (`WatermarkPass` on export, the preview player on screen) using this.
    static let bottomInsetRatio: CGFloat = 0.035

    static var iconImage: UIImage? { UIImage(named: "AppIconDisplay") }

    // MARK: - SwiftUI (title cards)

    /// Overlay used when rendering an intro/end card image.
    struct Badge: View {
        let cardHeight: CGFloat

        var body: some View {
            let height = cardHeight * heightRatio
            HStack(spacing: height * 0.28) {
                if let icon = iconImage {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: height, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: height * 0.24, style: .continuous))
                }
                Text(text)
                    .font(.system(size: height * 0.46, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, height * 0.42)
            .padding(.vertical, height * 0.22)
            .background(.black.opacity(0.32), in: Capsule())
        }
    }

}
