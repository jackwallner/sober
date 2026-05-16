import SwiftUI

/// Full-screen celebration overlay shown when a new garden item is unlocked.
struct UnlockCelebrationView: View {
    let item: GardenItem
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var sparkle = false
    @State private var dismissable = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

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

                // Text
                VStack(spacing: 8) {
                    Text("New Unlock!")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text(item.displayName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.accent)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Day \(item.milestoneDays) Milestone")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                Spacer()

                // Dismiss button
                if dismissable {
                    Button(action: onDismiss) {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandPrimary)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appear = true
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                sparkle = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { dismissable = true }
            }
        }
    }
}
