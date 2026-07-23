import SwiftUI

/// Crazy Bee Labs logo + link, dropped at the bottom of the Settings screen.
struct BrandFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Link(destination: AppInfo.siteURL) {
                VStack(spacing: 6) {
                    Image("CrazyBeeLabsLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22)
                    Text("crazybeelabs.com")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Record Seconds \(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}
