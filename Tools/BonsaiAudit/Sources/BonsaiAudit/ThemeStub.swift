import SwiftUI

/// Minimal stand-in for the app's Theme, used only by the renderer's #Preview.
enum Theme {
    static func caption(weight: Font.Weight = .regular) -> Font {
        .system(.caption, design: .rounded).weight(weight)
    }
}
