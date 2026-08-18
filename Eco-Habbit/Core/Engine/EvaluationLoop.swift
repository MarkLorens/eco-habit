import Foundation

/// The pass that runs at launch and on foreground.
///
/// **Most of what this used to do has moved to where it belongs.** It scored every
/// elapsed day: streak from whether the day cleared a 30-point target, and Vitality
/// from a per-day delta. Neither survives the friction economy —
///
///   - the streak now moves when something is **logged**
///     (`HabitRepository.advanceStreak`), so a nightly pass would double-count it
///   - Earth points **accumulate** as they are earned rather than being re-derived
///     each night from a day's total
///
/// What is genuinely periodic stays: the monthly Shield grant, and the bookkeeping
/// that stops a day being processed twice.
///
/// **`lastEvaluatedDate` is the last day that has been processed.** Today is never
/// processed, because today isn't over, so a fresh account starts it at yesterday.
/// Getting that invariant wrong is subtle and total.
///
/// Still idempotent, which is why it needs no scheduler: two launches a minute
/// apart are a no-op.
enum EvaluationLoop {

    struct Result: Equatable {
        var daysProcessed = 0
    }

    /// ponytail: bounds the loop so a corrupt or time-travelled date can't spin
    /// forever. Raise it if anyone ever legitimately returns after a decade.
    private static let maxDaysPerPass = 3_660

    @discardableResult
    static func evaluate(state: inout PersistedState, habits: [Habit], today: String) -> Result {
        UserRepository.grantMonthlyShields(in: &state, on: today)

        guard let lastProcessed = state.lastEvaluatedDate else {
            // New account: no history to process, and today is still in progress.
            state.lastEvaluatedDate = Day.adding(-1, to: today) ?? today
            return Result()
        }

        // Covers both "already run today" and a backward clock change.
        guard lastProcessed < today else { return Result() }

        var day = lastProcessed
        var processed = 0
        while processed < maxDaysPerPass, let next = Day.adding(1, to: day), next < today {
            day = next
            processed += 1
        }

        state.lastEvaluatedDate = day
        return Result(daysProcessed: processed)
    }
}
