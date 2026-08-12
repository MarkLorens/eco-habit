import XCTest
@testable import Eco_Habbit

/// PRD §2.2 delta table and §2.3 stage bands, asserted against the spec.
final class VitalityEngineTests: XCTestCase {

    // MARK: - Clamp (§2.2: never zero, never past 100)

    func testClampsToFloorAndCeiling() {
        XCTAssertEqual(VitalityEngine.clamp(0), 5)
        XCTAssertEqual(VitalityEngine.clamp(-10), 5)
        XCTAssertEqual(VitalityEngine.clamp(150), 100)
        XCTAssertEqual(VitalityEngine.clamp(50), 50)
    }

    // MARK: - Delta table

    func testZeroPointsDecays() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 0), -3)
    }

    func testPartialDayGainsOne() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 1), 1)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 29), 1)
    }

    func testTargetMetGainsThree() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, streak: 1), 3)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 60, streak: 3), 3)
    }

    /// "30+ for 7 consecutive days → +3, plus a one-off +5 bonus."
    func testSeventhConsecutiveTargetDayAddsBonus() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, streak: 7), 8)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, streak: 14), 8)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, streak: 6), 3)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, streak: 8), 3)
    }

    /// "Attended a Fight → +10 (replaces the above for that day)."
    func testFightReplacesTheDayDelta() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 0, fightAttended: true), 10)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, fightAttended: true, streak: 7), 10)
    }

    /// §2.4: "One Shield forces that day's Vitality delta to 0."
    func testShieldZeroesTheDayAndOutranksEverything() {
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 0, shielded: true), 0)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 30, shielded: true, streak: 7), 0)
        XCTAssertEqual(VitalityEngine.dailyDelta(points: 0, shielded: true, fightAttended: true), 0)
    }

    func testApplyClampsAtBothEnds() {
        XCTAssertEqual(VitalityEngine.apply(points: 0, to: 6), 5)
        XCTAssertEqual(VitalityEngine.apply(points: 60, to: 99, streak: 1), 100)
        XCTAssertEqual(VitalityEngine.apply(points: 30, to: 50, streak: 1), 53)
    }

    // MARK: - Stages (§2.3 — five of them)

    func testFiveStages() {
        XCTAssertEqual(VitalityStage.allCases.count, 5)
    }

    func testStageBandsMatchSpec() {
        XCTAssertEqual(VitalityStage.barren.range, 5...20)
        XCTAssertEqual(VitalityStage.stirring.range, 21...40)
        XCTAssertEqual(VitalityStage.recovering.range, 41...60)
        XCTAssertEqual(VitalityStage.thriving.range, 61...85)
        XCTAssertEqual(VitalityStage.flourishing.range, 86...100)
    }

    func testStageBoundaries() {
        for stage in VitalityStage.allCases {
            XCTAssertEqual(VitalityStage.stage(for: stage.range.lowerBound), stage)
            XCTAssertEqual(VitalityStage.stage(for: stage.range.upperBound), stage)
        }
    }

    /// The bands must tile [5, 100] with no gap — a gap silently shows the wrong Earth.
    func testStagesCoverTheWholeClampedRange() {
        for vitality in VitalityEngine.minVitality...VitalityEngine.maxVitality {
            XCTAssertTrue(
                VitalityStage.stage(for: vitality).range.contains(vitality),
                "Vitality \(vitality) fell outside its own stage"
            )
        }
    }

    /// §6.0 — a new account starts at Stirring, not at the floor.
    func testNewAccountStartsAtStirring() {
        XCTAssertEqual(VitalityStage.stage(for: VitalityEngine.startingVitality), .stirring)
    }
}
