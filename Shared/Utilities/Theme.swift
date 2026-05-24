import SwiftUI

enum Theme {
    #if os(watchOS)
    static let background = Color.black
    static let cardSurface = Color(white: 0.12)
    static let cardSurfaceLight = Color(white: 0.18)
    static let ringTrack = Color(white: 0.20)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.70)
    static let textTertiary = Color(white: 0.50)
    #else
    // D1 "Slow morning" — a designed warm-light theme. Surfaces are fixed (not
    // system-adaptive) so the brand reads the same in light/dark: a cream backdrop,
    // warm-white cards that lift on soft shadows, ink text.
    static let background = Color(red: 0.965, green: 0.937, blue: 0.878)      // cream  #F6EFE0
    static let cardSurface = Color(red: 1.000, green: 0.992, blue: 0.976)     // warm white #FFFDF9
    static let cardSurfaceLight = Color.white
    static let ringTrack = Color(red: 0.886, green: 0.851, blue: 0.792)       // warm sand-gray #E2D9CA
    static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.094)     // ink    #1A1A18
    static let textSecondary = Color(red: 0.357, green: 0.337, blue: 0.298)   // warm gray
    static let textTertiary = Color(red: 0.557, green: 0.529, blue: 0.471)
    #endif

    // D1 "Slow morning" palette — moss anchor, warm sand accent, no chromatic energy.
    static let brandPrimary = Color(red: 0.184, green: 0.357, blue: 0.271)   // moss   #2F5B45
    static let brandSecondary = Color(red: 0.310, green: 0.522, blue: 0.408) // lighter moss
    static let accent = Color(red: 0.769, green: 0.612, blue: 0.424)         // sand   #C49C6C
    static let streakFlame = Color(red: 0.851, green: 0.451, blue: 0.235)    // warm terracotta
    static let success = Color(red: 0.184, green: 0.357, blue: 0.271)        // moss
    static let warning = Color(red: 0.769, green: 0.612, blue: 0.424)        // sand
    static let danger = Color(red: 0.776, green: 0.357, blue: 0.302)         // muted terracotta

    static let cardRadius: CGFloat = 22
    static let cardPadding: CGFloat = 22

    /// Single spacing scale. Use these everywhere instead of literal padding values
    /// so cards, gutters, and rhythm stay consistent across screens.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    /// Dark scrim used on Home overlays that sit on top of the light garden gradient.
    /// Solid (not material) so legibility is the same whether the garden is bright sky
    /// or dim dusk, and identical across light/dark system appearance.
    static let gardenOverlayScrim = Color.black.opacity(0.42)

    /// Fill for the check-in button once today is logged. Darker than the active brand
    /// green so it still reads as a button (not as the surrounding gradient).
    static let checkInDoneFill = AnyShapeStyle(Color.black.opacity(0.55))

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandPrimary, brandSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Garden sky for D1: a soft morning wash that settles into the cream chrome at the
    /// horizon, so the garden and the surrounding UI feel like one continuous surface.
    static var skyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.831, green: 0.886, blue: 0.906), background],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Day counter and other hero numerals. D1 sets these in a humanist serif italic so the
    /// number reads as written in a journal rather than punched out of a tracker.
    static func bigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .serif).italic()
    }
}

extension View {
    /// Replaces the default cool system-grouped background of a `List`/`Form` with the
    /// brand cream, so scrolling screens (Health, Journal, Settings) read as the same
    /// surface as the rest of the app instead of a stock iOS settings page.
    func themedScrollBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}
