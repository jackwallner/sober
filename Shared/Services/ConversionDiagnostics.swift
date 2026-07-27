import Foundation
import os

enum ConversionEvent: String, CaseIterable {
    case onboardingReached
    case onboardingCompleted
    case trialOfferReached
    case trialCTATapped
    case freeVersionChosen
    case purchaseCancelled
    case purchaseFailed
    case purchasePending
    case purchaseSucceeded
}

enum ConversionDiagnostics {
    private static let logger = Logger(
        subsystem: "com.jackwallner.sober",
        category: "Conversion"
    )

    static func record(_ event: ConversionEvent) {
        let key = "conversion.\(event.rawValue)"
        AppGroup.defaults.set(AppGroup.defaults.integer(forKey: key) + 1, forKey: key)
        logger.info("Conversion event: \(event.rawValue, privacy: .public)")
    }

    #if DEBUG
    static var summary: [ConversionEvent: Int] {
        Dictionary(uniqueKeysWithValues: ConversionEvent.allCases.map { event in
            (event, AppGroup.defaults.integer(forKey: "conversion.\(event.rawValue)"))
        })
    }
    #endif
}
