import SwiftUI
import SwiftData
import CrazyBeeLicense

@main
struct RecordSecondsApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Project.self, Clip.self)
        } catch {
            fatalError("Could not create SwiftData ModelContainer: \(error)")
        }
        AppLicense.manager.startMonitoring()
        OneSignalConfig.startIfConfigured()

        // Lets screenshot/test automation skip straight past onboarding, same convention
        // as fasting-app / respire-app.
        if CommandLine.arguments.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: OnboardingGate.completedKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            OnboardingGate()
        }
        .modelContainer(container)
    }
}

/// Shows the first-launch onboarding carousel once, then falls through to the
/// existing `AppGate` (license check unchanged).
private struct OnboardingGate: View {
    static let completedKey = "onboarding.completed"

    @AppStorage(completedKey) private var completed = false

    var body: some View {
        if completed {
            AppGate()
        } else {
            OnboardingView { completed = true }
        }
    }
}

/// Gates the whole app behind the license state — trial running or a valid license
/// shows `RootView`, otherwise the shared `LicenseLockedView` paywall.
private struct AppGate: View {
    @ObservedObject private var license = AppLicense.manager

    var body: some View {
        Group {
            if license.isFunctional {
                RootView()
            } else {
                LicenseLockedView(
                    manager: license,
                    features: AppLicense.features,
                    logo: Image("CrazyBeeLabsLogo")
                )
            }
        }
        .task { await license.refresh() }
    }
}
