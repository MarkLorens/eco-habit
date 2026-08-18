import XCTest
@testable import Eco_Habbit

/// The catalogue moved from a Swift literal to `Resources/activities.json` so
/// content edits stop being code edits. The compiler no longer checks it, so
/// these do.
final class ActivityCatalogueTests: XCTestCase {

    func testCatalogueDecodesAndMatchesTheDocumentedShape() {
        let all = MockActivityData.all

        XCTAssertEqual(all.count, 38, "the table is 38 rows, whatever the spec says")
        XCTAssertEqual(Set(all.map(\.id)).count, 38, "activity ids must be unique")
        XCTAssertTrue(all.allSatisfy { !$0.name.isEmpty }, "every activity needs a name")
    }

    /// The per-category split Tio documented in the file header. A miscounted
    /// category is invisible in the app — the grid just shows fewer rows.
    func testPerCategoryCounts() {
        let expected: [Eco_Habbit.Category: Int] = [
            .foodConsumption: 8, .water: 6, .wasteManagement: 7,
            .energy: 6, .mobility: 6, .actions: 5,
        ]
        for (category, count) in expected {
            XCTAssertEqual(MockActivityData.activities(in: category).count, count,
                           "\(category.rawValue) should have \(count) activities")
        }
    }

    /// `basePoints` is omitted from the JSON wherever it equals the friction
    /// default, so this also proves the decoder's fallback works.
    func testBasePointsMatchFrictionLevel() {
        for activity in MockActivityData.all {
            XCTAssertEqual(
                activity.basePoints, activity.frictionLevel.basePoints,
                "\(activity.id) has basePoints \(activity.basePoints) but is \(activity.frictionLevel.rawValue)"
            )
        }
    }

    /// A `0` cooldown is a typo for "no cooldown" — `nil` is how that's spelled.
    func testCooldownsArePositiveOrAbsent() {
        for activity in MockActivityData.all {
            if let cooldown = activity.cooldownDays {
                XCTAssertGreaterThan(cooldown, 0, "\(activity.id) should use nil, not 0")
            }
        }
        // The two Tio set deliberately.
        XCTAssertEqual(MockActivityData.activity(withID: "water_fix_leaking_tap")?.cooldownDays, 30)
        XCTAssertEqual(MockActivityData.activity(withID: "waste_repair_instead_replace")?.cooldownDays, 7)
    }

    /// The catalogue carries definition only — progress belongs to a user.
    func testCatalogueCarriesNoUserProgress() {
        for activity in MockActivityData.all {
            XCTAssertFalse(activity.hasEvidence, "\(activity.id) ships with progress attached")
            XCTAssertNil(activity.lastCompletedDate, "\(activity.id) ships with progress attached")
        }
    }

    /// `validate()` is the in-app health check; previews rely on it not crashing.
    func testValidateReportsNoProblems() {
        XCTAssertEqual(MockActivityData.validate(), [])
    }
}
