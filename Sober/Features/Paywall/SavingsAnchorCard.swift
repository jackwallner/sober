import SwiftUI

/// Price-anchoring card: the money quitting saves over a year (struck through,
/// the "value") set against the Bloom+ price (the small number you actually pay).
/// Reads as a sale tag — "normally worth $1,800, yours for $30" — which reframes
/// the subscription as reinvesting a sliver of what the user is already saving.
///
/// Self-contained: callers pass the projected yearly savings in whole dollars and
/// the plan's price label. Renders nothing useful below ~$60/yr savings (the
/// anchor stops being dramatic), so callers should hide it when savings are 0.
struct SavingsAnchorCard: View {
    /// Projected savings over one nicotine-free year, in whole dollars.
    let yearlySavings: Int
    /// Clean price for the anchored plan, e.g. "$29.99".
    let priceLabel: String
    /// Optional caption under the price, e.g. "for a full year of Bloom+".
    var priceCaption: String = "a full year of Bloom+"
    /// True on the brand-gradient paywall (white-on-color); false on light sheets.
    var onBrand: Bool = false

    private var savingsLabel: String {
        Self.currency.string(from: NSNumber(value: yearlySavings)) ?? "$\(yearlySavings)"
    }

    private var primaryText: Color { onBrand ? .white : Theme.textPrimary }
    private var secondaryText: Color { onBrand ? .white.opacity(0.8) : Theme.textSecondary }
    private var accent: Color { onBrand ? .white : Theme.brandPrimary }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(savingsLabel)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .strikethrough(true, color: (onBrand ? Color.white : Theme.danger).opacity(0.9))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("you save this year")
                    .font(Theme.caption())
                    .foregroundStyle(secondaryText)
            }

            Image(systemName: "arrow.right")
                .font(Theme.subhead(weight: .bold))
                .foregroundStyle(accent.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text(priceLabel)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
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
        .accessibilityLabel("You save \(savingsLabel) a year. Bloom+ is \(priceLabel) for \(priceCaption).")
    }

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()
}
