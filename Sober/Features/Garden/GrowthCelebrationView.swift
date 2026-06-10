import SwiftUI

/// Full-screen celebration shown when the user's bonsai advances to a new
/// growth stage. This is "New Growth" — the same tree they've been growing,
/// further along — not a new item unlock.
struct GrowthCelebrationView: View {
    let stage: BonsaiStage
    let style: BonsaiStyle
    /// The day within the current 365-day cycle, so the rendered tree matches
    /// exactly how it looks in the garden right now.
    let dayInCycle: Int
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var sparkle = false

    var body: some View {
        ZStack {
            // Brand cream backdrop — same surface as the rest of the app.
            Theme.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Spacer()

                // The tree at its new stage, haloed by a soft sand glow.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)],
                                center: .center, startRadius: 4, endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                        .scaleEffect(sparkle ? 1.05 : 0.95)

                    Image(systemName: "sparkle")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                        .offset(y: -120)
                        .rotationEffect(.degrees(sparkle ? 360 : 0))
                        .scaleEffect(sparkle ? 1.2 : 0.8)

                    BonsaiView(day: dayInCycle, style: style, vitality: 1.0, fill: true)
                        .frame(width: 200, height: 200)
                        .scaleEffect(appear ? 1 : 0.4)
                        .opacity(appear ? 1 : 0)
                }

                // Text card lifting off the cream on a soft shadow.
                VStack(spacing: 8) {
                    Text("New Growth")
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(stage.title)
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)

                    Text(stage.growthMessage)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(Theme.ringTrack, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .padding(.horizontal, 24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(Theme.body(weight: .semibold))
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
