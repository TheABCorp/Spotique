import Foundation

extension Int {
    /// Format cents as a currency string (e.g. 500 → "$5.00").
    var currencyString: String {
        let decimal = Decimal(self) / 100
        return decimal.formatted(.currency(code: "USD"))
    }

    /// Format cents as a short rate string (e.g. 500 → "$5/hr").
    var hourlyRateString: String {
        let dollars = self / 100
        return "$\(dollars)/hr"
    }
}
