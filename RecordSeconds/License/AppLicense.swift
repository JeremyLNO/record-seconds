import Foundation
import CrazyBeeLicense

/// Wires the shared CrazyBeeLicense package to this app's bundle id + purchase page.
/// Same pattern as Shotbox / Macnap Blocker / Energy Manager / SpacesPilot.
enum AppLicense {
    @MainActor static let manager = LicenseManager(config: .init(
        apiBaseURL: URL(string: "https://crazybeelabs.com")!,
        bundleId: "company.lno.recordseconds",
        purchaseURL: URL(string: "https://crazybeelabs.com/apps/record-seconds")!
    ))

    @MainActor static var features: [LicenseFeature] {
        [
            LicenseFeature(
                systemImage: "square.stack.3d.up.fill",
                title: L.t("license_feature_projects_title"),
                detail: L.t("license_feature_projects_detail")
            ),
            LicenseFeature(
                systemImage: "wand.and.stars",
                title: L.t("license_feature_transitions_title"),
                detail: L.t("license_feature_transitions_detail")
            ),
            LicenseFeature(
                systemImage: "square.and.arrow.up",
                title: L.t("license_feature_export_title"),
                detail: L.t("license_feature_export_detail")
            ),
        ]
    }
}
