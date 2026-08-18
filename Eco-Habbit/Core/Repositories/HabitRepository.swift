import Foundation

/// **The only code that writes a `HabitLog`.** Every logging path — checklist,
/// dashboard card, camera chip — routes through `log`, which is what makes the
/// once-per-day rule, the cooldowns and the no-retroactive rule hold everywhere
/// at once instead of being re-implemented per screen.
///
/// The repeat rules changed with the catalogue. There used to be three
/// frequencies — daily, weekly-with-a-limit, and foundation-once-ever. The
/// friction catalogue has one rule plus an optional gap: **every habit is
/// once per calendar day**, and some additionally sit out a cooldown of
/// `cooldownDays` afterwards. Weekly limits and foundations went with the old
/// catalogue; neither concept exists in the 38 actions.
enum HabitRepository {

    enum LogResult: Equatable {
        case logged(points: Int)
        case alreadyLogged
        /// Logged recently enough that its cooldown has not elapsed.
        case onCooldown(daysRemaining: Int)
        /// If you didn't log it yesterday, it didn't happen.
        case retroactive

        var succeeded: Bool {
            switch self {
            case .logged: return true
            case .alreadyLogged, .onCooldown, .retroactive: return false
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
        guard !isCompleted(habit.id, on: day, in: state) else { return .alreadyLogged }

        let remaining = cooldownRemaining(habit, on: day, in: state)
        guard remaining == 0 else { return .onCooldown(daysRemaining: remaining) }

        append(habit, on: day, source: source, in: &state)
        return .logged(points: habit.basePoints)
    }

    /// Un-logging is permitted within the same day only. Points reverse for free
    /// because they are derived from `logs`.
    @discardableResult
    static func unlog(_ habitId: String, on day: String, today: String, habits: [Habit], in state: inout PersistedState) -> Bool {
        guard day == today,
              let log = state.logs.first(where: { $0.habitId == habitId && $0.localDate == day })
        else { return false }

        state.logs.removeAll { $0.id == log.id }
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

    /// Cooldown days still to run before `habit` may be logged again on `day`.
    /// `0` means it is available.
    ///
    /// Derived from the logs rather than from `Habit.lastCompletedDate`: the
    /// catalogue is bundled and shared, so it carries nobody's progress. The
    /// logs are the record.
    ///
    /// Measured in whole calendar days so it does not depend on what time of day
    /// the previous log happened.
    static func cooldownRemaining(_ habit: Habit, on day: String, in state: PersistedState) -> Int {
        guard let cooldownDays = habit.cooldownDays else { return 0 }

        let previousDays = state.logs
            .filter { $0.habitId == habit.id && $0.localDate < day }
            .map(\.localDate)
        guard let mostRecent = previousDays.max(),          // YYYY-MM-DD sorts correctly
              let from = Day.date(from: mostRecent),
              let to = Day.date(from: day)
        else { return 0 }

        let elapsed = Calendar(identifier: .iso8601)
            .dateComponents([.day], from: from, to: to).day ?? 0
        return max(0, cooldownDays - elapsed)
    }

    /// Whether the habit can still be logged on `day`, for greying out a row or a
    /// camera chip rather than hiding it — hiding it makes the camera look broken.
    static func isAvailable(_ habit: Habit, on day: String, in state: PersistedState) -> Bool {
        !isCompleted(habit.id, on: day, in: state)
            && cooldownRemaining(habit, on: day, in: state) == 0
    }

    private static func append(_ habit: Habit, on day: String, source: HabitLog.Source, in state: inout PersistedState) {
        state.logs.append(HabitLog(habitId: habit.id, localDate: day, source: source))
    }
}
