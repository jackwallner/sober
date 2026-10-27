import Foundation
import Testing
@testable import Sober

/// The string catalog compiles into one .lproj per language, and the plural
/// rules survive the trip. A key that fell back to English would still pass a
/// "not empty" check, so these compare against the catalog's own wording.
@Suite("Localization")
struct LocalizationTests {
    static let languages = ["cs", "de", "el", "es", "fi", "fr", "hi", "it", "ka", "lt", "nb", "nl", "pl", "ru", "uk", "vi"]

    private func bundle(_ language: String) -> Bundle? {
        let hosts = [Bundle.main] + Bundle.allBundles
        for host in hosts {
            if let path = host.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return nil
    }

    @Test func everyLanguageShips() {
        for language in Self.languages {
            #expect(bundle(language) != nil, "\(language).lproj is missing")
        }
    }

    @Test func russianPluralsPickTheRightForm() throws {
        let ru = try #require(bundle("ru"))
        let locale = Locale(identifier: "ru")
        #expect(String(localized: "\(1) days sober", bundle: ru, locale: locale) == "1 день трезвости")
        #expect(String(localized: "\(3) days sober", bundle: ru, locale: locale) == "3 дня трезвости")
        #expect(String(localized: "\(5) days sober", bundle: ru, locale: locale) == "5 дней трезвости")
    }

    @Test func pluralCategoryFollowsTheLanguage() throws {
        let ru = try #require(bundle("ru"))
        let locale = Locale(identifier: "ru")
        #expect(String(localized: "\(3) plural category", bundle: ru, locale: locale) == "few 3")
        #expect(String(localized: "\(5) plural category", bundle: ru, locale: locale) == "many 5")
        #expect(PluralLabel.category(1) == .one)
        #expect(PluralLabel.daysSoberTitle(12) == "Days Sober")
    }

    @Test func germanCopyIsTranslated() throws {
        let de = try #require(bundle("de"))
        #expect(String(localized: "Start my counter", bundle: de) == "Zähler starten")
        #expect(String(localized: "\(7) days free", bundle: de, locale: Locale(identifier: "de")) == "7 Tage gratis")
    }
}
