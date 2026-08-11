import XCTest
@testable import Eco_Habbit

/// PRD §3.2 / §3.4 — the write rules. These live in the repository precisely so they
/// hold for every logging surface at once.
final class HabitRepositoryTests: XCTestCase {

    private let today = "2026-02-10"   // a Tuesday, ISO week 2026-W07

    private let daily = Habit(id: "d", name: "Daily", category: .energy,
                              tier: .moderate, frequency: .daily, isCameraDetectable: false)
    private let weekly = Habit(id: "w", name: "Weekly", category: .waste,
                               tier: .high, frequency: .weekly(2), isCameraDetectable: false)
    private let foundation = Habit(id: "f", name: "Foundation", category: .water,
                                   tier: .high, frequency: .foundation, isCameraDetectable: false)

    private var habits: [Habit] { [daily, weekly, foundation] }

    private func state() -> PersistedState {
        var state = PersistedState()
        state.vitality = 50
        return state
    }

    func testLoggingPaysTierPoints() {
        var s = state()
        XCTAssertEqual(
            HabitRepository.log(daily, on: today, today: today, source: .checklist, in: &s),
            .logged(points: 10)
        )
        XCTAssertEqual(HabitRepository.dailyTotal(on: today, habits: habits, in: s), 10)
    }

    func testDailyHabitIsOncePerDay() {
        var s = state()
        HabitRepository.log(daily, on: today, today: today, source: .checklist, in: &s)
        XCTAssertEqual(
            HabitRepository.log(daily, on: today, today: today, source: .visualSearch, in: &s),
            .alreadyLogged
        )
        XCTAssertEqual(s.logs.count, 1)
    }

    /// §3.4: "If you didn't log it yesterday, it didn't happen."
    func testRetroactiveLoggingIsRejected() {
        var s = state()
        XCTAssertEqual(
            HabitRepository.log(daily, on: "2026-02-09", today: today, source: .checklist, in: &s),
            .retroactive
        )
        XCTAssertTrue(s.logs.isEmpty)
    }

    // MARK: - Weekly caps (§3.2)

    func testWeeklyHabitAllowsItsLimitAcrossTheWeek() {
        var s = state()
        XCTAssertEqual(HabitRepository.log(weekly, on: "2026-02-09", today: "2026-02-09", source: .checklist, in: &s),
                       .logged(points: 20))
        XCTAssertEqual(HabitRepository.log(weekly, on: "2026-02-10", today: "2026-02-10", source: .checklist, in: &s),
                       .logged(points: 20))
        XCTAssertEqual(HabitRepository.log(weekly, on: "2026-02-11", today: "2026-02-11", source: .checklist, in: &s),
                       .weeklyLimitReached(limit: 2))
        XCTAssertEqual(s.logs.count, 2)
    }

    /// The cap is per ISO week, so crossing Sunday→Monday refills it.
    func testWeeklyCapResetsInTheNextIsoWeek() {
        var s = state()
        HabitRepository.log(weekly, on: "2026-02-12", today: "2026-02-12", source: .checklist, in: &s)
        HabitRepository.log(weekly, on: "2026-02-13", today: "2026-02-13", source: .checklist, in: &s)
        XCTAssertEqual(HabitRepository.log(weekly, on: "2026-02-14", today: "2026-02-14", source: .checklist, in: &s),
                       .weeklyLimitReached(limit: 2))

        // 2026-02-16 is the Monday that opens ISO week 2026-W08.
        XCTAssertNotEqual(Day.isoWeek(of: "2026-02-14"), Day.isoWeek(of: "2026-02-16"))
        XCTAssertEqual(HabitRepository.log(weekly, on: "2026-02-16", today: "2026-02-16", source: .checklist, in: &s),
                       .logged(points: 20))
    }

    // MARK: - Foundations (§3.2)

    func testFoundationPaysVitalityNotPoints() {
        var s = state()
        XCTAssertEqual(
            HabitRepository.log(foundation, on: today, today: today, source: .checklist, in: &s),
            .foundation(vitalityGain: 2)
        )
        XCTAssertEqual(s.vitality, 52)
        XCTAssertEqual(HabitRepository.dailyTotal(on: today, habits: habits, in: s), 0,
                       "Foundations must not count toward the daily target")
    }

    func testFoundationIsOnceEverNotOncePerDay() {
        var s = state()
        HabitRepository.log(foundation, on: today, today: today, source: .checklist, in: &s)
        XCTAssertEqual(
            HabitRepository.log(foundation, on: "2026-03-01", today: "2026-03-01", source: .checklist, in: &s),
            .alreadyLogged
        )
    }

    // MARK: - Undo (§3.4)

    func testSameDayUndoRemovesTheLog() {
        var s = state()
        HabitRepository.log(daily, on: today, today: today, source: .checklist, in: &s)
        XCTAssertTrue(HabitRepository.unlog(daily.id, on: today, today: today, habits: habits, in: &s))
        XCTAssertEqual(HabitRepository.dailyTotal(on: today, habits: habits, in: s), 0)
    }

    func testUndoOfAnEarlierDayIsRejected() {
        var s = state()
        HabitRepository.log(daily, on: "2026-02-09", today: "2026-02-09", source: .checklist, in: &s)
        XCTAssertFalse(HabitRepository.unlog(daily.id, on: "2026-02-09", today: today, habits: habits, in: &s))
        XCTAssertEqual(s.logs.count, 1)
    }

    func testUndoingAFoundationHandsBackItsVitality() {
        var s = state()
        HabitRepository.log(foundation, on: today, today: today, source: .checklist, in: &s)
        XCTAssertEqual(s.vitality, 52)
        HabitRepository.unlog(foundation.id, on: today, today: today, habits: habits, in: &s)
        XCTAssertEqual(s.vitality, 50)
    }

    // MARK: - Availability

    func testAvailabilityReflectsEachFrequencyRule() {
        var s = state()
        XCTAssertTrue(HabitRepository.isAvailable(weekly, on: today, in: s))
        HabitRepository.log(weekly, on: today, today: today, source: .checklist, in: &s)
        XCTAssertFalse(HabitRepository.isAvailable(weekly, on: today, in: s), "same day")
        XCTAssertTrue(HabitRepository.isAvailable(weekly, on: "2026-02-11", in: s), "1 of 2 used")
    }
}
