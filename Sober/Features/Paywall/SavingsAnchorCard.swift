import SwiftUI

/// Savings-first price anchor: leads with money the user *keeps* sober, then
/// contrasts that win against the Bloom+ trial or price. The habit spend figure
/// is reframed as "in your pocket" — not a struck-through cost tag.
struct SavingsAnchorCard: View {
    /// Projected yearly savings (== yearly habit spend avoided), whole dollars.
    let yearlySpend: Int
    /// Habit noun for the context line, e.g. "alcohol" or "pouches".
    var habitName: String = "the habit"
    /// When set, the right side shows the free trial instead of a dollar price.
    var trialDays: Int? = nil
    /// Used when `trialDays` is nil.
    var priceLabel: String? = nil
    /// Caption under the right-side figure.
    var rightCaption: String = "full Bloom+ access"
    /// True on the brand-gradient paywall (white-on-color); false on light sheets.
    var onBrand: Bool = false

    private var savingsLabel: String {
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("YOUR SAVINGS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.1)
            }
            .foregroundStyle(accent.opacity(0.9))

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("You keep")
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(accent)
                    Text(savingsLabel)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("in your pocket each year")
                        .font(Theme.caption())
                        .foregroundStyle(secondaryText)
                    Text("not spent on \(habitName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(secondaryText.opacity(0.85))
                }

                Image(systemName: "arrow.right")
                    .font(Theme.subhead(weight: .bold))
                    .foregroundStyle(accent.opacity(0.75))
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Try Bloom+")
                        .font(Theme.caption(weight: .semibold))
                        .foregroundStyle(accent)
                    Text(rightHeadline)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(rightCaption)
                        .font(Theme.caption())
                        .foregroundStyle(secondaryText)
                }

                Spacer(minLength: 0)
            }
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
            return "You keep \(savingsLabel) in your pocket each year not spent on \(habitName). Try Bloom+ free for \(trialDays) days."
        }
        return "You keep \(savingsLabel) in your pocket each year. Bloom+ is \(priceLabel ?? "") \(rightCaption)."
    }

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
