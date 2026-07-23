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
    }

    var body: some Scene {
        WindowGroup {
            AppGate()
        }
        .modelContainer(container)
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
