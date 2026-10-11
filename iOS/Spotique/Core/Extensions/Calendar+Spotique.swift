import Foundation

extension Calendar {
    /// The Spotique market calendar — America/New_York, used for
    /// availability schedules and countdown formatting.
    static let spotique: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = MarketTime.zone
        return calendar
    }()
}

enum MarketTime {
    static let zone = TimeZone(identifier: "America/New_York")!
}
