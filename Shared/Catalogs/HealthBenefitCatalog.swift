import Foundation

struct HealthBenefit: Identifiable, Hashable {
    let id: String
    let hoursRequired: Double
    let title: String
    let summary: String
    let detail: String
    let sourceLabel: String
    let sourceURL: URL?

    var displayWait: String {
        if hoursRequired < 24 { return "\(Int(hoursRequired))h" }
        let days = Int(hoursRequired / 24)
        if days < 7 { return "\(days)d" }
        if days < 30 { return "\(days / 7)w" }
        if days < 365 { return "\(days / 30)mo" }
        return "\(days / 365)y"
    }
}

enum HealthBenefitCatalog {
    static let all: [HealthBenefit] = [
        HealthBenefit(
            id: "blood-alcohol-clearing",
            hoursRequired: 6,
            title: "Blood Alcohol Clearing",
            summary: "Blood alcohol level returns to zero.",
            detail: "After 6 hours, the liver finishes metabolizing the last drink and blood alcohol concentration returns to zero.",
            sourceLabel: "NIAAA · Alcohol Metabolism",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/publications/brochures-and-fact-sheets/alcohol-metabolism")
        ),
        HealthBenefit(
            id: "blood-sugar-stabilization",
            hoursRequired: 24,
            title: "Blood Sugar Stabilization",
            summary: "Insulin sensitivity begins to normalize.",
            detail: "Within 24 hours, blood sugar levels begin to normalize as the body regains its ability to regulate insulin effectively.",
            sourceLabel: "NIAAA · Alcohol & Health",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
        HealthBenefit(
            id: "rehydration",
            hoursRequired: 48,
            title: "Rehydration Complete",
            summary: "Cellular hydration restored.",
            detail: "Two days in, cells finish rehydrating, headaches subside, and skin tone improves.",
            sourceLabel: "NIAAA",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
        HealthBenefit(
            id: "sleep-quality",
            hoursRequired: 72,
            title: "Sleep Quality Improvement",
            summary: "Deeper REM cycles return.",
            detail: "After three nights, REM sleep cycles return to a healthy rhythm. Most people report more vivid dreams and easier mornings.",
            sourceLabel: "NIAAA · Alcohol & Sleep",
            sourceURL: URL(string: "https://pubs.niaaa.nih.gov/publications/arh25-2/101-109.htm")
        ),
        HealthBenefit(
            id: "mental-clarity",
            hoursRequired: 24 * 7,
            title: "Mental Clarity",
            summary: "Cognitive function sharpens.",
            detail: "By one week, many people notice sharper focus, memory, and reaction time as brain inflammation decreases. Experiences vary.",
            sourceLabel: "NIAAA",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
        HealthBenefit(
            id: "reduced-anxiety",
            hoursRequired: 24 * 14,
            title: "Reduced Anxiety",
            summary: "Nervous system rebalancing.",
            detail: "Around two weeks in, many people find anxiety eases as the nervous system rebalances. Individual experiences vary.",
            sourceLabel: "NIAAA",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
        HealthBenefit(
            id: "liver-fat-reduction",
            hoursRequired: 24 * 30,
            title: "Liver Fat Reduction",
            summary: "Hepatic steatosis improves.",
            detail: "By about a month, studies suggest liver fat can decrease and liver markers like ALT often improve. Results vary by person.",
            sourceLabel: "NIAAA · Alcohol & the Liver",
            sourceURL: URL(string: "https://pubs.niaaa.nih.gov/publications/arh27-3/277-284.htm")
        ),
        HealthBenefit(
            id: "weight-stabilization",
            hoursRequired: 24 * 30,
            title: "Weight Stabilization",
            summary: "Empty calories eliminated.",
            detail: "One month without alcohol calories typically translates to several pounds of fat loss for moderate-to-heavy drinkers.",
            sourceLabel: "CDC",
            sourceURL: URL(string: "https://www.cdc.gov/alcohol/index.html")
        ),
        HealthBenefit(
            id: "blood-pressure",
            hoursRequired: 24 * 60,
            title: "Blood Pressure Drops",
            summary: "Cardiovascular load eases.",
            detail: "By around two months, many people see blood pressure improve as the cardiovascular system recovers. Effects vary.",
            sourceLabel: "AHA",
            sourceURL: URL(string: "https://www.heart.org/en/healthy-living/healthy-eating/eat-smart/nutrition-basics/alcohol-and-heart-health")
        ),
        HealthBenefit(
            id: "cardiovascular",
            hoursRequired: 24 * 90,
            title: "Cardiovascular Improvement",
            summary: "Resting heart rate lower.",
            detail: "Three months sober, resting heart rate decreases and arterial stiffness improves.",
            sourceLabel: "AHA",
            sourceURL: URL(string: "https://www.heart.org/")
        ),
        HealthBenefit(
            id: "immune-boost",
            hoursRequired: 24 * 180,
            title: "Immune System Boost",
            summary: "Immune function improves.",
            detail: "By around six months, immune function tends to improve, and many people report getting sick less often.",
            sourceLabel: "NIAAA · Immune Function",
            sourceURL: URL(string: "https://pubs.niaaa.nih.gov/publications/arh34-4/319-323.htm")
        ),
        HealthBenefit(
            id: "skin-renewal",
            hoursRequired: 24 * 180,
            title: "Skin Renewal",
            summary: "Skin tone and hydration improve.",
            detail: "After about six months without alcohol-driven dehydration and inflammation, many people see skin tone, elasticity, and redness improve.",
            sourceLabel: "NIAAA · Alcohol & Health",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
        HealthBenefit(
            id: "full-body-recovery",
            hoursRequired: 24 * 365,
            title: "Full Body Recovery",
            summary: "Long-term health risks ease.",
            detail: "After a year, research links sustained sobriety with lower long-term risk for several alcohol-related health conditions. Talk to a doctor about your health.",
            sourceLabel: "NIAAA · Long-term Outcomes",
            sourceURL: URL(string: "https://www.niaaa.nih.gov/alcohol-health")
        ),
    ]

    static func benefit(id: String) -> HealthBenefit? {
        all.first { $0.id == id }
    }

    static func unlocked(hoursSober: Double) -> [HealthBenefit] {
        all.filter { hoursSober >= $0.hoursRequired }
    }

    static func next(after hoursSober: Double) -> HealthBenefit? {
        all.first { hoursSober < $0.hoursRequired }
    }
}
