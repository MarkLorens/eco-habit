import Foundation

/// PRD §9.5 — the daily pass that moves Vitality and derives the streak.
///
/// **`lastEvaluatedDate` is the last day that has been *scored*.** Today is never scored,
/// because today isn't over, so a fresh account starts with it set to yesterday. Getting
/// this invariant wrong is subtle and total: marking today as evaluated before scoring it
/// means every day is skipped on the next launch and Vitality never moves at all.
///
/// The loop is idempotent, which is why it needs no scheduler. Nine days offline runs it
/// nine times and correctly zeroes the streak; two launches a minute apart are a no-op.
enum EvaluationLoop {

    struct Result: Equatable {
        var daysScored = 0
        var vitalityDelta = 0
        var streakBroken = false
    }

    /// ponytail: bounds the loop at ~10 years so a corrupt or time-travelled date can't
    /// spin forever. Raise it if anyone ever legitimately returns after a decade.
    private static let maxDaysPerPass = 3_660

    @discardableResult
    static func evaluate(state: inout PersistedState, habits: [Habit], today: String) -> Result {
        UserRepository.grantMonthlyShields(in: &state, on: today)

        guard let lastScored = state.lastEvaluatedDate else {
            // New account: there is no history to score, and today is still in progress.
            state.lastEvaluatedDate = Day.adding(-1, to: today) ?? today
            return Result()
        }

        // Covers both "already run today" and a backward clock change. Forward-skipping
        // only damages the user's own Earth and isn't worth defending against (§9.5).
        guard lastScored < today else { return Result() }

        let vitalityBefore = state.vitality
        let streakBefore = state.streakDays
        var day = lastScored
        var scored = 0

        while scored < maxDaysPerPass, let next = Day.adding(1, to: day), next < today {
            day = next
            score(day: day, state: &state, habits: habits)
            scored += 1
        }

        state.lastEvaluatedDate = day
        return Result(
            daysScored: scored,
            vitalityDelta: state.vitality - vitalityBefore,
            streakBroken: streakBefore > 0 && state.streakDays == 0
        )
    }

    /// One elapsed day of Vitality.
    ///
    /// **No longer touches the streak.** The streak now moves when something is
    /// logged — `HabitRepository.advanceStreak` — rather than being derived here
    /// from whether the day cleared a target. Leaving both in place double-counted:
    /// logging advanced it, and then this pass advanced it again for the same day.
    ///
    /// `lastActiveDay` is likewise written at log time now, so this does not set
    /// it either; doing so would move the streak's anchor behind its back.
    private static func score(day: String, state: inout PersistedState, habits: [Habit]) {
        let shielded = state.shieldedDates.contains(day)
        let fightAttended = state.fightAttendedDates.contains(day)
        let points = HabitRepository.dailyTotal(on: day, in: state)

        state.vitality = VitalityEngine.apply(
            points: points,
            to: state.vitality,
            shielded: shielded,
            fightAttended: fightAttended,
            streak: state.streakDays
        )
    }
}
