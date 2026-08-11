import Foundation

/// Shields, Fight attendance, and the account fields the evaluation loop owns.
enum UserRepository {

    /// PRD §2.4.
    static let shieldsPerMonth = 2
    static let shieldCeiling = 3
    static let maxConsecutiveShields = 3

    /// Grants the monthly allowance, at most once per calendar month. Keyed on
    /// `lastShieldGrantMonth` so replaying the evaluation loop can't hand out extras.
    static func grantMonthlyShields(in state: inout PersistedState, on day: String) {
        let month = Day.month(of: day)
        guard state.lastShieldGrantMonth != month else { return }
        state.shieldsAvailable = min(shieldCeiling, state.shieldsAvailable + shieldsPerMonth)
        state.lastShieldGrantMonth = month
    }

    /// PRD §2.4: activated before or during the day it covers, never retroactively.
    /// That is the entire anti-abuse mechanism, so the date check is the important line.
    @discardableResult
    static func activateShield(in state: inout PersistedState, on day: String, today: String) -> Bool {
        guard day >= today else { return false }
        guard state.shieldsAvailable > 0 else { return false }
        guard !state.shieldedDates.contains(day) else { return false }
        guard consecutiveRun(endingBefore: day, in: state) < maxConsecutiveShields else { return false }

        state.shieldsAvailable -= 1
        state.shieldedDates.insert(day)
        return true
    }

    static func isShielded(_ day: String, in state: PersistedState) -> Bool {
        state.shieldedDates.contains(day)
    }

    /// PRD §4.5 — check-in awards +10 Vitality for that day, replacing its normal delta.
    /// Recorded as a date so the evaluation loop applies it; nothing is added directly.
    static func recordFightAttendance(in state: inout PersistedState, on day: String) {
        state.fightAttendedDates.insert(day)
    }

    /// Shielded days immediately preceding `day`. Derived rather than stored (§9.7) —
    /// a counter drifts the moment a Shield is used non-consecutively.
    private static func consecutiveRun(endingBefore day: String, in state: PersistedState) -> Int {
        var count = 0
        var cursor = day
        while count < maxConsecutiveShields,
              let previous = Day.adding(-1, to: cursor),
              state.shieldedDates.contains(previous) {
            count += 1
            cursor = previous
        }
        return count
    }
}
