import XCTest
@testable import Sober

final class OnboardingPlanTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        suite = "OnboardingPlanTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testMissingOrUnknownMetadataKeepsTheLiveMonthlyButton() {
        XCTAssertEqual(OnboardingPlan.config(from: nil), .monthly)
        XCTAssertEqual(OnboardingPlan.config(from: ["onboarding_plan": "weekly"]), .monthly)
        XCTAssertEqual(OnboardingPlan.config(from: ["onboarding_plan": "split"]), .split)
        XCTAssertEqual(OnboardingPlan.kind(.monthly, defaults, coin: { true }), .monthly)
        XCTAssertEqual(OnboardingPlan.kind(.yearly, defaults, coin: { false }), .yearly)
    }

    func testSplitDealsOnceAndKeepsTheArm() {
        XCTAssertEqual(OnboardingPlan.kind(.split, defaults, coin: { true }), .yearly)
        XCTAssertEqual(OnboardingPlan.kind(.split, defaults, coin: { false }), .yearly, "kept for good")
        XCTAssertEqual(OnboardingPlan.kind(.monthly, defaults, coin: { true }), .monthly, "monthly overrides a kept arm")
    }

    func testSeenArmIsWhatTheAttributeCarries() {
        XCTAssertNil(OnboardingPlan.seenArm(defaults))
        OnboardingPlan.markSeen(.yearly, defaults)
        XCTAssertEqual(OnboardingPlan.seenArm(defaults), "yearly")
    }

    func testYearlyArmLeadsWithYearlyAndFallsBackToMonthly() {
        XCTAssertEqual(SubscriptionService.preferredTrialKind(from: [.monthly, .yearly], first: .yearly), .yearly)
        XCTAssertEqual(SubscriptionService.preferredTrialKind(from: [.monthly], first: .yearly), .monthly)
        XCTAssertEqual(SubscriptionService.preferredTrialKind(from: [.yearly, .monthly]), .monthly)
    }
}
