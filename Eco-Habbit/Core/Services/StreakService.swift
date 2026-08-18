import Foundation

/// What logging on a given day does to the streak.
nonisolated struct StreakOutcome: Equatable {
    let newStreak: Int
    /// A Shield covered the missed day.
    let usedShield: Bool
    /// The gap was too wide to cover; the streak restarted at 1.
    let didReset: Bool
}

/// The streak rule, as a pure function of the stored day and today.
///
/// **Tio's day-gap model, wired to main's Shields.** The rule that changed: a day
/// used to count only if it cleared the 30-point target, which meant a user who
/// logged one small action lost their streak anyway. Now *logging at all* keeps
/// the day, and the size of the day is what the points express.
///
/// Working in `YYYY-MM-DD` strings rather than `Date` is deliberate and matches
/// the rest of main: `localDate` is written at log time and never re-derived, so
/// somebody who logs in Bali and reopens in Dublin keeps their history.
nonisolated struct StreakService {

    let config: PointsConfiguration

    init(config: PointsConfiguration = .default) {
        self.config = config
    }

    /// Whole days between two day-strings, or `nil` if either will not parse.
    static func dayGap(from: String, to: String) -> Int? {
        guard let a = Day.date(from: from), let b = Day.date(from: to) else { return nil }
        var utc = Calendar(identifier: .iso8601)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        return utc.dateComponents([.day], from: a, to: b).day
    }

    /// The streak after logging on `day`.
    ///
    /// - no history          → start at 1
    /// - same day            → unchanged; the streak counts DAYS, not actions
    /// - one day apart       → extend
    /// - two days apart      → one missed day; a Shield on it holds the streak
    /// - three or more apart → reset, and a Shield cannot help
    ///
    /// A Shield covers exactly one day on purpose. If it covered an absence of
    /// any length, somebody could vanish for three weeks with a 60-day streak
    /// intact while decay ate their points — two systems telling the user
    /// contradictory things about the same absence.
    func outcome(lastActiveDay: String?,
                 currentStreak: Int,
                 shieldedDates: Set<String>,
                 loggingOn day: String) -> StreakOutcome {

        guard let lastActiveDay,
              let gap = Self.dayGap(from: lastActiveDay, to: day)
        else {
            return StreakOutcome(newStreak: 1, usedShield: false, didReset: false)
        }

        switch gap {
        case ..<0:
            // The stored day is in the future — the device clock was changed.
            // Leave the streak alone; punishing the user for this is wrong.
            return StreakOutcome(newStreak: currentStreak, usedShield: false, didReset: false)

        case 0:
            return StreakOutcome(newStreak: max(1, currentStreak), usedShield: false, didReset: false)

        case 1:
            return StreakOutcome(newStreak: currentStreak + 1, usedShield: false, didReset: false)

        case 2 where missedDayWasShielded(lastActiveDay: lastActiveDay, shieldedDates: shieldedDates):
            return StreakOutcome(newStreak: currentStreak + 1, usedShield: true, didReset: false)

        default:
            return StreakOutcome(newStreak: 1, usedShield: false, didReset: true)
        }
    }

    /// The streak worth **showing** right now, without changing anything.
    ///
    /// Different from the stored number: after two missed days with no Shield the
    /// stored value is still 12 when the streak is actually broken. Showing 12
    /// until the user next logs something is a lie.
    func displayStreak(lastActiveDay: String?,
                       currentStreak: Int,
                       shieldedDates: Set<String>,
                       asOf day: String) -> Int {

        guard let lastActiveDay,
              let gap = Self.dayGap(from: lastActiveDay, to: day)
        else { return 0 }

        switch gap {
        case ..<0, 0, 1:
            return currentStreak
        case 2 where missedDayWasShielded(lastActiveDay: lastActiveDay, shieldedDates: shieldedDates):
            return currentStreak
        default:
            return 0
        }
    }

    /// The single day between the last active one and today.
    private func missedDayWasShielded(lastActiveDay: String, shieldedDates: Set<String>) -> Bool {
        guard let missed = Day.adding(1, to: lastActiveDay) else { return false }
        return shieldedDates.contains(missed)
    }
}
