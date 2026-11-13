import SwiftUI

extension View {
    /// Caps content at a readable width and centres it. Phones are narrower
    /// than every cap, so this only changes an iPad or a wide window.
    func readableColumn(_ width: CGFloat = 560) -> some View {
        frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}
