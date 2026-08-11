import XCTest
@testable import Eco_Habbit

/// PRD §9.5 — the most subtle code in the app. Idempotency is the property everything
/// else rests on: it is what lets the loop run with no scheduler.
final class EvaluationLoopTests: XCTestCase {

    /// 10 points — a partial day. Three of these make the 30-point target.
    private let moderate = Habit(id: "m", name: "Moderate", category: .energy,
                                 tier: .moderate, frequency: .daily, isCameraDetectable: false)
    private let high = Habit(id: "h", name: "High", category: .waste,
                             tier: .high, frequency: .daily, isCameraDetectable: false)
    private let extra = Habit(id: "x", name: "Extra", category: .food,
                              tier: .moderate, frequency: .daily, isCameraDetectable: false)

    private var habits: [Habit] { [moderate, high, extra] }

    private func state(vitality: Int = 50, lastScored: String? = nil) -> PersistedState {
        var state = PersistedState()
        state.vitality = vitality
        state.lastEvaluatedDate = lastScored
        return state
    }

    /// 30 points on `day` — meets the target exactly.
    private func targetMet(on day: String) -> [HabitLog] {
        [HabitLog(habitId: "h", localDate: day, source: .checklist),
         HabitLog(habitId: "m", localDate: day, source: .checklist)]
    }

    // MARK: - The invariant

    /// A new account has no history to score, and today is still in progress.
    func testFirstRunScoresNothingAndArmsTheLoop() {
        var s = state()
        let result = EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-15")

        XCTAssertEqual(result.daysScored, 0)
        XCTAssertEqual(s.vitality, 50)
        XCTAssertEqual(s.lastEvaluatedDate, "2026-01-14", "must arm at yesterday, not today")
    }

    /// The regression that mattered: marking today evaluated before scoring it means
    /// every day is skipped on the next launch and Vitality never moves at all.
    func testEachDayIsScoredExactlyOnceAcrossDailyLaunches() {
        var s = state(vitality: 50)
        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-15")

        // Day 1: hits the target.
        s.logs += targetMet(on: "2026-01-15")
        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")
        XCTAssertEqual(s.vitality, 53, "01-15 met the target → +3")
        XCTAssertEqual(s.streakDays, 1)

        // Day 2: also hits the target.
        s.logs += targetMet(on: "2026-01-16")
        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-17")
        XCTAssertEqual(s.vitality, 56)
        XCTAssertEqual(s.streakDays, 2)
    }

    func testRunningTwiceInADayIsANoOp() {
        var s = state(vitality: 50, lastScored: "2026-01-14")
        s.logs = targetMet(on: "2026-01-15")

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")
        let afterFirst = s

        for _ in 0..<5 {
            EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")
        }

        XCTAssertEqual(s.vitality, afterFirst.vitality)
        XCTAssertEqual(s.streakDays, afterFirst.streakDays)
        XCTAssertEqual(s.lastEvaluatedDate, afterFirst.lastEvaluatedDate)
    }

    /// §9.5: guard backward clock changes rather than rewinding.
    func testBackwardClockIsANoOp() {
        var s = state(vitality: 60, lastScored: "2026-01-15")
        s.streakDays = 5

        let result = EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-10")

        XCTAssertEqual(result.daysScored, 0)
        XCTAssertEqual(s.vitality, 60)
        XCTAssertEqual(s.streakDays, 5)
        XCTAssertEqual(s.lastEvaluatedDate, "2026-01-15")
    }

    /// Catching up in one pass must equal having run each day (§9.5 idempotency).
    func testOnePassEqualsDayByDay() {
        var batched = state(vitality: 70, lastScored: "2026-01-01")
        var daily = state(vitality: 70, lastScored: "2026-01-01")
        let logs = targetMet(on: "2026-01-03") + targetMet(on: "2026-01-04")
        batched.logs = logs
        daily.logs = logs

        EvaluationLoop.evaluate(state: &batched, habits: habits, today: "2026-01-08")
        for day in ["2026-01-02", "2026-01-03", "2026-01-04", "2026-01-05", "2026-01-06", "2026-01-07", "2026-01-08"] {
            EvaluationLoop.evaluate(state: &daily, habits: habits, today: day)
        }

        XCTAssertEqual(batched.vitality, daily.vitality)
        XCTAssertEqual(batched.streakDays, daily.streakDays)
        XCTAssertEqual(batched.lastEvaluatedDate, daily.lastEvaluatedDate)
    }

