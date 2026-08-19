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
        /// `atDailyCap` means today's base-points allowance was already spent, so this
        /// log paid **nothing**. It is still a real log — it counts for the streak, for
        /// badges, for category totals and for history — which is why it is a flag on
        /// success rather than a refusal.
        ///
        /// Carried on the case rather than inferred from `points == 0` at each call
        /// site, so a surface cannot forget: adding it here made the compiler point at
        /// every screen that shows an award, which is how the camera's "+0" was found.
        case logged(points: Int, atDailyCap: Bool)
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

        // The cap is measured in BASE points and applied before the multipliers,
        // so a long streak never makes somebody hit the ceiling sooner than a
        // new user would. See PointsCalculationService for why that ordering.
        let breakdown = points.breakdown(
            habit: habit,
            hasEvidence: source == .visualSearch,
            currentStreak: state.streakDays,
            isPrioritized: false,          // regional bonus is built but dormant
            basePointsUsedToday: basePointsUsed(on: day, in: state)
        )

        append(habit, on: day, source: source, breakdown: breakdown, in: &state)
        advanceStreak(to: day, in: &state)
        // Points accumulate. The logs stay authoritative for the day's total and
        // for history; this is the running Earth figure the stages are drawn
        // against, and it is only ever reduced by decay.
        state.currentPoints += breakdown.finalPoints
        // The absence is over, so the decay bookkeeping resets. Leaving the
        // baseline behind would measure the NEXT absence's one-stage limit from
        // a total the user has long since climbed back past.
        state.decayBaselinePoints = nil
        state.lastDecayAppliedDay = nil
        // `countedBasePoints == 0` is the honest test, not `finalPoints == 0`: it is the
        // cap clamping the base to nothing that makes the log worthless, and it does not
        // depend on the multipliers happening to round to zero.
        return .logged(points: breakdown.finalPoints,
                       atDailyCap: breakdown.countedBasePoints == 0)
    }

    /// The streak moves when something is logged, not on a nightly score.
    ///
    /// This is the rule that changed: a day used to count only if it cleared the
    /// 30-point target, so a user who logged one small action still lost their
    /// streak. Now the day counts, and the points express how big it was.
    private static func advanceStreak(to day: String, in state: inout PersistedState) {
        let outcome = streaks.outcome(lastActiveDay: state.lastActiveDay,
                                      currentStreak: state.streakDays,
                                      shieldedDates: state.shieldedDates,
                                      loggingOn: day)
        state.streakDays = outcome.newStreak
        state.longestStreak = max(state.longestStreak, outcome.newStreak)
        state.lastActiveDay = day
    }

    /// The economy. A `let` rather than a parameter because every logging path
    /// must price an action identically — a caller that could pass its own
    /// configuration is a caller that can disagree with the rest of the app.
    private static let points = PointsCalculationService()
    private static let streaks = StreakService()

    /// The streak worth showing right now, without mutating anything.
    static func displayStreak(on day: String, in state: PersistedState) -> Int {
        streaks.displayStreak(lastActiveDay: state.lastActiveDay,
                              currentStreak: state.streakDays,
                              shieldedDates: state.shieldedDates,
                              asOf: day)
    }

    /// Base points already spent against today's ceiling.
    static func basePointsUsed(on day: String, in state: PersistedState) -> Int {
        points.basePointsUsed(in: logs(on: day, in: state))
    }

    /// Un-logging is permitted within the same day only.
    ///
    /// **The refund is not optional, and it used to be missing.** The comment here
    /// claimed points reversed for free "because they are derived from `logs`", which
    /// was true once and stopped being true when `log` started doing
    /// `state.currentPoints += breakdown.finalPoints`. `currentPoints` is a stored
    /// running total — `DecayService` *subtracts* from it, so it cannot be a pure sum of
    /// the logs — and deleting a log therefore left the points it paid behind.
    ///
    /// That was an unbounded points farm, not a rounding error: toggling one checkbox
    /// on and off paid out every time, and because the daily cap is measured from the
    /// logs, undoing also handed the base-points allowance back. Five taps was 125
    /// points with zero logs on record. `tools/EconomyCheck.swift` locks it.
    ///
    /// Clamped at zero because decay can have taken `currentPoints` below what this log
    /// originally paid, and a negative Earth is not a state any of the stage maths
    /// expects.
    @discardableResult
    static func unlog(_ habitId: String, on day: String, today: String, habits: [Habit], in state: inout PersistedState) -> Bool {
        guard day == today,
              let log = state.logs.first(where: { $0.habitId == habitId && $0.localDate == day })
        else { return false }

        state.logs.removeAll { $0.id == log.id }
        state.currentPoints = max(0, state.currentPoints - log.finalPoints)
        return true
    }

    // MARK: - Reads

    static func dailyTotal(on day: String, in state: PersistedState) -> Int {
        PointsEngine.dailyTotal(logs: logs(on: day, in: state))
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

    private static func append(_ habit: Habit,
                               on day: String,
                               source: HabitLog.Source,
                               breakdown: PointsBreakdown,
                               in state: inout PersistedState) {
        state.logs.append(HabitLog(habitId: habit.id,
                                   localDate: day,
                                   source: source,
                                   breakdown: breakdown))
    }
}
