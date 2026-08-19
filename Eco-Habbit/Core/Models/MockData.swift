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
              icon: "b1", type: .totalActions, threshold: 1),
        Badge(id: "b2", name: "7-Day Streak", tier: "Streak",
              detail: "Kept your habit alive for a full week.",
              icon: "b2", type: .streak, threshold: 7),
        Badge(id: "b3", name: "30-Day Streak", tier: "Streak",
              detail: "Log an action every day for 30 days straight.",
              icon: "b3", type: .streak, threshold: 30),
        Badge(id: "b4", name: "Earth Day Hero", tier: "Seasonal",
              detail: "Available every April 22 — Earth Day.",
              icon: "b4", type: .seasonal),
        Badge(id: "b5", name: "Century Club", tier: "Milestone",
              detail: "Log 100 total actions.",
              icon: "b5", type: .totalActions, threshold: 100),
        // Was "Reach the Flourishing stage — 86 Vitality". Vitality is derived
        // from points now, so the criterion is stated in the points that produce
        // it: the Flourishing threshold. Same place on the journey, said in the
        // unit the economy actually stores.
        Badge(id: "b6", name: "Reef Guardian", tier: "Rare",
              detail: "Reach the Flourishing stage.",
              icon: "b6", type: .points,
              threshold: PointsConfiguration.default.threshold(for: .flourishing)),
        // Was "Complete 3 Foundations". Foundations went with the old catalogue —
        // the friction catalogue has no zero-point band — so this keeps its name,
        // tier and artwork and becomes the early-days badge instead. Three actions
        // is deliberately reachable in one sitting.
        Badge(id: "b7", name: "Groundwork", tier: "Foundation",
              detail: "Log your first 3 actions.",
              icon: "b5", type: .totalActions, threshold: 3),

        // One per category, all on the same 10-action threshold so the set reads as a
        // matched row rather than six separate difficulties. `icon` borrows the
        // category artwork — there are no b8–b13 badge assets yet.
        Badge(id: "b8", name: "Lights Out", tier: "Category",
              detail: "Log 10 Energy actions.",
              icon: HabitCategory.energy.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .energy),
        Badge(id: "b9", name: "Waste Not", tier: "Category",
              detail: "Log 10 Waste actions.",
              icon: HabitCategory.waste.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .waste),
        Badge(id: "b10", name: "Ripple Effect", tier: "Category",
              detail: "Log 10 Actions — the small everyday ones.",
              icon: HabitCategory.actions.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .actions),
        Badge(id: "b11", name: "Every Drop", tier: "Category",
              detail: "Log 10 Water actions.",
              icon: HabitCategory.water.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .water),
        Badge(id: "b12", name: "Free Wheeler", tier: "Category",
              detail: "Log 10 Mobility actions.",
              icon: HabitCategory.mobility.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .mobility),
        Badge(id: "b13", name: "Second Life", tier: "Category",
              detail: "Log 10 Consumption actions.",
              icon: HabitCategory.consumption.icon, type: .categoryMilestone,
              threshold: 10, targetCategory: .consumption),
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
