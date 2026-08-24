import Foundation

/// Which slice of history a recap covers.
///
/// Matching is a prefix test on `HabitLog.localDate` — the day string written at log
/// time and never re-derived from a timestamp (see `Day`) — so a recap always agrees
/// with the day each log was filed under, whatever timezone the reader has moved to
/// since. `YYYY-MM-DD` makes that a plain string comparison: `2026-08` is August
/// 2026 and nothing else.
nonisolated struct RecapPeriod: Hashable, Identifiable {

    /// What the screen calls this period: "All Time", "August 2026", "2026".
    let title: String

    /// The same period without its year, for places that already sit next to a card
    /// naming the year — "August" rather than "August 2026".
    let shortTitle: String

    /// `nil` matches every log; otherwise a `localDate` prefix.
    let datePrefix: String?

    var id: String { datePrefix ?? "all" }

    func contains(_ localDate: String) -> Bool {
        guard let datePrefix else { return true }
        return localDate.hasPrefix(datePrefix)
    }
}

extension RecapPeriod {

    /// Everything ever logged.
    static let allTime = RecapPeriod(title: "All Time", shortTitle: "All Time", datePrefix: nil)

    /// The calendar month `day` falls in.
    static func month(of day: String) -> RecapPeriod {
        let prefix = Day.month(of: day)
        let name = monthName(prefix)
        return RecapPeriod(title: name.map { "\($0) \(day.prefix(4))" } ?? prefix,
                           shortTitle: name ?? prefix,
                           datePrefix: prefix)
    }

    /// The calendar year `day` falls in.
    static func year(of day: String) -> RecapPeriod {
        let prefix = String(day.prefix(4))
        return RecapPeriod(title: prefix, shortTitle: prefix, datePrefix: prefix)
    }

    /// "August", in the reader's locale. Built on the spot rather than cached in a
    /// static: a `DateFormatter` is not `Sendable`, and this runs three times a screen.
    private static func monthName(_ monthPrefix: String) -> String? {
        guard let date = Day.date(from: monthPrefix + "-01") else { return nil }
        let formatter = DateFormatter()
        // `Day`'s arithmetic is UTC, so read the date back in the same zone or the
        // first of the month can format as the last of the one before.
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }
}
