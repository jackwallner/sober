import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCat)

enum SoberPackageKind: Int {
    case lifetime = 0
    case yearly = 1
    case monthly = 2
    case other = 3
}

extension SoberPackageKind {
    init(package: Package) {
        switch package.packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        default:
            let identifiers = [package.identifier, package.storeProduct.productIdentifier].map { $0.lowercased() }
            if identifiers.contains(where: { $0.contains("lifetime") }) {
                self = .lifetime
            } else if identifiers.contains(where: { $0.contains("yearly") || $0.contains("annual") }) {
                self = .yearly
            } else if identifiers.contains(where: { $0.contains("monthly") }) {
                self = .monthly
            } else {
                self = .other
            }
        }
    }
}

extension Package {
    var soberPackageKind: SoberPackageKind {
        SoberPackageKind(package: self)
    }

    var soberDisplayName: String {
        switch soberPackageKind {
        case .lifetime:
            return "Lifetime"
        case .yearly:
            return "Yearly"
        case .monthly:
            return "Monthly"
        case .other:
            return storeProduct.localizedTitle
        }
    }

    var soberPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.value == 1 {
            return "\(storeProduct.localizedPriceString) / \(unit)"
        }
        return "\(storeProduct.localizedPriceString) / \(period.value) \(unit)"
    }

    /// Number of months covered by a single billing period. Used to derive the
    /// "per-month" anchor that makes annual feel cheap next to monthly.
    var soberMonthsInPeriod: Decimal? {
        guard let period = storeProduct.subscriptionPeriod else { return nil }
        let v = Decimal(period.value)
        switch period.unit {
        case .day: return v / 30
        case .week: return v / Decimal(string: "4.345")!
        case .month: return v
        case .year: return v * 12
        @unknown default: return nil
        }
    }

    /// "$2.50 / mo" derived from the package price (only meaningful for >1 month
    /// periods — i.e. annual / lifetime). Returns nil when math doesn't apply
    /// or the storefront doesn't expose a currency.
    var soberPerMonthLabel: String? {
        guard let months = soberMonthsInPeriod, months >= 2 else { return nil }
        let perMonth = (storeProduct.price as NSDecimalNumber)
            .dividing(by: months as NSDecimalNumber)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = storeProduct.priceFormatter?.locale ?? .current
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        guard let s = f.string(from: perMonth) else { return nil }
        return "\(s) / mo"
    }

    /// Discount % vs a monthly plan, e.g. annual at $29.99 vs monthly at $4.99/mo
    /// = 50% off. Returns nil if a comparable monthly isn't available or the
    /// product doesn't run for at least 2 months.
    func soberSavingsPercent(vsMonthly monthly: Package?) -> Int? {
        guard let monthly,
              let months = soberMonthsInPeriod,
              months >= 2 else { return nil }
        let monthlyPrice = monthly.storeProduct.price as NSDecimalNumber
        let projected = monthlyPrice.multiplying(by: months as NSDecimalNumber)
        let actual = storeProduct.price as NSDecimalNumber
        guard projected.doubleValue > 0, actual.doubleValue > 0 else { return nil }
        let saved = projected.doubleValue - actual.doubleValue
        guard saved > 0 else { return nil }
        return Int((saved / projected.doubleValue * 100).rounded())
    }

    /// Strikethrough anchor price — the equivalent monthly×12 cost, e.g.
    /// "$59.88" for a $29.99 annual when monthly is $4.99.
    func soberAnchorPriceLabel(vsMonthly monthly: Package?) -> String? {
        guard let monthly,
              let months = soberMonthsInPeriod,
              months >= 2 else { return nil }
        let monthlyPrice = monthly.storeProduct.price as NSDecimalNumber
        let projected = monthlyPrice.multiplying(by: months as NSDecimalNumber)
        let actual = (storeProduct.price as NSDecimalNumber).doubleValue
        guard projected.doubleValue > actual else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = storeProduct.priceFormatter?.locale ?? .current
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: projected)
    }

    /// Human-readable free-trial label when the product carries a free-trial intro offer.
    var soberIntroOfferLabel: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = ""
        }
        if period.unit == .week {
            return "\(period.value * 7)-day free trial"
        }
        return "\(period.value)-\(unit.dropLast(period.value == 1 ? 0 : 1)) free trial"
    }

    func packageHasFreeTrialIntro() -> Bool {
        soberIntroOfferLabel != nil
    }
}

extension Offering {
    var soberSortedPackages: [Package] {
        availablePackages.sorted {
            let lhsKind = $0.soberPackageKind
            let rhsKind = $1.soberPackageKind
            if lhsKind.rawValue != rhsKind.rawValue {
                return lhsKind.rawValue < rhsKind.rawValue
            }
            return $0.storeProduct.productIdentifier < $1.storeProduct.productIdentifier
        }
    }
}

extension Offerings {
    var soberPaywallOffering: Offering? {
        offering(identifier: "default") ?? current
    }
}

#endif
