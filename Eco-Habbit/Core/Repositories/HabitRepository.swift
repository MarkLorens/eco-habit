import Foundation

/// **The only code that writes a `HabitLog`** (PRD §9.7, §9.13.2). Every logging path —
/// checklist, dashboard card, camera chip — routes through `log`, which is what makes the
/// once-per-day rule, the weekly caps and the no-retroactive rule hold everywhere at once
/// instead of being re-implemented per screen.
enum HabitRepository {

    enum LogResult: Equatable {
        case logged(points: Int)
        /// Foundations pay Vitality directly and bypass points entirely (PRD §3.2).
        case foundation(vitalityGain: Int)
        case alreadyLogged
        case weeklyLimitReached(limit: Int)
        /// PRD §3.4 — if you didn't log it yesterday, it didn't happen.
        case retroactive

        var succeeded: Bool {
            switch self {
            case .logged, .foundation: return true
            case .alreadyLogged, .weeklyLimitReached, .retroactive: return false
            }
        }
    }

    @discardableResult
    static func log(
        _ habit: Habit,
        on day: String,
        today: String,
        source: HabitLog.Source,
        in state: inout PersistedState
    ) -> LogResult {
        guard day == today else { return .retroactive }

        switch habit.frequency {
        case .foundation:
            // Once ever, per account — not once per day.
            guard !state.logs.contains(where: { $0.habitId == habit.id }) else { return .alreadyLogged }
            append(habit, on: day, source: source, in: &state)
            state.vitality = VitalityEngine.clamp(state.vitality + VitalityEngine.foundationBoost)
            return .foundation(vitalityGain: VitalityEngine.foundationBoost)

        case .daily:
            guard !isCompleted(habit.id, on: day, in: state) else { return .alreadyLogged }
            append(habit, on: day, source: source, in: &state)
            return .logged(points: habit.tier.points)

        case .weekly(let limit):
            guard !isCompleted(habit.id, on: day, in: state) else { return .alreadyLogged }
            guard weeklyCount(habit.id, containing: day, in: state) < limit else {
                return .weeklyLimitReached(limit: limit)
            }
            append(habit, on: day, source: source, in: &state)
            return .logged(points: habit.tier.points)
        }
    }

    /// PRD §3.4 — un-logging is permitted within the same day only. Points reverse for
    /// free because they are derived from `logs`; a Foundation's Vitality has to be
    /// handed back explicitly.
    @discardableResult
    static func unlog(_ habitId: String, on day: String, today: String, habits: [Habit], in state: inout PersistedState) -> Bool {
        guard day == today,
              let log = state.logs.first(where: { $0.habitId == habitId && $0.localDate == day })
        else { return false }

        state.logs.removeAll { $0.id == log.id }

        if let habit = habits.first(where: { $0.id == habitId }), habit.isFoundation {
            state.vitality = VitalityEngine.clamp(state.vitality - VitalityEngine.foundationBoost)
        }
        return true
    }

    // MARK: - Reads

    static func dailyTotal(on day: String, habits: [Habit], in state: PersistedState) -> Int {
        PointsEngine.dailyTotal(logs: logs(on: day, in: state), habits: habits)
    }

    static func logs(on day: String, in state: PersistedState) -> [HabitLog] {
        state.logs.filter { $0.localDate == day }
    }

    static func isCompleted(_ habitId: String, on day: String, in state: PersistedState) -> Bool {
        state.logs.contains { $0.habitId == habitId && $0.localDate == day }
    }

    /// How many times this habit has been logged in the ISO week containing `day`.
    static func weeklyCount(_ habitId: String, containing day: String, in state: PersistedState) -> Int {
        guard let week = Day.isoWeek(of: day) else { return 0 }
        return state.logs.filter { $0.habitId == habitId && Day.isoWeek(of: $0.localDate) == week }.count
    }

    /// Whether the habit can still be logged on `day`, for greying out a row or a camera
    /// chip rather than hiding it (PRD §5.4 — hiding it makes the camera look broken).
    static func isAvailable(_ habit: Habit, on day: String, in state: PersistedState) -> Bool {
        switch habit.frequency {
        case .foundation:
            return !state.logs.contains { $0.habitId == habit.id }
        case .daily:
            return !isCompleted(habit.id, on: day, in: state)
        case .weekly(let limit):
            return !isCompleted(habit.id, on: day, in: state)
                && weeklyCount(habit.id, containing: day, in: state) < limit
        }
    }

    private static func append(_ habit: Habit, on day: String, source: HabitLog.Source, in state: inout PersistedState) {
        state.logs.append(HabitLog(habitId: habit.id, localDate: day, source: source))
    }
}
