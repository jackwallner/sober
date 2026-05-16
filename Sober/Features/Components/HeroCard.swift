import SwiftUI

/// Shared page-top card. Every primary tab wraps its summary content in this
/// so the app reads as one product instead of five differently-styled screens.
///
/// Usage:
/// ```
/// HeroCard {
///     // any content — kept white-on-gradient for congruence
/// }
/// ```
struct HeroCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .foregroundStyle(.white)
    }
}

/// A labelled metric used inside `HeroCard` (and standalone strips). Consistent
/// typography for the "big number + caption" pattern repeated across tabs.
struct HeroStat: View {
    let value: String
    let label: String
    var tint: Color = .white

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(tint.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Neutral (non-gradient) section card used for the rest of a page's content,
/// so secondary cards are visually consistent too.
struct SectionCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.cardPadding)
            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
