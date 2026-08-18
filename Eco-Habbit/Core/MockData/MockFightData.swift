import Foundation

/// Seeded Fights for the demo.
///
/// Loaded from `Resources/fights.json` as **offsets from launch**, not absolute
/// dates. Absolute dates in seed data go stale — a week after writing them the
/// whole list is in the past and the exhibit demo shows an empty screen. `f1`
/// is offset −1h over 10h, so there is always one Fight with an open check-in
/// window, which is what §12.1's booth demo needs.
nonisolated enum MockFightData {

    static let seeded: [Fight] = {
        guard let url = Bundle.main.url(forResource: "fights", withExtension: "json") else {
            fatalError("fights.json is missing from the bundle")
        }
        do {
            let seeds = try JSONDecoder().decode([FightSeed].self, from: Data(contentsOf: url))
            return seeds.map { $0.materialise() }
        } catch {
            fatalError("fights.json failed to decode: \(error)")
        }
    }()

    static let byId: [String: Fight] = Dictionary(
        uniqueKeysWithValues: seeded.map { ($0.id, $0) }
    )

    static func fight(withID id: String) -> Fight? { byId[id] }

    /// Mirrors the `validate()` convention the other mock tables use: report
    /// problems rather than assert, so previews never crash.
    static func validate() -> [String] {
        var problems: [String] = []
        if seeded.isEmpty { problems.append("no seeded fights") }
        if !seeded.contains(where: { $0.isCheckInOpen() }) {
            problems.append("no fight has an open check-in window — the §12.1 demo dead-ends")
        }
        if seeded.contains(where: { !$0.isDemo }) {
            problems.append("seeded fights must all be labelled isDemo")
        }
        return problems
    }
}
