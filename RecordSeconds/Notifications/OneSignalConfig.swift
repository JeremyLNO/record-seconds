import Foundation
#if canImport(OneSignalFramework)
import OneSignalFramework
#endif

/// OneSignal push notifications — config-gated like the rest of the Crazy Bee Labs
/// portfolio: with no real App ID set, this is a silent no-op so the app works fully
/// without push until Jeremy supplies real OneSignal credentials.
enum OneSignalConfig {
    /// Replace with the real OneSignal App ID once created on onesignal.com.
    static let appID: String? = "56552fac-ce5e-414d-a1df-9ea5f76ae7ed"

    static func startIfConfigured() {
        // Screenshot/test runs skip the system permission alert, same convention as
        // fasting-app / cycles-app.
        if CommandLine.arguments.contains("-skipNotifPrompt") { return }
        guard let appID, !appID.isEmpty else { return }
        #if canImport(OneSignalFramework)
        OneSignal.initialize(appID, withLaunchOptions: nil)
        OneSignal.Notifications.requestPermission({ _ in }, fallbackToSettings: true)
        #endif
    }

    /// Call from Settings when the user flips the notifications toggle.
    static func setEnabled(_ enabled: Bool) {
        guard appID != nil else { return }
        #if canImport(OneSignalFramework)
        OneSignal.User.pushSubscription.optIn()
        if !enabled { OneSignal.User.pushSubscription.optOut() }
        #endif
    }
}
