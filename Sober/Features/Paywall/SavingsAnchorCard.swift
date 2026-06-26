import SwiftUI

/// Price-anchoring row: the user's *yearly habit spend* (struck through) set
/// against the Bloom+ price (the small number they actually pay). Reads as a
/// sale tag — "you already burn $1,168/yr on pouches; Bloom+ is $29.99" — which
/// makes the subscription feel trivial next to the habit it replaces.
///
/// Self-contained: callers pass the projected yearly spend in whole dollars and
/// the plan's price label. The dollar figure is the same as yearly savings (what
/// you stop spending = what you save); we frame it as *spend* so the strikethrough
/// reads as "this is what the habit costs."
struct SavingsAnchorCard: View {
    /// Yearly spend on the habit, in whole dollars (== projected yearly savings).
    let yearlySpend: Int
    /// Caption under the struck spend figure, e.g. "a year on pouches".
    var spendCaption: String = "a year on the habit"
    /// Clean price for the anchored plan, e.g. "$29.99".
    let priceLabel: String
    /// Caption under the price, e.g. "a year of Bloom+".
    var priceCaption: String = "a year of Bloom+"
    /// True on the brand-gradient paywall (white-on-color); false on light sheets.
    var onBrand: Bool = false

    private var spendLabel: String {
        Self.currency.string(from: NSNumber(value: yearlySpend)) ?? "$\(yearlySpend)"
    }

    private var primaryText: Color { onBrand ? .white : Theme.textPrimary }
    private var secondaryText: Color { onBrand ? .white.opacity(0.8) : Theme.textSecondary }
    private var accent: Color { onBrand ? .white : Theme.brandPrimary }

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
                Text(priceLabel)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(priceCaption)
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
        .accessibilityLabel("You spend \(spendLabel) \(spendCaption). Bloom+ is \(priceLabel) \(priceCaption).")
    }

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
