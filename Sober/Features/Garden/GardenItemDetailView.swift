import SwiftUI

/// Tap-to-inspect detail for any garden element.
struct GardenItemDetailView: View {
    let item: GardenItem
    let unlocked: Bool
    let currentDays: Int

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Theme.ringTrack)
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            GardenItemRenderer(
                item: item,
                scale: 2.2,
                opacity: unlocked ? 1.0 : 0.3,
                vitality: 1.0
            )
            .frame(height: 110)

            VStack(spacing: 6) {
                Text(item.displayName)
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(item.type.displayCategory)
                    .font(Theme.body(12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(item.description)
                .font(Theme.body(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            statusPill

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private var statusPill: some View {
        Group {
            if unlocked {
                Label(item.milestoneDays <= 0 ? "Earned from the start" : "Earned at day \(item.milestoneDays)",
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
            } else {
                let away = max(1, item.milestoneDays - currentDays)
                Label("Unlocks in \(away) day\(away == 1 ? "" : "s")", systemImage: "lock.fill")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .font(Theme.body(15, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            (unlocked ? Theme.success.opacity(0.15) : Theme.cardSurface),
            in: Capsule()
        )
    }
}
