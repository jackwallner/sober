import SwiftData
import SwiftUI
import UIKit

/// Shows the app only on the real store. While the saved data cannot be
/// opened, the empty stand-in would read as a lost streak, so this screen
/// says the data is safe and keeps trying.
struct StoreGate: View {
    @State private var store = StoreState.shared

    var body: some View {
        Group {
            if store.status == .unavailable {
                StoreUnavailableView { reopen() }
            } else {
                RootView()
                    .modelContainer(store.container)
            }
        }
        .alert(
            noticeTitle,
            isPresented: Binding(
                get: { store.notice != nil },
                set: { if !$0 { store.notice = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.notice = nil }
        } message: {
            Text(noticeMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            reopen()
        }
    }

    private func reopen() {
        guard store.status == .unavailable, store.retry() else { return }
        SoberApp.prepareStore()
    }

    private var noticeTitle: String {
        store.notice == .recovered ? String(localized: "Your data is back") : String(localized: "Your data couldn't be read")
    }

    private var noticeMessage: String {
        if store.notice == .recovered {
            return String(localized: "Sober found your earlier sobriety date and check-ins on this iPhone and restored them.")
        }
        return String(localized: "Sober kept a copy of the unreadable file on this iPhone and started fresh. Tap Send Feedback in Settings and we'll help recover it.")
    }
}

struct StoreUnavailableView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Your data is safe")
                .font(.title2.bold())
            Text("Sober couldn't open your saved data right now. Nothing was deleted.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            Text("If this keeps happening, free up storage and restart your iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
