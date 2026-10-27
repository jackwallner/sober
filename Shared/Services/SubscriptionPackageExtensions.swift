import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

#if canImport(RevenueCat)

enum SoberPackageKind: Int {
    case yearly = 0
    case monthly = 1
    case lifetime = 2
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
            return String(localized: "Lifetime")
        case .yearly:
            return String(localized: "Yearly")
        case .monthly:
            return String(localized: "Monthly")
        case .other:
            return storeProduct.localizedTitle
        }
    }

    var soberPriceLabel: String {
        guard let period = storeProduct.subscriptionPeriod else { return storeProduct.localizedPriceString }
        let price = storeProduct.localizedPriceString
        let n = period.value
        if n == 1 {
            switch period.unit {
            case .day: return String(localized: "\(price) / day")
            case .week: return String(localized: "\(price) / week")
            case .month: return String(localized: "\(price) / month")
            case .year: return String(localized: "\(price) / year")
            @unknown default: return price
            }
        }
        switch period.unit {
        case .day: return String(localized: "\(price) / \(n) days")
        case .week: return String(localized: "\(price) / \(n) weeks")
        case .month: return String(localized: "\(price) / \(n) months")
        case .year: return String(localized: "\(price) / \(n) years")
        @unknown default: return price
        }
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
        return String(localized: "\(s) / mo")
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
        switch period.unit {
        case .day: return String(localized: "\(period.value)-day free trial")
        case .week: return String(localized: "\(period.value * 7)-day free trial")
        case .month: return String(localized: "\(period.value)-month free trial")
        case .year: return String(localized: "\(period.value)-year free trial")
        @unknown default: return String(localized: "Free trial")
        }
    }

    /// Free-trial length in days, for copy that counts it down.
    var soberIntroOfferDays: Int? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    /// "7-day free trial, then $4.99 / month." as one sentence, so the trial
    /// length and the price can trade places in translation.
    var soberTrialThenPriceSentence: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        let price = soberPriceLabel
        switch period.unit {
        case .day: return String(localized: "\(period.value)-day free trial, then \(price).")
        case .week: return String(localized: "\(period.value * 7)-day free trial, then \(price).")
        case .month: return String(localized: "\(period.value)-month free trial, then \(price).")
        case .year: return String(localized: "\(period.value)-year free trial, then \(price).")
        @unknown default: return nil
        }
    }

    /// "Start 7-Day Free Trial" for the CTA.
    var soberStartTrialTitle: String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return String(localized: "Start \(period.value)-Day Free Trial")
        case .week: return String(localized: "Start \(period.value * 7)-Day Free Trial")
        case .month: return String(localized: "Start \(period.value)-Month Free Trial")
        case .year: return String(localized: "Start \(period.value)-Year Free Trial")
        @unknown default: return String(localized: "Start Free Trial")
        }
    }

    /// "7-day free · $2.50 / mo" for a plan card's subtitle.
    func soberTrialFreeSubtitle(perMonth: String) -> String? {
        guard let intro = storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial else {
            return nil
        }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return String(localized: "\(period.value)-day free · \(perMonth)")
        case .week: return String(localized: "\(period.value * 7)-day free · \(perMonth)")
        case .month: return String(localized: "\(period.value)-month free · \(perMonth)")
        case .year: return String(localized: "\(period.value)-year free · \(perMonth)")
        @unknown default: return perMonth
        }
    }

    func packageHasFreeTrialIntro() -> Bool {
        soberIntroOfferLabel != nil
    }

    /// Full habit-relative sentence for this package, e.g. "A year of Bloom+
    /// costs about a day and a half of drinking." Nil when the user hasn't
    /// entered a daily spend or the comparison stops being flattering. Every
    /// plan and span pairing is its own whole sentence so translations can
    /// inflect both halves.
    func soberHabitComparisonSentence(costPerDayCents: Int) -> String? {
        guard costPerDayCents > 0 else { return nil }
        let price = (storeProduct.price as NSDecimalNumber).doubleValue
        guard let days = HabitPriceComparison.daysOfHabit(
            price: price,
            costPerDay: Double(costPerDayCents) / 100
        ) else { return nil }
        let span = HabitPriceComparison.span(days)
        switch soberPackageKind {
        case .yearly:
            switch span {
            case .underADay: return String(localized: "A year of Bloom+ costs less than a day of drinking.")
            case .aboutADay: return String(localized: "A year of Bloom+ costs about a day of drinking.")
            case .aboutADayAndAHalf: return String(localized: "A year of Bloom+ costs about a day and a half of drinking.")
            case .aboutDays(let n): return String(localized: "A year of Bloom+ costs about \(n) days of drinking.")
            case .aboutDaysAndAHalf(let n): return String(localized: "A year of Bloom+ costs about \(n) and a half days of drinking.")
            }
        case .monthly:
            switch span {
            case .underADay: return String(localized: "A month of Bloom+ costs less than a day of drinking.")
            case .aboutADay: return String(localized: "A month of Bloom+ costs about a day of drinking.")
            case .aboutADayAndAHalf: return String(localized: "A month of Bloom+ costs about a day and a half of drinking.")
            case .aboutDays(let n): return String(localized: "A month of Bloom+ costs about \(n) days of drinking.")
            case .aboutDaysAndAHalf(let n): return String(localized: "A month of Bloom+ costs about \(n) and a half days of drinking.")
            }
        case .lifetime:
            switch span {
            case .underADay: return String(localized: "Bloom+ for life costs less than a day of drinking.")
            case .aboutADay: return String(localized: "Bloom+ for life costs about a day of drinking.")
            case .aboutADayAndAHalf: return String(localized: "Bloom+ for life costs about a day and a half of drinking.")
            case .aboutDays(let n): return String(localized: "Bloom+ for life costs about \(n) days of drinking.")
            case .aboutDaysAndAHalf(let n): return String(localized: "Bloom+ for life costs about \(n) and a half days of drinking.")
            }
        case .other:
            switch span {
            case .underADay: return String(localized: "Bloom+ costs less than a day of drinking.")
            case .aboutADay: return String(localized: "Bloom+ costs about a day of drinking.")
            case .aboutADayAndAHalf: return String(localized: "Bloom+ costs about a day and a half of drinking.")
            case .aboutDays(let n): return String(localized: "Bloom+ costs about \(n) days of drinking.")
            case .aboutDaysAndAHalf(let n): return String(localized: "Bloom+ costs about \(n) and a half days of drinking.")
            }
        }
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
