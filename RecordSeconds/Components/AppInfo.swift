import Foundation

/// Crazy Bee Labs constants shared across Settings/support/review flows.
enum AppInfo {
    static let supportURL = URL(string: "https://crazybeelabs.com/support/")!
    static let siteURL = URL(string: "https://crazybeelabs.com/")!
    static let privacyURL = URL(string: "https://www.crazybeelabs.com/legal/apps")!
    /// Apple's standard EULA — required next to any auto-renewable subscription.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Placeholder App Store id — replace once Record Seconds has a real App Store listing.
    static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6794005763?action=write-review")!
}
