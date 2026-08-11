import XCTest
@testable import Eco_Habbit

/// Guards the contract between `habit_vectors.json` and `habits.json`.
///
/// These two files are generated at different times by different people — one by
/// `ml/generate_vectors.py`, one by whoever owns catalogue content. Renaming a
/// habit id in the catalogue silently orphans its vector: the camera keeps
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

    private func loadCatalogue() throws -> [Habit] {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "habits", withExtension: "json")
                ?? Bundle.main.url(forResource: "habits", withExtension: "json")
        )
        return try JSONDecoder().decode([Habit].self, from: Data(contentsOf: url))
    }

    /// The one that matters: every vector must name a habit that exists.
    func testEveryVectorMapsToACatalogueHabit() throws {
        let payload = try loadPayload()
        let catalogueIDs = Set(try loadCatalogue().map(\.id))

        let orphans = payload.habits.map(\.id).filter { !catalogueIDs.contains($0) }
        XCTAssertTrue(
            orphans.isEmpty,
            "habit_vectors.json references ids absent from habits.json: \(orphans). "
            + "Re-run ml/generate_vectors.py."
        )
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

    /// Foundations are once-ever and mostly invisible to a camera; a vector for
    /// one is more likely a mapping mistake than a deliberate choice.
    func testNoVectorsPointAtFoundations() throws {
        let payload = try loadPayload()
        let foundations = Set(try loadCatalogue().filter(\.isFoundation).map(\.id))

        let mistakes = payload.habits.map(\.id).filter { foundations.contains($0) }
        XCTAssertTrue(mistakes.isEmpty, "vectors point at Foundation habits: \(mistakes)")
    }

    /// The classifier only reaches habits that have a vector, so the catalogue's
    /// `isCameraDetectable` flag should not promise more than ships. It may
    /// legitimately be a superset — flagged-but-unprompted habits are a backlog,
    /// not a bug — so this only reports the gap rather than failing.
    func testCameraDetectableFlagIsASupersetOfShippedVectors() throws {
        let payload = try loadPayload()
        let vectorIDs = Set(payload.habits.map(\.id))
        let catalogue = try loadCatalogue()
        let flagged = Set(catalogue.filter(\.isCameraDetectable).map(\.id))

        let vectorsWithoutFlag = vectorIDs.subtracting(flagged)
        XCTAssertTrue(
            vectorsWithoutFlag.isEmpty,
            "these have vectors but aren't flagged isCameraDetectable: \(vectorsWithoutFlag.sorted())"
        )

        let pending = flagged.subtracting(vectorIDs).sorted()
        if !pending.isEmpty {
            print("[HabitVectorsTests] \(vectorIDs.count) habits are camera-searchable; "
                  + "\(pending.count) flagged but not yet prompted: \(pending)")
        }
    }
}
