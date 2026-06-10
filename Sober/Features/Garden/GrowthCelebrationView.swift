import SwiftUI

/// Full-screen celebration for garden growth events. Stage advances show the
/// user's tree as it looks right now ("New Growth"). A completed 365-day
/// cycle shows the finished tree and explains the grove handoff — without
/// this, the year rollover silently swaps a legendary tree for a seed.
struct GrowthCelebrationView: View {
    let event: GardenGrowthEvent
    let style: BonsaiStyle
    /// The day within the current 365-day cycle, so the rendered tree matches
    /// exactly how it looks in the garden right now.
    let dayInCycle: Int
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var sparkle = false

    /// A completed tree is shown fully grown — the tree being celebrated is
    /// the one that just finished, not the fresh sapling that replaced it.
    private var renderDay: Int {
        if case .treeCompleted = event { return 365 }
        return dayInCycle
    }

    private var headline: String {
        switch event {
        case .newStage: return "New Growth"
        case .treeCompleted: return "A Full Year"
        }
    }

    private var brandLine: String {
        switch event {
        case .newStage(let stage): return stage.title
        case .treeCompleted: return "Your tree joins the grove"
        }
    }

    private var message: String {
        switch event {
        case .newStage(let stage):
            return stage.growthMessage
        case .treeCompleted(let total):
            return total <= 1
                ? "365 days of growth, complete. Your tree now stands in your grove, and a fresh sapling begins beside it."
                : "365 days of growth, complete. That's \(total) trees in your grove — and a fresh sapling begins."
        }
    }

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

                    BonsaiView(day: renderDay, style: style, vitality: 1.0, fill: true)
                        .frame(width: 200, height: 200)
                        .scaleEffect(appear ? 1 : 0.4)
                        .opacity(appear ? 1 : 0)
                }

                // Text card lifting off the cream on a soft shadow.
                VStack(spacing: 8) {
                    Text(headline)
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(brandLine)
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)

                    Text(message)
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
