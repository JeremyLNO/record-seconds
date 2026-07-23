import SwiftUI

/// Persistent floating button that jumps straight into a 1-3s capture, routed to
/// whichever project Settings designates (last-used or a fixed default).
struct QuickCaptureButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                Image(systemName: "record.circle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L.t("quick_capture_button_label")))
    }
}
