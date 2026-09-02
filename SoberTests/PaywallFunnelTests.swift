import Testing
import Foundation
@testable import Sober

/// The fleet-wide paywall record: how often someone was pitched, on which
/// screen, how early, and what the funnel looked like at the moment of sale.
/// Every assertion here is a claim that will be read off a RevenueCat customer
/// record later, so wrong values are worse than no values.
@MainActor
struct PaywallFunnelTests {

    /// A throwaway suite per test. These counters live in the App Group and
    /// would otherwise carry between tests and into the real container.
    private func withFreshSuite(_ body: () throws -> Void) rethrows {
        let name = "conv.tests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        ConversionDiagnostics.defaultsOverride = suite
        defer {
            ConversionDiagnostics.defaultsOverride = nil
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        try body()
    }

    @Test func impressionIDsAreReducedToSurfaces() throws {
        try withFreshSuite {
            #expect(ConversionDiagnostics.surface(fromImpressionID: "sober_bloom_tab") == "bloom_tab")
            // An id that did not follow the convention is kept whole rather than
            // mangled.
            #expect(ConversionDiagnostics.surface(fromImpressionID: "legacy_tab") == "legacy_tab")
        }
    }

    @Test func countsPitchesPerSurfaceAndInTotal() throws {
        try withFreshSuite {
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            ConversionDiagnostics.recordPitchView(impressionID: "sober_settings")

            let attributes = ConversionDiagnostics.subscriberAttributes
            #expect(attributes["pitch_views_total"] == "3")
            #expect(attributes["pitch_views_bloom_tab"] == "2")
            #expect(attributes["pitch_last"] == "settings")
        }
    }

    @Test func noAttributesBeforeAnyPitchIsSeen() throws {
        try withFreshSuite {
            // Someone never shown a paywall has nothing to say about paywalls.
            // Zeros would make them look like a funnel failure.
            ConversionDiagnostics.recordAppOpen()
            #expect(ConversionDiagnostics.subscriberAttributes.isEmpty)
        }
    }

    @Test func recordsHowEarlyTheFirstPitchArrived() throws {
        try withFreshSuite {
            ConversionDiagnostics.recordAppOpen()
            ConversionDiagnostics.recordAppOpen()
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")

            let attributes = ConversionDiagnostics.subscriberAttributes
            #expect(attributes["opens_before_first_pitch"] == "2")
            #expect(attributes["days_since_install"] == "0")
        }
    }

    @Test func theEarlinessPairIsFrozenOnTheFirstPitchOnly() throws {
        try withFreshSuite {
            ConversionDiagnostics.recordAppOpen()
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            ConversionDiagnostics.recordAppOpen()
            ConversionDiagnostics.recordPitchView(impressionID: "sober_settings")

            #expect(ConversionDiagnostics.subscriberAttributes["opens_before_first_pitch"] == "1")
        }
    }

    @Test func anInstallThatPredatesThisCodeReportsNoAge() throws {
        try withFreshSuite {
            // No recorded app open, so no install stamp. Absent is the honest
            // answer; zero would claim they were asked on their first day.
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            let attributes = ConversionDiagnostics.subscriberAttributes
            #expect(attributes["days_since_install"] == nil)
            #expect(attributes["pitch_views_total"] == "1")
        }
    }

    @Test func conversionFreezesTheSurfaceAndCountAtTheMomentOfSale() throws {
        try withFreshSuite {
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            ConversionDiagnostics.recordPitchView(impressionID: "sober_settings")
            ConversionDiagnostics.recordConversion(
                plan: "com.jackwallner.sober.yearly",
                startedTrial: true,
                offeringID: "default"
            )
            // A pitch after the sale must not rewrite how they converted.
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")

            let attributes = ConversionDiagnostics.subscriberAttributes
            #expect(attributes["converted_surface"] == "settings")
            #expect(attributes["pitch_views_at_convert"] == "2")
            #expect(attributes["converted_with_trial"] == "true")
            #expect(attributes["converted_offering"] == "default")
        }
    }

    @Test func onlyTheFirstConversionIsRecorded() throws {
        try withFreshSuite {
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            ConversionDiagnostics.recordConversion(plan: "monthly", startedTrial: true)
            // A renewal or plan change is not a new answer to what sold them.
            ConversionDiagnostics.recordConversion(plan: "yearly", startedTrial: false)

            let attributes = ConversionDiagnostics.subscriberAttributes
            #expect(attributes["converted_plan"] == "monthly")
            #expect(attributes["converted_with_trial"] == "true")
        }
    }

    @Test func attributeKeysStayInsideRevenueCatsLimit() throws {
        try withFreshSuite {
            // RevenueCat drops a key over 40 characters, silently.
            let long = String(repeating: "a", count: 80)
            ConversionDiagnostics.recordPitchView(impressionID: "sober_\(long)")
            for key in ConversionDiagnostics.subscriberAttributes.keys {
                #expect(key.count <= 40, "attribute key too long: \(key)")
            }
        }
    }

    @Test func theOnboardingEventCountersAreUntouched() throws {
        try withFreshSuite {
            // The paywall record was added alongside the event funnel, not in
            // place of it. Both must survive.
            ConversionDiagnostics.record(.trialOfferReached)
            ConversionDiagnostics.recordPitchView(impressionID: "sober_bloom_tab")
            #expect(ConversionDiagnostics.count(of: .trialOfferReached) >= 1)
            #expect(ConversionDiagnostics.subscriberAttributes["pitch_views_total"] == "1")
        }
    }
}
