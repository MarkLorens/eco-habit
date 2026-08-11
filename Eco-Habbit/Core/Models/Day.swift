import Foundation

/// Calendar-day arithmetic on plain `YYYY-MM-DD` strings.
///
/// PRD §9.5: `localDate` is written at log time and never re-derived from a timestamp,
/// so a user who logs in Bali and reopens in Dublin keeps their history. That makes the
/// string the unit of work, not `Date` — and zero-padded `YYYY-MM-DD` sorts correctly
/// with plain `<`, which is what the evaluation loop relies on.
enum Day {

    /// Arithmetic runs in UTC so `string → date → string` is pure calendar maths with no
    /// DST or offset surprises. This calendar never sees the user's timezone.
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// The user's current local day. This is the one place the device timezone is read —
    /// PRD §3.4: the boundary is local midnight in the device's *current* timezone.
    static func today(_ now: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return format(year: parts.year, month: parts.month, day: parts.day) ?? ""
    }

    static func date(from day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func string(from date: Date) -> String? {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return format(year: parts.year, month: parts.month, day: parts.day)
    }

    static func adding(_ days: Int, to day: String) -> String? {
        guard let date = date(from: day),
              let shifted = utc.date(byAdding: .day, value: days, to: date) else { return nil }
        return string(from: shifted)
    }

    /// ISO-week key, e.g. `2026-W07`. Weekly habit caps are per ISO week (PRD §3.2),
    /// so the year has to come from `yearForWeekOfYear` — week 1 of 2027 can fall in
    /// December 2026, and keying on the calendar year would split it in half.
    static func isoWeek(of day: String) -> String? {
        guard let date = date(from: day) else { return nil }
        let parts = utc.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let year = parts.yearForWeekOfYear, let week = parts.weekOfYear else { return nil }
        return String(format: "%04d-W%02d", year, week)
    }

    /// `YYYY-MM` — the granularity the monthly Shield allowance is granted at.
    static func month(of day: String) -> String { String(day.prefix(7)) }

    private static func format(year: Int?, month: Int?, day: Int?) -> String? {
        guard let year, let month, let day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
