import Foundation

/// Runs the latest scheduled action once, `delay` after the last `schedule`.
/// Typing into a note scheduled a SwiftData save, a widget snapshot rebuild
/// and a timeline reload per character; this turns a burst of edits into one.
@MainActor
final class DebouncedAction {
    private let delay: Duration
    private var pending: (@MainActor () -> Void)?
    private var task: Task<Void, Never>?

    init(delay: Duration = .milliseconds(700)) {
        self.delay = delay
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        pending = action
        task?.cancel()
        task = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    /// Runs a waiting action now, for when the field goes away mid-burst.
    func flush() {
        task?.cancel()
        task = nil
        guard let action = pending else { return }
        pending = nil
        action()
    }
}
