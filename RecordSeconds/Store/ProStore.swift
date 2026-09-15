import StoreKit
import SwiftUI

/// StoreKit 2 entitlement manager for Video One Sec Pro.
///
/// iOS unlocks are **In-App Purchases only**: App Review guideline 3.1.1 forbids
/// unlocking paid features with a licence bought outside the App Store, which is how
/// the macOS apps do it. The shared `CrazyBeeLicense` package still runs the 7-day
/// free trial, but the purchase itself goes through StoreKit here.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    /// Auto-renewable yearly subscription.
    static let yearlyID = "company.lno.videoonesec.pro.yearly"
    /// Non-consumable one-off unlock.
    static let lifetimeID = "company.lno.videoonesec.pro.lifetime"
    static var productIDs: [String] { [yearlyID, lifetimeID] }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = true
    @Published var lastError: String?

    var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }
    /// True when StoreKit returned nothing (no products configured / offline).
    var hasNoProducts: Bool { products.isEmpty }

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task { await load(); await refreshEntitlement() }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        isLoading = true
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            // Keep a stable order: yearly first, then lifetime.
            products = Self.productIDs.compactMap { id in fetched.first { $0.id == id } }
        } catch {
            products = []
        }
        isLoading = false
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        lastError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                    return isPro
                }
                lastError = L.t("pay_error_unverified")
                return false
            case .userCancelled:
                return false
            case .pending:
                lastError = L.t("pay_pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Backs the "Restore Purchases" button App Review requires on any paid screen.
    func restore() async {
        lastError = nil
        do { try await AppStore.sync() } catch { /* cancelled or offline — entitlements below still apply */ }
        await refreshEntitlement()
        if !isPro { lastError = L.t("pay_nothing_to_restore") }
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result else { continue }
            guard Self.productIDs.contains(t.productID), t.revocationDate == nil else { continue }
            if let expiry = t.expirationDate, expiry < Date() { continue }
            active = true
        }
        isPro = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }
}

extension Product {
    /// "9,99 € / year" style label built from the product's own localised price.
    var vosPriceLabel: String {
        guard let period = subscription?.subscriptionPeriod else { return displayPrice }
        let unit: String
        switch period.unit {
        case .year:  unit = L.t("period_year")
        case .month: unit = L.t("period_month")
        case .week:  unit = L.t("period_week")
        case .day:   unit = L.t("period_day")
        @unknown default: return displayPrice
        }
        return "\(displayPrice) / \(unit)"
    }

    /// Localised free-trial length ("7 days free"), when the product offers one.
    var vosIntroOffer: String? {
        guard let offer = subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let n = offer.period.value
        let unitKey: String
        switch offer.period.unit {
        case .day:   unitKey = n == 1 ? "period_day" : "period_days"
        case .week:  unitKey = n == 1 ? "period_week" : "period_weeks"
        case .month: unitKey = n == 1 ? "period_month" : "period_months"
        case .year:  unitKey = n == 1 ? "period_year" : "period_years"
        @unknown default: return nil
        }
        return String(format: L.t("pay_free_trial_length"), n, L.t(unitKey))
    }
}
