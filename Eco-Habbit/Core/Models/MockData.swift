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
              requirement: .totalActions(1), icon: "b1"),
        Badge(id: "b2", name: "7-Day Streak", tier: "Streak",
              detail: "Kept your habit alive for a full week.",
              requirement: .streak(7), icon: "b2"),
        Badge(id: "b3", name: "30-Day Streak", tier: "Streak",
              detail: "Log an action every day for 30 days straight.",
              requirement: .streak(30), icon: "b3"),
        Badge(id: "b4", name: "Earth Day Hero", tier: "Seasonal",
              detail: "Available every April 22 — Earth Day.",
              requirement: .seasonal, icon: "b4"),
        Badge(id: "b5", name: "Century Club", tier: "Milestone",
              detail: "Log 100 total actions.",
              requirement: .totalActions(100), icon: "b5"),
        Badge(id: "b6", name: "Reef Guardian", tier: "Rare",
              detail: "Reach the Flourishing stage — 86 Vitality.",
              requirement: .vitality(86), icon: "b6"),
        Badge(id: "b7", name: "Groundwork", tier: "Foundation",
              detail: "Complete 3 Foundations — the one-off changes that keep paying.",
              requirement: .foundations(3), icon: "b5"),

        // One per category, all on the same 10-action threshold so the set reads as a
        // matched row rather than six separate difficulties. `icon` borrows the
        // category artwork — there are no b8–b13 badge assets yet.
        Badge(id: "b8", name: "Lights Out", tier: "Category",
              detail: "Log 10 Energy actions.",
              requirement: .categoryActions(.energy, 10), icon: HabitCategory.energy.icon),
        Badge(id: "b9", name: "Waste Not", tier: "Category",
              detail: "Log 10 Waste actions.",
              requirement: .categoryActions(.waste, 10), icon: HabitCategory.waste.icon),
        Badge(id: "b10", name: "Ripple Effect", tier: "Category",
              detail: "Log 10 Actions — the small everyday ones.",
              requirement: .categoryActions(.actions, 10), icon: HabitCategory.actions.icon),
        Badge(id: "b11", name: "Every Drop", tier: "Category",
              detail: "Log 10 Water actions.",
              requirement: .categoryActions(.water, 10), icon: HabitCategory.water.icon),
        Badge(id: "b12", name: "Free Wheeler", tier: "Category",
              detail: "Log 10 Mobility actions.",
              requirement: .categoryActions(.mobility, 10), icon: HabitCategory.mobility.icon),
        Badge(id: "b13", name: "Second Life", tier: "Category",
              detail: "Log 10 Consumption actions.",
              requirement: .categoryActions(.consumption, 10), icon: HabitCategory.consumption.icon),
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
