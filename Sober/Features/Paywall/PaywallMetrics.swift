import SwiftUI

/// The paywall is one page, never two, and it has to look designed on a 4.7"
/// SE and a 6.9" Pro Max alike.
///
/// The old version fixed every block at one size and handed the difference
/// (roughly 150pt between a 6.1" phone and a 6.9" one) to three flexible
/// spacers. The spacing logic was right and the result still looked wrong: on a
/// big screen the same small cards sat marooned in cream, because slack was
/// only ever spent on air. Blocks that never grow can only be spread out.
///
/// `PaywallMetrics` inverts that. `size` says how much room this device has,
/// and every dimension on the page is a lerp between a compact value and a
/// roomy one, so type, icons, card padding, and row heights all grow together.
/// A taller screen gets a bigger page rather than a stretched one.
///
/// Three rules keep it honest:
///
///   * **The ramps are calibrated, not guessed.** `-paywallMetrics` prints the
///     page height, the stack's height, and what one gap settled at. The
///     anchors below are those measured numbers: a phone at
///     `compactPageHeight` has no slack at all, and every point above that is a
///     point the ramps are allowed to spend.
///
///   * **They deliberately underspend.** The ramps aim at about 90% of the
///     slack and the three spacers mop up the rest, because overshooting means
///     a page that scrolls and hides the trial timeline, while undershooting
///     just means slightly airier gaps.
///
///   * **Above a threshold the page shows _more_, not just bigger.** Each
///     benefit picks up its one-line detail and the list gets a section label:
///     filling a large screen with a larger version of a thin card is still a
///     thin card. That costs real height, so it is charged against the ramps
///     (`expansionCost`) rather than added on top of them — otherwise crossing
///     the threshold blows through the very slack that paid for it.
struct PaywallMetrics: Equatable {
    /// How big this device is: 0 on the shortest phone that gets a full page,
    /// 1 on the tallest. Only the expansion threshold reads this directly.
    let size: CGFloat
    /// What the ramps may actually spend, which is `size` minus whatever the
    /// expansion already took. Every `lerp` below runs on this.
    let ramp: CGFloat
    /// Each benefit shows its detail line and the card gets a section label.
    let showsExpandedBenefits: Bool
    /// The height this page was handed, kept for the `-paywallMetrics` readout.
    let pageHeight: CGFloat

    /// Measured, not guessed. `pageHeight` is the whole paywall area including
    /// the pinned purchase dock, which is what the outer `GeometryReader` sees:
    ///
    ///     iPhone SE (3rd gen)   564   — already overflows; scrolls, as before
    ///     iPhone 17e / 16 / 15  714   — 42pt of slack
    ///     iPhone 17 Pro         741   — 69pt
    ///     iPhone 16 Plus        799   — 127pt
    ///     iPhone 17 Pro Max     811   — 139pt
    ///
    /// Slack runs about a point per point of page height, so the compact anchor
    /// is the height at which it reaches zero. The span is not the largest
    /// surplus but the ramps' own total reach (~140pt at `ramp` 1) divided by
    /// the ~0.85 of the slack they are meant to spend: that is what makes
    /// `growth ≈ 0.9 × slack` fall out on every device at once instead of
    /// having to be re-tuned per phone.
    static let compactPageHeight: CGFloat = 672
    static let roomyPageHeight: CGFloat = 838

    /// Roughly what the detail lines and the section label add. Charged against
    /// the ramps so total growth stays proportional to the slack on either side
    /// of the threshold, and crossing it is a swap rather than a jump.
    static let expansionCost: CGFloat = 35
    /// Set clear of the 6.1"/6.3" cluster (`size` 0.25–0.42), which cannot
    /// afford the expansion, and below the Plus/Max cluster (0.76–0.84), which
    /// can. It must also stay above `expansionCost / span`, or the expansion
    /// would cost more than the device has to spend.
    static let expansionThreshold: CGFloat = 0.55

    /// Fallback for the states that render before a page height is known
    /// (loading, empty). They are centred rather than laid out to fill, so the
    /// compact end is the right default.
    static let compact = PaywallMetrics(pageHeight: compactPageHeight)

    /// Deliberately not a function of `DynamicTypeSize`. An earlier version
    /// damped the ramps as the type size grew, on the theory that big type had
    /// already spent the slack — but every font on this page comes from
    /// `Theme`, which builds them with `Font.system(size:)`, and those are
    /// fixed: measured at `accessibility-medium` the disclosure, the trust row
    /// and the plan titles are all the same size they are at `medium`. The
    /// damping bought nothing and cost the readers who need the room most the
    /// larger icons and the benefit detail lines. If this page ever moves to
    /// text styles, the damping comes back with it.
    init(pageHeight: CGFloat) {
        self.pageHeight = pageHeight
        let span = Self.roomyPageHeight - Self.compactPageHeight
        var size = ((pageHeight - Self.compactPageHeight) / span).clampedToUnit
        #if DEBUG
        // `-paywallT 0.35` pins the ramps, which is how a device's compact
        // content height gets measured in the first place.
        if let forced = Self.forcedSize { size = forced }
        #endif
        self.size = size

        let expanded = size >= Self.expansionThreshold
        self.showsExpandedBenefits = expanded
        self.ramp = expanded ? max(0, size - Self.expansionCost / span) : size
    }

