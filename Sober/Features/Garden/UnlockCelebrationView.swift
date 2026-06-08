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
            // Brand cream backdrop — same surface as the rest of the app, so the
            // celebration reads as part of Bloom rather than a generic gray modal.
            Theme.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Spacer()

                // Item preview, haloed by a soft sand glow so it feels spotlit
                // on the cream without introducing a dark scrim.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0)],
                                center: .center, startRadius: 4, endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .scaleEffect(sparkle ? 1.05 : 0.95)

                    Image(systemName: "sparkle")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)
                        .offset(y: -96)
                        .rotationEffect(.degrees(sparkle ? 360 : 0))
                        .scaleEffect(sparkle ? 1.2 : 0.8)

                    GardenItemRenderer(item: item, scale: 2.0, opacity: 1.0, vitality: 1.0)
                        .frame(height: 100)
                        .scaleEffect(appear ? 1 : 0.3)
                        .rotation3DEffect(
                            .degrees(appear ? 0 : 180),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }

                // Text — a warm-white card that lifts off the cream on a soft
                // shadow, matching the Home card treatment.
                VStack(spacing: 8) {
                    Text("New Unlock")
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(item.displayName)
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.brandPrimary)

                    Text(item.description)
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(canPlace
                         ? "Placed in your garden · Day \(item.milestoneDays)"
                         : "Earned at Day \(item.milestoneDays) · Place it with Bloom+")
                        .font(Theme.caption())
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.top, 4)
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

/// Shown once when a freshly-onboarded user enters a back-dated sober date and
/// has already crossed several milestones. Instead of cycling through a stack
/// of individual celebrations (which feels like a slot machine on first run),
/// we recap everything they've already grown in a single, scannable list.
struct UnlockRecapView: View {
    let items: [GardenItem]
    let days: Int
    let onDismiss: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.accent)
                    Text("Welcome to your garden")
                        .font(Theme.title(weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("You've been sober \(days) day\(days == 1 ? "" : "s"), so you've already grown \(items.count) thing\(items.count == 1 ? "" : "s").")
                        .font(Theme.subhead())
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(items) { item in
                            HStack(spacing: 14) {
                                GardenItemRenderer(item: item, scale: 1.1, opacity: 1.0, vitality: 1.0)
                                    .frame(width: 52, height: 52)
                                    .background(Theme.cardSurfaceLight, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(Theme.subhead(weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(item.description)
                                        .font(Theme.caption())
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Text("Day \(item.milestoneDays)")
                                    .font(Theme.caption(weight: .bold))
                                    .foregroundStyle(Theme.brandPrimary)
                            }
                            .padding(12)
                            .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).stroke(Theme.ringTrack, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    // Extra trailing space so the last row scrolls fully clear
                    // of the fade mask + CTA below.
                    .padding(.bottom, 28)
                }
                .frame(maxHeight: 360)
                // Soft fade at the bottom edge so partially-visible rows look
                // intentional instead of clipped against the CTA.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                Button(action: onDismiss) {
                    Text("Start growing")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brandPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.92)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }
}
