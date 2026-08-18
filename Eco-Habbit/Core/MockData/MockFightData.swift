import Foundation

/// Seeded Fights for the demo.
///
/// Loaded from `Resources/fights.json` with absolute ISO 8601 dates, matching
/// what the partner admin app writes.
///
/// The offsets-from-launch trick this used to rely on is gone, so **the seed
/// dates need refreshing once they pass** — a Fight is dropped from the list
/// the moment it starts.
nonisolated enum MockFightData {

    static let seeded: [Fight] = {
        guard let url = Bundle.main.url(forResource: "fights", withExtension: "json") else {
            fatalError("fights.json is missing from the bundle")
        }
        do {
            let decoder = JSONDecoder()
            // Wajib: tanpa ini strategi bawaan membaca tanggal sebagai detik
            // sejak 2001, dan seluruh file gagal di-decode.
            decoder.dateDecodingStrategy = .iso8601
            let seeds = try decoder.decode([FightSeed].self, from: Data(contentsOf: url))
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
