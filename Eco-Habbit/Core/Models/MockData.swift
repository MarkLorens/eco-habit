import Foundation

enum MockData {

    /// The catalogue is bundled content, not user input — if it fails to load the app is
    /// broken, so this traps rather than returning `[]`. A `try?` here previously turned
    /// a one-character JSON mismatch into an app with zero habits and no error anywhere.
    static let habits: [Habit] = {
        guard let url = Bundle.main.url(forResource: "habits", withExtension: "json") else {
            fatalError("habits.json is missing from the bundle")
        }
        do {
            return try JSONDecoder().decode([Habit].self, from: Data(contentsOf: url))
        } catch {
            fatalError("habits.json failed to decode: \(error)")
        }
    }()

    static let habitsById: [String: Habit] = Dictionary(
        uniqueKeysWithValues: habits.map { ($0.id, $0) }
    )

    static func habits(in category: HabitCategory) -> [Habit] {
        habits.filter { $0.category == category }
    }

    static let badges: [Badge] = [
        Badge(id: "b1", name: "First Step", tier: "Milestone",
              detail: "Logged your very first action.",
              requirement: .totalActions(1)),
        Badge(id: "b2", name: "7-Day Streak", tier: "Streak",
              detail: "Kept your habit alive for a full week.",
              requirement: .streak(7)),
        Badge(id: "b3", name: "30-Day Streak", tier: "Streak",
              detail: "Log an action every day for 30 days straight.",
              requirement: .streak(30)),
        Badge(id: "b4", name: "Earth Day Hero", tier: "Seasonal",
              detail: "Available every April 22 — Earth Day.",
              requirement: .seasonal),
        Badge(id: "b5", name: "Century Club", tier: "Milestone",
              detail: "Log 100 total actions.",
              requirement: .totalActions(100)),
        Badge(id: "b6", name: "Reef Guardian", tier: "Rare",
              detail: "Reach the Flourishing stage — 86 Vitality.",
              requirement: .vitality(86)),
        Badge(id: "b7", name: "Groundwork", tier: "Foundation",
              detail: "Complete 3 Foundations — the one-off changes that keep paying.",
              requirement: .foundations(3)),
    ]

    // MARK: - Fights

    /// Seeded from offsets at launch, so the demo list is never in the past (§12.1).
    static let fights: [Fight] = {
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

    static let fightsById: [String: Fight] = Dictionary(
        uniqueKeysWithValues: fights.map { ($0.id, $0) }
    )

    static let demoEmail = "made@ecohabit.app"
    static let demoPassword = "planet2026"
    static let demoName = "Made Wirawan"
}
