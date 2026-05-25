import Foundation

/// App Store review deep links for Sober.
enum AppStoreReviewLinks {
    static let appStoreID = "6768869215"

    /// Opens the App Store write-review page (explicit user-initiated rating CTAs only).
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }
}
