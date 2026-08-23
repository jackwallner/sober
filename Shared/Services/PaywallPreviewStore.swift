#if DEBUG
import Foundation
#if canImport(RevenueCat)
import RevenueCat

/// A local stand-in for the RevenueCat offering, so the real paywall can be
/// rendered (and screenshotted) on a headless simulator.
///
/// `SubscriptionService.configure()` deliberately returns early on simulator so
/// agent runs can never pollute the production RevenueCat project. The side
/// effect was that the paywall could not be inspected anywhere except a real
/// device: no configure means no offerings, no offerings means no packages, and
/// `PaywallView` falls through to `devPlaceholder`. Every trial claim on the
/// screen is derived from a package, so none of them were verifiable.
///
/// These packages come from `TestStoreProduct`, so nothing touches the network
/// and no production key is involved. Prices here are illustrative; the point of
/// the harness is the *shape* of the copy (trial length, per-month, anchor), not
/// the amounts, which always come from StoreKit in a real run.
enum PaywallPreviewStore {

    static func packages(trialDays: Int) -> [Package] {
        let trial = TestStoreProductDiscount(
            identifier: "preview-free-trial",
            price: 0,
            localizedPriceString: "$0.00",
            paymentMode: .freeTrial,
            subscriptionPeriod: trialPeriod(days: trialDays),
            numberOfPeriods: 1,
            type: .introductory
        )

        let monthly = TestStoreProduct(
            localizedTitle: "Bloom+ Monthly",
            price: 9.99,
            currencyCode: "USD",
            localizedPriceString: "$9.99",
            productIdentifier: "com.jackwallner.sober.pro.monthly",
            productType: .autoRenewableSubscription,
            localizedDescription: "All of Bloom+, billed monthly.",
            subscriptionGroupIdentifier: "SG-PRO",
            subscriptionPeriod: .init(value: 1, unit: .month),
            introductoryDiscount: trial,
            locale: .init(identifier: "en_US")
        )

        let yearly = TestStoreProduct(
            localizedTitle: "Bloom+ Yearly",
            price: 29.99,
            currencyCode: "USD",
            localizedPriceString: "$29.99",
            productIdentifier: "com.jackwallner.sober.pro.yearly",
            productType: .autoRenewableSubscription,
            localizedDescription: "All of Bloom+, billed yearly.",
            subscriptionGroupIdentifier: "SG-PRO",
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryDiscount: trial,
            locale: .init(identifier: "en_US")
        )

        let lifetime = TestStoreProduct(
            localizedTitle: "Bloom+ Lifetime",
            price: 69.99,
            currencyCode: "USD",
            localizedPriceString: "$69.99",
            productIdentifier: "com.jackwallner.sober.pro.lifetime",
            productType: .nonConsumable,
            localizedDescription: "All of Bloom+, forever.",
            locale: .init(identifier: "en_US")
        )

        return [
            package("$rc_annual", .annual, yearly),
            package("$rc_monthly", .monthly, monthly),
            package("$rc_lifetime", .lifetime, lifetime),
        ]
    }

    /// Product identifiers the harness should report as trial-eligible.
    static func eligibleIdentifiers(in packages: [Package]) -> [String] {
        packages
            .filter { $0.storeProduct.introductoryDiscount?.paymentMode == .freeTrial }
            .map(\.storeProduct.productIdentifier)
    }

    /// Matches how App Store Connect models a trial: whole weeks where it can,
    /// days otherwise. `soberIntroOfferLabel` reads the unit back, so a 14-day
    /// trial has to arrive as 2 weeks to render the way the real offer will.
    private static func trialPeriod(days: Int) -> SubscriptionPeriod {
        let days = max(1, days)
        if days % 7 == 0 { return .init(value: days / 7, unit: .week) }
        return .init(value: days, unit: .day)
    }

    private static func package(
        _ identifier: String,
        _ type: PackageType,
        _ product: TestStoreProduct
    ) -> Package {
        Package(
            identifier: identifier,
            packageType: type,
            storeProduct: product.toStoreProduct(),
            offeringIdentifier: "preview",
            webCheckoutUrl: nil
        )
    }
}
#endif
#endif
