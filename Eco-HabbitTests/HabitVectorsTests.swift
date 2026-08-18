import XCTest
@testable import Eco_Habbit

/// Guards the contract between `habit_vectors.json` and the activity catalogue.
///
/// These are generated at different times by different people — the vectors by
/// `ml/generate_vectors.py`, the catalogue by whoever edits `MockActivityData`.
/// Renaming an activity id silently orphans its vector: the camera keeps
/// ranking, keeps returning that id, and the chip row just never shows it. No
/// crash, no log. That is what this catches.
final class HabitVectorsTests: XCTestCase {

    private struct Payload: Decodable {
        struct Entry: Decodable { let id: String; let vec: [Float] }
        let model: String
        let dim: Int
        let habits: [Entry]
    }

    private func loadPayload() throws -> Payload {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "habit_vectors", withExtension: "json")
                ?? Bundle.main.url(forResource: "habit_vectors", withExtension: "json")
        )
        return try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
    }

    /// The one that matters: every vector must name an activity that exists.
    func testEveryVectorMapsToACatalogueActivity() throws {
        let payload = try loadPayload()
        let catalogueIDs = Set(MockActivityData.all.map(\.id))

        let orphans = payload.habits.map(\.id).filter { !catalogueIDs.contains($0) }
        XCTAssertTrue(
            orphans.isEmpty,
            "habit_vectors.json references ids absent from MockActivityData: \(orphans). "
            + "Re-run ml/generate_vectors.py."
        )
    }

    /// A vector for something the catalogue says can't be photographed is a
    /// mapping mistake — `evidenceStrength` is what decides camera eligibility.
    func testVectorsOnlyCoverCameraEligibleActivities() throws {
        let payload = try loadPayload()
        let eligible = Set(
            MockActivityData.all
                .filter(\.evidenceStrength.isCameraEligible)
                .map(\.id)
        )

        let ineligible = payload.habits.map(\.id).filter { !eligible.contains($0) }
        XCTAssertTrue(ineligible.isEmpty,
                      "vectors exist for non-camera-eligible activities: \(ineligible)")
    }

    /// The image tower emits 512 floats. A mismatch means the vectors were built
    /// with a different MobileCLIP variant, which scores plausible nonsense.
    func testVectorsAre512DimensionalAndUnitLength() throws {
        let payload = try loadPayload()

        XCTAssertEqual(payload.dim, 512)
        XCTAssertEqual(payload.model, "MobileCLIP-S2",
                       "must match the image tower in Resources/")

        for habit in payload.habits {
            XCTAssertEqual(habit.vec.count, 512, "\(habit.id) has the wrong length")

            let magnitude = sqrtf(habit.vec.reduce(0) { $0 + $1 * $1 })
            XCTAssertEqual(magnitude, 1.0, accuracy: 1e-4,
                           "\(habit.id) is not unit length — the dot product stops being a cosine")
        }
    }

    func testVectorIDsAreUnique() throws {
        let ids = try loadPayload().habits.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in habit_vectors.json")
    }

    /// Reports the backlog rather than failing: the catalogue may legitimately
    /// mark more activities photographable than have prompts written yet.
    func testCameraEligibleIsASupersetOfShippedVectors() throws {
        let vectorIDs = Set(try loadPayload().habits.map(\.id))
        let eligible = Set(
            MockActivityData.all.filter(\.evidenceStrength.isCameraEligible).map(\.id)
        )

        let pending = eligible.subtracting(vectorIDs).sorted()
        if !pending.isEmpty {
            print("[HabitVectorsTests] \(vectorIDs.count) activities are camera-searchable; "
                  + "\(pending.count) eligible but not yet prompted: \(pending)")
        }
    }
}
