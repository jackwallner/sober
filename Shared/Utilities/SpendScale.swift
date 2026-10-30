import Foundation

/// Sizes the daily spend controls to the user's currency.
///
/// The slider and stepper were fixed at 0 to 200 units, which is a real range
/// in dollars or euros and nothing at all in dong or rupees: 200 ₫ is about a
/// cent, so every money figure in Vietnam and India read near zero. `unit` is
/// a round number of local currency worth roughly one US dollar; the controls
/// keep their dollar shape (default 20, step 5, up to 200) times that unit.
/// Rough on purpose: it sizes a slider, it never converts a price.
struct SpendScale: Equatable {
    let unit: Int

    var defaultDaily: Int { 20 * unit }
    var step: Int { 5 * unit }
    var maxDaily: Int { 200 * unit }

    init(currencyCode: String?) {
        unit = Self.units[currencyCode?.uppercased() ?? ""] ?? 1
    }

    static var current: SpendScale {
        SpendScale(currencyCode: Locale.current.currency?.identifier)
    }

    /// The device locale's currency, the one the controls are labelled in.
    static var currentCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    /// Local units per US dollar, rounded to 1, 2 or 5 times a power of ten.
    /// Covers the shipped languages' regions and the larger storefronts;
    /// anything missing keeps the dollar scale.
    private static let units: [String: Int] = [
        "ARS": 1000, "BGN": 2, "BRL": 5, "CLP": 1000, "CNY": 5, "COP": 5000,
        "CZK": 20, "DKK": 5, "EGP": 50, "GEL": 2, "HKD": 10, "HUF": 500,
        "IDR": 20000, "ILS": 5, "INR": 100, "ISK": 100, "JPY": 200, "KRW": 1000,
        "KZT": 500, "MXN": 20, "MYR": 5, "NGN": 2000, "NOK": 10, "PEN": 5,
        "PHP": 50, "PKR": 200, "PLN": 5, "RON": 5, "RSD": 100, "RUB": 100,
        "SAR": 5, "AED": 5, "SEK": 10, "THB": 50, "TRY": 50, "TWD": 50,
        "UAH": 50, "VND": 20000, "ZAR": 20,
    ]
}