    #if DEBUG
    private static var forcedSize: CGFloat? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-paywallT"), index + 1 < args.count,
              let value = Double(args[index + 1]) else { return nil }
        return CGFloat(value)
    }
    #endif

    /// The one primitive. `compact` is what this dimension is on the smallest
    /// phone, `roomy` what it becomes on the largest.
    func lerp(_ compact: CGFloat, _ roomy: CGFloat) -> CGFloat {
        compact + (roomy - compact) * ramp
    }

    /// Same ramp, reached later. Used for the gaps, which should be the last
    /// thing to grow: a tall screen ought to read as bigger content rather than
    /// looser content, and the gaps are already the mop-up for whatever the
    /// other ramps underspend.
    private func slowLerp(_ compact: CGFloat, _ roomy: CGFloat) -> CGFloat {
        compact + (roomy - compact) * (ramp * ramp)
    }

    func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Page rhythm

    /// Minimum gap between the four blocks, and the spacers' `minLength`, so
    /// whatever the ramps didn't spend lands here split three ways instead of
    /// pooling in one hole above the CTA.
    var blockGap: CGFloat { slowLerp(9, 20) }
    /// The most a gap is ever allowed to be. Past this the page has more slack
    /// than the ramps predicted — a missing block, an unusually short hero —
    /// and the right answer is taller cards, not wider holes.
    var maxBlockGap: CGFloat { blockGap + lerp(9, 14) }
    func stackTopPadding(hasCloseButton: Bool) -> CGFloat {
        hasCloseButton ? lerp(34, 44) : lerp(8, 18)
    }
    var horizontalGutter: CGFloat { lerp(20, 22) }
    var cardRadius: CGFloat { lerp(18, 22) }

    // MARK: - Savings hero

    var heroLineSpacing: CGFloat { lerp(2, 5) }
    var heroEyebrowSize: CGFloat { lerp(11, 12.5) }
    var heroAmountSize: CGFloat { lerp(34, 46) }
    var heroHeadlineSize: CGFloat { lerp(25, 30) }
    var heroSubheadSize: CGFloat { lerp(14.5, 16.5) }

    // MARK: - Benefit showcase

    var benefitIconSize: CGFloat { lerp(26, 33) }
    var benefitGlyphSize: CGFloat { lerp(13, 16) }
    var benefitTitleSize: CGFloat { lerp(15, 17) }
    var benefitDetailSize: CGFloat { lerp(12, 13.5) }
    var benefitRowSpacing: CGFloat { lerp(4, 8) }
    var benefitCardPaddingV: CGFloat { lerp(9, 14) }
    var benefitCardPaddingH: CGFloat { lerp(13, 18) }
    var sectionLabelSize: CGFloat { lerp(10.5, 11.5) }

    // MARK: - Plan stack

    var planSpacing: CGFloat { slowLerp(6, 10) }
    var planMinHeight: CGFloat { lerp(52, 62) }
    var planPaddingV: CGFloat { lerp(7, 11.5) }
    var planPaddingH: CGFloat { lerp(15, 18) }
    var planTitleSize: CGFloat { lerp(15, 17) }
    var planSubtitleSize: CGFloat { lerp(12, 13.5) }
    var planPriceSize: CGFloat { lerp(15, 17.5) }
    var planAnchorSize: CGFloat { lerp(12, 13.5) }
    var planBadgeSize: CGFloat { lerp(10, 10.5) }
    var planRadioSize: CGFloat { lerp(22, 26) }
    var planRadius: CGFloat { lerp(16, 20) }

    // MARK: - Trial timeline

    var timelinePaddingV: CGFloat { lerp(8, 12) }
    var timelinePaddingH: CGFloat { lerp(12, 15) }
    var timelineMarkerSize: CGFloat { lerp(28, 33) }
    var timelineGlyphSize: CGFloat { lerp(12, 14) }
    var timelineTitleSize: CGFloat { lerp(12, 13) }
    var timelineDetailSize: CGFloat { lerp(11.5, 12.5) }
    var timelineRowGap: CGFloat { lerp(6, 8) }
    var timelineColumnGap: CGFloat { lerp(5, 7) }

    // MARK: - Purchase dock

    /// The dock is the one block that must not run away with the page: it is
    /// pinned, so every point it gains is a point the scrolling content loses.
    var ctaHeight: CGFloat { lerp(52, 57) }
    var ctaTitleSize: CGFloat { lerp(17, 18.5) }
    var ctaRadius: CGFloat { lerp(16, 19) }
    var dockSpacing: CGFloat { slowLerp(8, 11) }
    var dockInnerSpacing: CGFloat { slowLerp(9, 12) }
    var disclosureSize: CGFloat { lerp(12, 12.5) }
    var trustSize: CGFloat { lerp(12, 12.5) }
    var footerSize: CGFloat { lerp(12, 12.5) }
}

private extension CGFloat {
    var clampedToUnit: CGFloat { Swift.min(1, Swift.max(0, self.isFinite ? self : 0)) }
}
