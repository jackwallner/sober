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
    case remindersStepReached
    case remindersGranted
    case remindersDeclined
}

enum ConversionDiagnostics {
    private static let logger = Logger(
        subsystem: "com.jackwallner.sober",
        category: "Conversion"
    )

    static func record(_ event: ConversionEvent) {
        let key = "conversion.\(event.rawValue)"
        // `defaults` rather than `AppGroup.defaults` directly, so a test suite
        // override covers the event counters too and cannot stamp on the real
        // shared container.
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        logger.info("Conversion event: \(event.rawValue, privacy: .public)")
    }

    static func count(of event: ConversionEvent) -> Int {
        defaults.integer(forKey: "conversion.\(event.rawValue)")
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

    // MARK: - Paywall funnel (fleet-wide contract)
    //
    // The event counters above answer "where did they drop out of onboarding".
    // These answer a different question: how many times were they shown a
    // paywall, on which screen, how early, and what did the funnel look like at
    // the moment of sale. Both are cheap and neither replaces the other.
    //
    // The key names and formats below are identical in every app in the fleet on
    // purpose, so one query reads the whole portfolio. Do not rename them here.
    // Nothing recorded may be health data, free text, or anything the user
    // typed: counts, dates, and short surface names only.

    /// Overridable so tests get their own suite instead of stamping on the real
    /// counters in the shared App Group container.
    nonisolated(unsafe) static var defaultsOverride: UserDefaults?

    private static var defaults: UserDefaults {
        defaultsOverride ?? AppGroup.defaults
    }

    /// Impression ids carry an app prefix that says nothing once the attributes
    /// are already grouped under this app's customer record.
    private static let impressionPrefix = "sober_"

    private enum PitchKey {
        static let totalViews = "conv.pitchViews.total"
        static let firstSeen = "conv.pitchFirstSeen"
        static let lastSurface = "conv.pitchLastSurface"
        static func views(_ surface: String) -> String { "conv.pitchViews.\(surface)" }

        static let installedAt = "conv.installedAt"
        static let appOpens = "conv.appOpens"
        static let opensBeforeFirstPitch = "conv.opensBeforeFirstPitch"
        static let daysSinceInstallAtFirstPitch = "conv.daysToFirstPitch"

        static let convertedOn = "conv.convertedOn"
        static let convertedAt = "conv.convertedAt"
        static let viewsAtConvert = "conv.viewsAtConvert"
        static let daysToConvert = "conv.daysToConvert"
        static let convertedPlan = "conv.convertedPlan"
        static let convertedWithTrial = "conv.convertedWithTrial"
        static let convertedOffering = "conv.convertedOffering"
    }

    static func surface(fromImpressionID id: String) -> String {
        id.hasPrefix(impressionPrefix) ? String(id.dropFirst(impressionPrefix.count)) : id
    }

    /// One app launch. Stamps the install date on the very first call, which is
    /// the closest thing to an install timestamp available without a server.
    ///
    /// An install that predates this code has no stamp, so its first launch
    /// after updating becomes day zero. `days_since_install` is therefore only
    /// trustworthy for installs that started on a build containing this file,
    /// which is why it is omitted rather than zeroed when the stamp is missing.
    static func recordAppOpen() {
        let d = defaults
        if d.object(forKey: PitchKey.installedAt) == nil {
            d.set(Date.now.timeIntervalSince1970, forKey: PitchKey.installedAt)
        }
        d.set(d.integer(forKey: PitchKey.appOpens) + 1, forKey: PitchKey.appOpens)
    }

    /// One pitch was put in front of the user.
    ///
    /// The "how early were they asked" pair is frozen on the first pitch only. A
    /// customer who sees a paywall on day 30 has not retroactively been asked on
    /// day 30 if the first ask was on day one.
    static func recordPitchView(impressionID: String) {
        let surface = surface(fromImpressionID: impressionID)
        let d = defaults
        d.set(d.integer(forKey: PitchKey.totalViews) + 1, forKey: PitchKey.totalViews)
        d.set(d.integer(forKey: PitchKey.views(surface)) + 1, forKey: PitchKey.views(surface))
        d.set(surface, forKey: PitchKey.lastSurface)
        if d.object(forKey: PitchKey.firstSeen) == nil {
            d.set(Date.now.timeIntervalSince1970, forKey: PitchKey.firstSeen)
            d.set(d.integer(forKey: PitchKey.appOpens), forKey: PitchKey.opensBeforeFirstPitch)
            if let installed = installDate {
                let days = Calendar.current.dateComponents([.day], from: installed, to: .now).day ?? 0
                d.set(max(0, days), forKey: PitchKey.daysSinceInstallAtFirstPitch)
            }
        }
        logger.info("Pitch view: \(surface, privacy: .public) (total \(d.integer(forKey: PitchKey.totalViews)))")
    }

    /// A purchase went through. Freezes what the funnel looked like at that
    /// moment, so later views cannot rewrite the story of how they converted.
    /// Only the first conversion counts: a renewal or plan change is not a new
    /// answer to "what sold this person".
    static func recordConversion(
        plan: String,
        startedTrial: Bool,
        offeringID: String? = nil
    ) {
        let d = defaults
        guard d.string(forKey: PitchKey.convertedOn) == nil else { return }
        d.set(d.string(forKey: PitchKey.lastSurface) ?? "unknown", forKey: PitchKey.convertedOn)
        d.set(d.integer(forKey: PitchKey.totalViews), forKey: PitchKey.viewsAtConvert)
        d.set(plan, forKey: PitchKey.convertedPlan)
        d.set(startedTrial, forKey: PitchKey.convertedWithTrial)
        if let offeringID { d.set(offeringID, forKey: PitchKey.convertedOffering) }
        d.set(Date.now.timeIntervalSince1970, forKey: PitchKey.convertedAt)
        if let first = firstSeenDate {
            let days = Calendar.current.dateComponents([.day], from: first, to: .now).day ?? 0
            d.set(max(0, days), forKey: PitchKey.daysToConvert)
        }
        logger.info("Conversion on \(d.string(forKey: PitchKey.convertedOn) ?? "?", privacy: .public) after \(d.integer(forKey: PitchKey.viewsAtConvert)) pitches")
    }

    static var totalPitchViews: Int { defaults.integer(forKey: PitchKey.totalViews) }
    static var lastSurface: String? { defaults.string(forKey: PitchKey.lastSurface) }
    static var appOpens: Int { defaults.integer(forKey: PitchKey.appOpens) }

    static var firstSeenDate: Date? {
        let stamp = defaults.double(forKey: PitchKey.firstSeen)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    static var installDate: Date? {
        let stamp = defaults.double(forKey: PitchKey.installedAt)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    static var viewsBySurface: [String: Int] {
        var result: [String: Int] = [:]
        let prefix = "conv.pitchViews."
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            let surface = String(key.dropFirst(prefix.count))
            guard surface != "total", let count = value as? Int, count > 0 else { continue }
            result[surface] = count
        }
        return result
    }

    /// The paywall record as RevenueCat subscriber attributes. Keys stay under
    /// RevenueCat's 40-character limit and values are plain strings, which is all
    /// that API accepts.
    ///
    /// Empty until the first pitch: someone who has never been shown a paywall
    /// has nothing to say about paywalls, and sending zeros would make them
    /// indistinguishable from a customer the funnel genuinely failed.
    static var subscriberAttributes: [String: String] {
        var attributes: [String: String] = [:]
        let d = defaults

        let total = totalPitchViews
        guard total > 0 else { return attributes }
        attributes["pitch_views_total"] = String(total)
        for (surface, count) in viewsBySurface {
            let key = "pitch_views_\(surface)"
            attributes[String(key.prefix(40))] = String(count)
        }
        if let last = lastSurface { attributes["pitch_last"] = last }
        if let first = firstSeenDate {
            attributes["pitch_first_seen"] = ISO8601DateFormatter().string(from: first)
            let days = Calendar.current.dateComponents([.day], from: first, to: .now).day ?? 0
            attributes["days_since_first_pitch"] = String(max(0, days))
        }
        if d.object(forKey: PitchKey.daysSinceInstallAtFirstPitch) != nil {
            attributes["days_since_install"] = String(d.integer(forKey: PitchKey.daysSinceInstallAtFirstPitch))
        }
        if d.object(forKey: PitchKey.opensBeforeFirstPitch) != nil {
            attributes["opens_before_first_pitch"] = String(d.integer(forKey: PitchKey.opensBeforeFirstPitch))
        }
        if let convertedOn = d.string(forKey: PitchKey.convertedOn) {
            attributes["converted_surface"] = convertedOn
            let stamp = d.double(forKey: PitchKey.convertedAt)
            if stamp > 0 {
                attributes["converted_at"] = ISO8601DateFormatter()
                    .string(from: Date(timeIntervalSince1970: stamp))
            }
            attributes["pitch_views_at_convert"] = String(d.integer(forKey: PitchKey.viewsAtConvert))
            attributes["days_to_convert"] = String(d.integer(forKey: PitchKey.daysToConvert))
            attributes["converted_plan"] = d.string(forKey: PitchKey.convertedPlan) ?? "unknown"
            attributes["converted_with_trial"] = d.bool(forKey: PitchKey.convertedWithTrial) ? "true" : "false"
            if let offering = d.string(forKey: PitchKey.convertedOffering) {
                attributes["converted_offering"] = offering
            }
        }
        return attributes
    }

    #if DEBUG
    /// Test seam. The counters outlive a launch.
    static func resetPitchRecord() {
        let d = defaults
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("conv.") {
            d.removeObject(forKey: key)
        }
    }
    #endif
}
