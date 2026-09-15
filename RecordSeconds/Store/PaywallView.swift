import SwiftUI
import StoreKit

/// Video One Sec Pro paywall — **In-App Purchase only** (App Review 3.1.1: on iOS,
/// paid features can't be unlocked by a licence bought on the web the way the macOS
/// apps do, so there is deliberately no licence-key field here).
///
/// Layout puts the product first: app icon + name at the top over the honeycomb
/// pattern, the offer in the middle, and the Crazy Bee Labs logo at the very bottom
/// as a signature.
struct PaywallView: View {
    /// `true` when shown as the trial-expired gate — the app is locked, so no close button.
    var isGate: Bool = false

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ProStore.shared

    @State private var selectedID = ProStore.yearlyID
    @State private var busy = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    appHeader
                    headline.padding(.top, 24)
                    features.padding(.top, 22)
                    plans.padding(.top, 24)
                    callToAction.padding(.top, 20)
                    legal.padding(.top, 16)
                    signature.padding(.top, 28)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .overlay(alignment: .topTrailing) {
                if !isGate {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
            }
            if busy {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView().controlSize(.large).tint(.white)
            }
        }
        .task {
            if store.hasNoProducts { await store.load() }
            if store.yearly == nil, let first = store.products.first { selectedID = first.id }
        }
        .onChange(of: store.isPro) { _, pro in if pro, !isGate { dismiss() } }
    }

    // MARK: - App identity (top priority)

    /// The app's own icon and name lead the screen; the honeycomb band behind them is
    /// the same pattern the intro/end cards use.
    private var appHeader: some View {
        VStack(spacing: 14) {
            if let icon = UIImage(named: "AppIconDisplay") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
            }
            VStack(spacing: 4) {
                Text("Video One Sec")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text(L.t("pay_app_tagline"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background {
            HoneycombBackground(seed: 20260915)
                .opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.top, isGate ? 28 : 12)
    }

    private var headline: some View {
        VStack(spacing: 6) {
            Text(isGate ? L.t("pay_trial_ended") : L.t("pay_get_pro"))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text(L.t("pay_subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(spacing: 14) {
            ForEach(Array(AppLicense.proFeatures.enumerated()), id: \.offset) { _, feature in
                featureRow(feature.systemImage, feature.title, feature.detail)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func featureRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 10) {
            if store.isLoading && planList.isEmpty {
                ProgressView().frame(height: 60)
            } else if planList.isEmpty {
                Text(L.t("pay_store_unavailable"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 10)
            } else {
                ForEach(planList) { planCard($0) }
            }
        }
    }

    /// One purchasable offer, ready to render.
    private struct Plan: Identifiable {
        let id: String
        let title: String
        let detail: String
        let price: String
        let product: Product?
    }

    private var planList: [Plan] {
        if !store.products.isEmpty {
            return store.products.map { p in
                let lifetime = p.id == ProStore.lifetimeID
                return Plan(id: p.id,
                            title: lifetime ? L.t("plan_lifetime") : L.t("plan_yearly"),
                            detail: lifetime ? L.t("plan_lifetime_detail")
                                             : (p.vosIntroOffer ?? L.t("plan_yearly_detail")),
                            price: lifetime ? p.displayPrice : p.vosPriceLabel,
                            product: p)
            }
        }
        #if DEBUG
        // -demoPrices: layout preview only. StoreKit returns no products unless the app
        // runs with VideoOneSec.storekit (or against App Store Connect).
        if CommandLine.arguments.contains("-demoPrices") {
            return [
                Plan(id: ProStore.yearlyID, title: L.t("plan_yearly"),
                     detail: L.t("plan_yearly_detail"), price: "9,99 € / \(L.t("period_year"))", product: nil),
                Plan(id: ProStore.lifetimeID, title: L.t("plan_lifetime"),
                     detail: L.t("plan_lifetime_detail"), price: "24,99 €", product: nil)
            ]
        }
        #endif
        return []
    }

    private func planCard(_ plan: Plan) -> some View {
        let selected = plan.id == selectedID
        return Button {
            selectedID = plan.id
        } label: {
            HStack(spacing: 13) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).font(.system(.headline, design: .rounded))
                    Text(plan.detail)
                        .font(.caption)
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                Spacer(minLength: 0)
                Text(plan.price)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            .padding(15)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color(.separator), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var callToAction: some View {
        VStack(spacing: 12) {
            Button { buy() } label: {
                Text(ctaTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(busy || planList.isEmpty)
            .opacity(planList.isEmpty ? 0.5 : 1)

            Button { restore() } label: {
                Text(L.t("pay_restore"))
                    .font(.subheadline.weight(.semibold))
            }
            .disabled(busy)

            if let error = store.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        guard let plan = planList.first(where: { $0.id == selectedID }) else { return L.t("pay_continue") }
        if plan.id == ProStore.lifetimeID { return L.t("pay_buy_once") }
        if plan.product?.vosIntroOffer != nil { return L.t("pay_start_trial") }
        return L.t("pay_subscribe")
    }

    // MARK: - Legal + signature

    private var legal: some View {
        VStack(spacing: 10) {
            Text(L.t("pay_terms"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link(L.t("privacy_policy"), destination: AppInfo.privacyURL)
                Link(L.t("terms_of_use"), destination: AppInfo.termsURL)
                Link(L.t("settings_support_ideas"), destination: AppInfo.supportURL)
            }
            .font(.caption2)
            .tint(.secondary)
        }
    }

    /// Crazy Bee Labs signature — deliberately last, below the app's own identity.
    private var signature: some View {
        Link(destination: AppInfo.siteURL) {
            VStack(spacing: 8) {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 120, height: 1)
                Image("CrazyBeeLabsLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .opacity(0.85)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func buy() {
        guard let product = planList.first(where: { $0.id == selectedID })?.product else { return }
        busy = true
        Task { await store.purchase(product); busy = false }
    }

    private func restore() {
        busy = true
        Task { await store.restore(); busy = false }
    }
}
