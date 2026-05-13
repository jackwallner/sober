import Foundation
import SwiftData

@Model
final class UnlockedHealthBenefit {
    @Attribute(.unique) var benefitID: String
    var unlockedAt: Date

    init(benefitID: String, unlockedAt: Date = .now) {
        self.benefitID = benefitID
        self.unlockedAt = unlockedAt
    }
}
