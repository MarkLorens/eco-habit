import Foundation

/// PRD §7 — all criteria are counts of actions, never point totals. There is no point
/// total to threshold against.
struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tier: String
    let detail: String
    let requirement: Requirement
    let icon: String

    enum Requirement: Codable, Hashable {
        case totalActions(Int)
        case streak(Int)
        case vitality(Int)
        case categoryActions(HabitCategory, Int)
        // `foundations(Int)` was removed with the old catalogue: the friction
        // catalogue has no zero-point band, so nothing could ever satisfy it.
        // Badge b7 now uses `.totalActions`.
        case seasonal
    }
}

/// A rendered line in the activity history. **Derived, never persisted** — computed from
/// `logs` plus the catalogue (PRD §9.7). Storing it is what let the old revert-by-title
/// bug delete unrelated past entries.
struct HistoryEntry: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: HabitCategory
    let points: Int
    let date: Date
    let source: HabitLog.Source

    init(log: HabitLog, habit: Habit) {
        id = log.id
        title = habit.name
        category = habit.category
        points = habit.basePoints
        date = log.loggedAt
        source = log.source
    }
}
