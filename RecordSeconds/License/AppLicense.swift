import Foundation
import CrazyBeeLicense

/// Wires the shared CrazyBeeLicense package to this app's bundle id + purchase page.
/// Same pattern as Shotbox / Macnap Blocker / Energy Manager / SpacesPilot.
enum AppLicense {
    @MainActor static let manager = LicenseManager(config: .init(
        apiBaseURL: URL(string: "https://crazybeelabs.com")!,
        bundleId: "company.lno.videoonesec",
        purchaseURL: URL(string: "https://crazybeelabs.com/apps/record-seconds")!
    ))

    /// True once the user actually paid. The 7-day trial is the "free version": fully
    /// usable, but exports carry the watermark and always include the intro/end cards.
    ///
    /// On iOS the unlock is the StoreKit purchase (App Review 3.1.1). The CrazyBeeLicense
    /// state is still honoured so an owner licence keeps working for internal builds, but
    /// there is no key field in the UI to enter one.
    @MainActor static var isPaid: Bool {
        #if DEBUG
        // Lets a Simulator run exercise either tier without a purchase, same spirit as
        // the other debug launch flags.
        if CommandLine.arguments.contains("-forcePaid") { return true }
        if CommandLine.arguments.contains("-forceFree") { return false }
        #endif
        if ProStore.shared.isPro { return true }
        if case .licensed = manager.state { return true }
        return false
    }

    /// Everything a purchase unlocks — the paywall's selling points. Extends the
    /// onboarding `features` with what the free tier deliberately withholds.
    @MainActor static var proFeatures: [LicenseFeature] {
        features + [
            LicenseFeature(
                systemImage: "checkmark.seal.fill",
                title: L.t("pro_feature_no_watermark_title"),
                detail: L.t("pro_feature_no_watermark_detail")
            ),
            LicenseFeature(
                systemImage: "slider.horizontal.3",
                title: L.t("pro_feature_cards_title"),
                detail: L.t("pro_feature_cards_detail")
            ),
        ]
    }

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
