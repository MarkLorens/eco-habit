import XCTest
@testable import Eco_Habbit

/// PRD §3.3 tiers, the 30-point target and the 60-point ceiling.
final class PointsEngineTests: XCTestCase {

    private func habit(_ id: String, _ tier: Habit.Tier, _ frequency: Habit.Frequency = .daily) -> Habit {
        Habit(id: id, name: id, category: .energy, tier: tier, frequency: frequency, isCameraDetectable: false)
    }

    private func log(_ habitId: String, _ day: String = "2026-02-10") -> HabitLog {
        HabitLog(habitId: habitId, localDate: day, source: .checklist)
    }

    func testTierValues() {
        XCTAssertEqual(Habit.Tier.light.points, 5)
        XCTAssertEqual(Habit.Tier.moderate.points, 10)
        XCTAssertEqual(Habit.Tier.high.points, 20)
    }

    func testTargetAndCap() {
        XCTAssertEqual(PointsEngine.dailyTarget, 30)
        XCTAssertEqual(PointsEngine.dailyCap, 60)
    }

    /// §2.2: "three moderate habits" is exactly the target.
    func testThreeModerateHabitsMeetTheTarget() {
        let habits = [habit("a", .moderate), habit("b", .moderate), habit("c", .moderate)]
        let total = PointsEngine.dailyTotal(logs: [log("a"), log("b"), log("c")], habits: habits)
        XCTAssertEqual(total, PointsEngine.dailyTarget)
    }

    /// §3.3: "one high plus one moderate" also meets it.
    func testOneHighPlusOneModerateMeetsTheTarget() {
        let habits = [habit("a", .high), habit("b", .moderate)]
        let total = PointsEngine.dailyTotal(logs: [log("a"), log("b")], habits: habits)
        XCTAssertEqual(total, 30)
    }

    func testTotalIsCappedAtSixty() {
        let habits = (0..<10).map { habit("h\($0)", .high) }
        let logs = (0..<10).map { log("h\($0)") }
        XCTAssertEqual(PointsEngine.dailyTotal(logs: logs, habits: habits), 60)
    }

    /// §3.2: Foundations award Vitality directly and never count toward the daily target.
    func testFoundationsAreExcluded() {
        let habits = [habit("f", .high, .foundation), habit("d", .moderate)]
        let total = PointsEngine.dailyTotal(logs: [log("f"), log("d")], habits: habits)
        XCTAssertEqual(total, 10)
    }

    /// A duplicate log for the same habit must never pay twice, whatever wrote it.
    func testDuplicateLogsCountOnce() {
        let habits = [habit("a", .high)]
        XCTAssertEqual(PointsEngine.dailyTotal(logs: [log("a"), log("a")], habits: habits), 20)
    }

    func testUnknownHabitIdsAreIgnored() {
        XCTAssertEqual(PointsEngine.dailyTotal(logs: [log("ghost")], habits: [habit("a", .high)]), 0)
    }

    // MARK: - Catalogue

    /// The bundled catalogue must actually decode. A `try?` here once turned a JSON
    /// mismatch into an app with zero habits and no error anywhere.
    func testBundledCatalogueDecodes() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "habits", withExtension: "json")
                ?? Bundle.main.url(forResource: "habits", withExtension: "json")
        )
        let habits = try JSONDecoder().decode([Habit].self, from: Data(contentsOf: url))

        XCTAssertEqual(habits.count, 50, "PRD §3.6 specifies 50 habits")
        XCTAssertEqual(habits.filter(\.isFoundation).count, 7, "PRD §3.6: 43 recurring + 7 Foundations")
        XCTAssertEqual(Set(habits.map(\.id)).count, 50, "habit ids must be unique")

        for habit in habits {
            if case .weekly(let limit) = habit.frequency {
                XCTAssertGreaterThan(limit, 0, "\(habit.id) has a non-positive weekly limit")
            }
        }
    }
}
