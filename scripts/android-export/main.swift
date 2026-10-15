import AppKit
import Foundation
import SwiftUI

func colorHex(_ color: Color) -> String {
    guard let color = NSColor(color).usingColorSpace(.sRGB) else { return "#000000" }
    let red = Int((color.redComponent * 255).rounded())
    let green = Int((color.greenComponent * 255).rounded())
    let blue = Int((color.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}

func writeJSON(_ object: Any, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try (data + Data("\n".utf8)).write(to: url, options: .atomic)
}

// Elapsed time is a progress marker, not a measurement of someone's recovery.
// Keep the source IDs, thresholds and citations without exporting guarantees.
let safeMilestoneCopy: [String: (title: String, summary: String, detail: String)] = [
    "blood-alcohol-clearing": ("Alcohol metabolism", "Learn how alcohol is processed.", "Alcohol metabolism varies with the amount consumed and individual factors. A timer cannot tell you when alcohol has cleared or when it is safe to drive."),
    "blood-sugar-stabilization": ("Blood sugar context", "Learn about alcohol and blood sugar.", "Alcohol can affect blood sugar regulation. Changes after stopping differ between people; this app does not measure your blood sugar or insulin response."),
    "rehydration": ("Hydration", "Learn about alcohol and hydration.", "Alcohol can affect hydration. Your day count is not a hydration measurement or a prediction of when symptoms will change."),
    "sleep-quality": ("Sleep and alcohol", "Notice your own sleep routine.", "Alcohol can affect sleep. Some people notice changes after stopping, but the timing and experience vary. This milestone does not measure sleep or promise a recovery date."),
    "mental-clarity": ("Mental clarity", "Reflect on your own experience.", "People may notice changes in concentration after reducing or stopping alcohol. Individual experiences vary; this app does not assess cognitive function."),
    "reduced-anxiety": ("Anxiety and alcohol", "Information, not a diagnosis.", "Alcohol and anxiety can interact in different ways. This app does not assess or treat anxiety. Speak with a qualified clinician about symptoms or concerns."),
    "liver-fat-reduction": ("Liver health", "Learn about alcohol and the liver.", "Research describes links between alcohol use and liver health. Your elapsed time does not establish a change in liver fat or blood tests. Discuss your health with a clinician."),
    "weight-stabilization": ("Alcohol calories", "Understand the calories in your routine.", "The app's calorie totals use the amount you entered. They do not predict weight change, measure body fat, or account for changes in food intake."),
    "blood-pressure": ("Blood pressure information", "Learn about alcohol and heart health.", "Alcohol use can affect blood pressure, but responses and timing vary. This app does not measure blood pressure or predict when it will change."),
    "cardiovascular": ("Heart health information", "Read the cited background information.", "Alcohol use and heart health are linked in research. Your counter is not a measurement of resting heart rate, arterial function, or cardiovascular recovery."),
    "immune-boost": ("Six-Month Milestone", "A longer-term progress marker.", "Around six months, take stock of the routines and personal progress that brought you here."),
    "skin-renewal": ("Skin and hydration", "Notice changes without a promised timeline.", "Alcohol can affect hydration and skin. Changes vary between people; this milestone does not establish when a visible or medical change will occur."),
    "full-body-recovery": ("One-Year Milestone", "A year of personal progress.", "A year is a meaningful progress marker, not a declaration of full recovery. Discuss your individual health and risks with a qualified clinician."),
]

let output = CommandLine.arguments[1]
let parityOutput = CommandLine.arguments[2]
let content: [String: Any] = [
    "schemaVersion": 1,
    "healthBenefits": HealthBenefitCatalog.all.map { benefit -> [String: Any] in
        guard let copy = safeMilestoneCopy[benefit.id] else {
            fatalError("Review Android health wording for the new milestone \(benefit.id) before exporting.")
        }
        return ["id": benefit.id, "hoursRequired": benefit.hoursRequired, "title": copy.title,
                "summary": copy.summary, "detail": copy.detail, "sourceLabel": benefit.sourceLabel,
                "sourceURL": benefit.sourceURL.map { $0.absoluteString as Any } ?? NSNull()]
    },
    "achievements": AchievementCatalog.all.map { achievement -> [String: Any] in
        ["id": achievement.id, "title": achievement.title, "description": achievement.description,
         "kind": achievement.kind.rawValue, "dayThreshold": achievement.dayThreshold, "icon": achievement.icon]
    },
    "journalPrompts": JournalPromptCatalog.all.map { prompt -> [String: Any] in
        ["id": prompt.id, "kind": prompt.kind.rawValue, "text": prompt.text]
    },
    "species": GardenItemCatalog.all.map { item -> [String: Any] in
        ["id": item.id, "displayName": item.displayName, "description": item.description,
         "order": item.milestoneDays, "icon": item.sfSymbol, "colors": item.colors.map(colorHex)]
    },
    "stages": BonsaiStage.allCases.map { stage -> [String: Any] in
        ["id": stage.rawValue, "title": stage.title, "dayThreshold": stage.dayThreshold,
         "growthMessage": stage.growthMessage]
    },
    "vocabulary": [
        "substance": HabitVocabulary.substance, "habitGerund": HabitVocabulary.habitGerund,
        "habitInstance": HabitVocabulary.habitInstance, "urgeNoun": HabitVocabulary.urgeNoun,
        "urgeNounPlural": HabitVocabulary.urgeNounPlural,
        "typicalUrgeSeconds": HabitVocabulary.typicalUrgeSeconds,
        "minUrgeSeconds": HabitVocabulary.minUrgeSeconds, "maxUrgeSeconds": HabitVocabulary.maxUrgeSeconds,
        "triggers": HabitVocabulary.triggers, "reasonPlaceholder": HabitVocabulary.reasonPlaceholder,
    ],
    "coachLines": [0, 20, 35, 65, 95].map { CravingCoach.line(elapsed: $0, target: 100) },
]

let days = [-3, 0, 1, 2, 3, 6, 7, 13, 14, 29, 30, 59, 60, 89, 90, 179, 180, 364, 365, 366, 400, 730, 731, 1080]
let growth: [[String: Any]] = days.map { day in
    let cycle = GardenService.cycleProgress(forDays: day)
    return ["days": day, "dayInCycle": cycle.dayInCycle, "completed": cycle.completed,
            "stage": GardenService.stage(forDays: day).rawValue]
}
let carryover: [[String: Any]] = days.flatMap { day in
    [0, 5, 20, 364].map { inherited -> [String: Any] in
        ["days": day, "carryover": inherited,
         "treeDays": GardenService.treeDays(streakDays: day, carryover: inherited)]
    }
}
let coach: [[String: Any]] = [0, 60, 180, 600].flatMap { target in
    [0, 1, 9, 14, 15, 34, 35, 59, 60, 84, 85, 99, 100, 180, 600].map { elapsed in
        ["elapsed": elapsed, "target": target, "line": CravingCoach.line(elapsed: elapsed, target: target)]
    }
}
let parity: [String: Any] = [
    "counts": ["healthBenefits": HealthBenefitCatalog.all.count, "achievements": AchievementCatalog.all.count,
               "journalPrompts": JournalPromptCatalog.all.count, "species": GardenItemCatalog.all.count,
               "stages": BonsaiStage.allCases.count],
    "growth": growth, "carryover": carryover, "coach": coach,
]
try writeJSON(content, to: output)
try writeJSON(parity, to: parityOutput)
print("Exported \(HealthBenefitCatalog.all.count) health milestones, \(AchievementCatalog.all.count) achievements, \(JournalPromptCatalog.all.count) prompts, \(GardenItemCatalog.all.count) species and Swift parity fixtures.")
