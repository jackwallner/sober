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

    static func count(of event: ConversionEvent) -> Int {
        AppGroup.defaults.integer(forKey: "conversion.\(event.rawValue)")
    }

    /// Every non-zero counter. Not DEBUG-gated: these counts spent their whole
    /// life on-device, which made "nobody reached the offer" and "everybody
    /// reached it and said no" indistinguishable from the outside.
    /// `SubscriptionService` mirrors this onto the RevenueCat customer record so
    /// the drop-off is answerable without a device in hand.
    static var counts: [ConversionEvent: Int] {
        var result: [ConversionEvent: Int] = [:]
        for event in ConversionEvent.allCases where count(of: event) > 0 {
            result[event] = count(of: event)
        }
        return result
    }
}
