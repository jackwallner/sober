import SwiftUI

/// Price-anchoring row: the user's yearly habit spend (struck through) set against
/// either a free-trial win or a Bloom+ price. During trial pitches the right side
/// leads with free days so a glance reads "habit costs $X, try Bloom+ free."
struct SavingsAnchorCard: View {
    /// Yearly spend on the habit, in whole dollars (== projected yearly savings).
    let yearlySpend: Int
    /// Caption under the struck spend figure, e.g. "a year on pouches".
    var spendCaption: String = "a year on the habit"
    /// When set, the right side shows the free trial instead of a dollar price.
    var trialDays: Int? = nil
    /// Used when `trialDays` is nil.
    var priceLabel: String? = nil
    /// Caption under the right-side figure.
    var rightCaption: String = "a year of Bloom+"
    /// True on the brand-gradient paywall (white-on-color); false on light sheets.
    var onBrand: Bool = false

    private var spendLabel: String {
        Self.currency.string(from: NSNumber(value: yearlySpend)) ?? "$\(yearlySpend)"
    }

    private var primaryText: Color { onBrand ? .white : Theme.textPrimary }
    private var secondaryText: Color { onBrand ? .white.opacity(0.8) : Theme.textSecondary }
    private var accent: Color { onBrand ? .white : Theme.brandPrimary }

    private var rightHeadline: String {
        if let trialDays { return "\(trialDays) days free" }
        return priceLabel ?? ""
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(spendLabel)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .strikethrough(true, color: (onBrand ? Color.white : Theme.danger).opacity(0.95))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(spendCaption)
                    .font(Theme.caption())
                    .foregroundStyle(secondaryText)
            }

            Image(systemName: "arrow.right")
                .font(Theme.subhead(weight: .bold))
                .foregroundStyle(accent.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(rightHeadline)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(rightCaption)
                    .font(Theme.caption())
                    .foregroundStyle(secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(onBrand ? Color.white.opacity(0.14) : Theme.brandPrimary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke((onBrand ? Color.white : Theme.brandPrimary).opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if let trialDays {
            return "You spend \(spendLabel) \(spendCaption). Try Bloom+ free for \(trialDays) days."
        }
        return "You spend \(spendLabel) \(spendCaption). Bloom+ is \(priceLabel ?? "") \(rightCaption)."
    }

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
