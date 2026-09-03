import Foundation

/// Crazy Bee Labs constants shared across Settings/support/review flows.
enum AppInfo {
    static let supportURL = URL(string: "https://crazybeelabs.com/support/")!
    static let siteURL = URL(string: "https://crazybeelabs.com/")!
    static let privacyURL = URL(string: "https://www.crazybeelabs.com/legal/apps")!
    /// Placeholder App Store id — replace once Record Seconds has a real App Store listing.
    static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!
}
