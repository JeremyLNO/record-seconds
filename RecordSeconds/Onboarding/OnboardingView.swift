import SwiftUI
import CrazyBeeLicense

/// First-launch, shown-once carousel: one page per `AppLicense.features` entry, then a
/// final page explaining the 7-day free trial (all features unlocked, no card needed).
/// Purely informational — it must never touch camera/microphone permissions itself;
/// those are requested naturally once the user reaches the capture screen.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    private var featureCount: Int { AppLicense.features.count }
    private var totalPages: Int { featureCount + 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(AppLicense.features.enumerated()), id: \.offset) { index, feature in
                    featurePage(feature)
                        .tag(index)
                }
                trialPage
                    .tag(featureCount)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < totalPages - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < totalPages - 1 ? L.t("continue") : L.t("onboarding_get_started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
    }

    private func featurePage(_ feature: LicenseFeature) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: feature.systemImage)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .frame(height: 72)
            Text(feature.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(feature.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var trialPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .frame(height: 72)
            Text(L.t("onboarding_trial_title"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(L.t("onboarding_trial_body"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
