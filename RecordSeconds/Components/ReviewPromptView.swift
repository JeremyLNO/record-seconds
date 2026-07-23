import SwiftUI
import StoreKit

/// 24h-after-install "are you enjoying the app?" prompt. "Yes" opens the App Store
/// review page for this app; "No" opens the support & ideas page instead — a custom
/// branch rather than the system `SKStoreReviewController`, per spec.
@MainActor
final class ReviewPromptManager: ObservableObject {
    @Published var isPresented = false

    private enum Keys {
        static let firstLaunchAt = "review.firstLaunchAt"
        static let hasPrompted = "review.hasPrompted"
    }

    private let defaults: UserDefaults
    private let delay: TimeInterval

    init(defaults: UserDefaults = .standard, delay: TimeInterval = 24 * 3600) {
        self.defaults = defaults
        self.delay = delay
        if defaults.object(forKey: Keys.firstLaunchAt) == nil {
            defaults.set(Date(), forKey: Keys.firstLaunchAt)
        }
    }

    func presentIfDue() {
        guard !defaults.bool(forKey: Keys.hasPrompted) else { return }
        let firstLaunch = defaults.object(forKey: Keys.firstLaunchAt) as? Date ?? Date()
        guard Date().timeIntervalSince(firstLaunch) >= delay else { return }
        isPresented = true
    }

    func respond(satisfied: Bool) {
        defaults.set(true, forKey: Keys.hasPrompted)
        isPresented = false
        let url = satisfied ? AppInfo.appStoreReviewURL : AppInfo.supportURL
        UIApplication.shared.open(url)
    }

    func dismiss() {
        defaults.set(true, forKey: Keys.hasPrompted)
        isPresented = false
    }
}

struct ReviewPromptView: View {
    @ObservedObject var manager: ReviewPromptManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(.pink)
                .padding(.top, 32)
            Text(L.t("review_prompt_title"))
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(L.t("review_prompt_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button(L.t("no")) { manager.respond(satisfied: false) }
                    .buttonStyle(.bordered)
                Button(L.t("yes")) { manager.respond(satisfied: true) }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .presentationDetents([.medium])
    }
}
