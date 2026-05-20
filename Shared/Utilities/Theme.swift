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
    static let background = Color(.systemBackground)
    static let cardSurface = Color(.secondarySystemBackground)
    static let cardSurfaceLight = Color(.tertiarySystemBackground)
    static let ringTrack = Color(.systemFill)
    static let textPrimary = Color(.label)
    static let textSecondary = Color(.secondaryLabel)
    static let textTertiary = Color(.tertiaryLabel)
    #endif

    // Recovery palette — muted greens & warm sand
    static let brandPrimary = Color(red: 0.32, green: 0.62, blue: 0.45)   // sage green
    static let brandSecondary = Color(red: 0.48, green: 0.78, blue: 0.55) // fresh green
    static let accent = Color(red: 0.95, green: 0.78, blue: 0.45)         // warm sand
    static let streakFlame = Color(red: 1.00, green: 0.55, blue: 0.10)
    static let success = Color(red: 0.20, green: 0.72, blue: 0.45)
    static let warning = Color(red: 1.00, green: 0.70, blue: 0.20)
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)

    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 20

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

    static var skyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.68, green: 0.85, blue: 0.95), Color(red: 0.92, green: 0.96, blue: 0.86)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func bigNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
