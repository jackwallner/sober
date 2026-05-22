import SwiftUI

/// Full-screen celebration overlay shown when a new garden item is unlocked.
struct UnlockCelebrationView: View {
    let item: GardenItem
    /// True when the user can actually place this item right now. Drives the
    /// copy so free users don't feel bait-and-switched when an item celebrates
    /// but lives behind a Bloom+ gate.
    var canPlace: Bool = true
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var sparkle = false

    var body: some View {
        ZStack {
            // Opaque backdrop — tap anywhere to dismiss.
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Spacer()

                // Sparkle icon
                Image(systemName: "sparkle")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.accent)
                    .rotationEffect(.degrees(sparkle ? 360 : 0))
                    .scaleEffect(sparkle ? 1.2 : 0.8)

                // Item preview
                GardenItemRenderer(item: item, scale: 2.0, opacity: 1.0, vitality: 1.0)
                    .frame(height: 100)
                    .scaleEffect(appear ? 1 : 0.3)
                    .rotation3DEffect(
                        .degrees(appear ? 0 : 180),
                        axis: (x: 0, y: 1, z: 0)
                    )

                // Text — opaque card panel so it doesn't fight bright OLED
                // garden colors behind the backdrop.
                VStack(spacing: 8) {
                    Text("New Unlock!")
                        .font(.title.bold())
                        .foregroundStyle(Theme.textPrimary)

                    Text(item.displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.brandPrimary)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(canPlace
                         ? "Placed in your garden · Day \(item.milestoneDays)"
                         : "Earned at Day \(item.milestoneDays) · Place it with Bloom+")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandPrimary)
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                sparkle = true
            }
        }
    }
}