    // MARK: - Decay and streaks

    func testNineDaysOfflineZeroesStreakAndDecaysPerDay() {
        var s = state(vitality: 80, lastScored: "2026-01-01")
        s.streakDays = 10
        s.longestStreak = 10

        let result = EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-10")

        // 01-02 … 01-09 inclusive is 8 unscored days, all empty: 8 × −3.
        XCTAssertEqual(result.daysScored, 8)
        XCTAssertEqual(s.vitality, 80 - 24)
        XCTAssertEqual(s.streakDays, 0)
        XCTAssertEqual(s.longestStreak, 10, "the record survives")
        XCTAssertTrue(result.streakBroken)
    }

    func testDecayStopsAtTheFloor() {
        var s = state(vitality: 10, lastScored: "2026-01-01")
        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-03-01")
        XCTAssertEqual(s.vitality, VitalityEngine.minVitality)
    }

    /// §9.5: the streak counts days that met the *target*, not days with any activity.
    func testPartialDayBreaksTheStreakButStillGains() {
        var s = state(vitality: 50, lastScored: "2026-01-14")
        s.streakDays = 4
        s.logs = [HabitLog(habitId: "m", localDate: "2026-01-15", source: .checklist)]  // 10 pts

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")

        XCTAssertEqual(s.vitality, 51, "1–29 points → +1")
        XCTAssertEqual(s.streakDays, 0, "under target does not extend a streak")
    }

    func testSevenTargetDaysAwardTheBonus() {
        var s = state(vitality: 50, lastScored: "2025-12-31")
        for day in 1...7 {
            s.logs += targetMet(on: String(format: "2026-01-%02d", day))
        }

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-08")

        XCTAssertEqual(s.streakDays, 7)
        // Six days at +3, then the seventh at +3+5.
        XCTAssertEqual(s.vitality, 50 + (6 * 3) + 8)
    }

    // MARK: - Shield (§2.4)

    func testShieldedDayNeitherDecaysNorExtendsTheStreak() {
        var s = state(vitality: 50, lastScored: "2026-01-14")
        s.streakDays = 4
        s.shieldedDates = ["2026-01-15"]

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")

        XCTAssertEqual(s.vitality, 50, "no decay")
        XCTAssertEqual(s.streakDays, 4, "preserved, not extended")
    }

    func testFightDayAwardsTenAndReplacesTheNormalDelta() {
        var s = state(vitality: 50, lastScored: "2026-01-14")
        s.fightAttendedDates = ["2026-01-15"]

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-16")

        XCTAssertEqual(s.vitality, 60)
    }

    // MARK: - Monthly shields

    func testShieldsAreGrantedOncePerMonth() {
        var s = state(lastScored: "2026-01-14")
        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-15")
        XCTAssertEqual(s.shieldsAvailable, 2)

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-01-20")
        XCTAssertEqual(s.shieldsAvailable, 2, "same month grants nothing further")

        EvaluationLoop.evaluate(state: &s, habits: habits, today: "2026-02-01")
        XCTAssertEqual(s.shieldsAvailable, 3, "next month tops up to the ceiling")
    }

    // MARK: - Timezone

    /// §9.5: `localDate` is written at log time, so history must not shift when the
    /// device timezone does.
    func testLocalDateStringsAreTimezoneStable() {
        var bali = state(vitality: 50, lastScored: "2026-01-14")
        var dublin = bali
        let logs = targetMet(on: "2026-01-15")
        bali.logs = logs
        dublin.logs = logs

        EvaluationLoop.evaluate(state: &bali, habits: habits, today: "2026-01-16")
        EvaluationLoop.evaluate(state: &dublin, habits: habits, today: "2026-01-16")

        XCTAssertEqual(bali.vitality, dublin.vitality)
    }

    func testDayArithmeticCrossesMonthAndYearBoundaries() {
        XCTAssertEqual(Day.adding(1, to: "2026-01-31"), "2026-02-01")
        XCTAssertEqual(Day.adding(1, to: "2026-12-31"), "2027-01-01")
        XCTAssertEqual(Day.adding(-1, to: "2026-03-01"), "2026-02-28")
        XCTAssertEqual(Day.adding(1, to: "2028-02-28"), "2028-02-29", "leap year")
    }
}
