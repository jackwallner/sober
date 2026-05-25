import Foundation

/// Skips passive review prompts during automated screenshot capture.
enum ScreenshotConfig {
#if DEBUG
    static let isEnabled = ProcessInfo.processInfo.environment["SOBER_SCREENSHOT_MODE"] == "1"
#else
    static let isEnabled = false
#endif
}
