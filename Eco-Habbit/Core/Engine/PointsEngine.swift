import Foundation

/// PRD §3.3 — tier values, the daily target, and the daily ceiling. Points exist only to
/// decide the day's Vitality delta; they never accumulate (§2.1).
enum PointsEngine {
    static let dailyTarget = 30
    static let dailyCap = 60

    static func tierPoints(_ tier: Habit.Tier) -> Int { tier.points }

    /// Points earned on one day, capped at 60 (PRD §2.2).
    ///
    /// The cap is applied here rather than at write time on purpose: the user really did
    /// the 61st point's worth of work and it belongs in their history, it just stops
    /// moving the Earth. Foundations are excluded — they pay Vitality directly (§3.2).
    static func dailyTotal(logs: [HabitLog], habits: [Habit]) -> Int {
        let byId = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var counted = Set<String>()
        var total = 0

        for log in logs where counted.insert(log.habitId).inserted {
            guard let habit = byId[log.habitId], !habit.isFoundation else { continue }
            total += habit.tier.points
        }
        return min(total, dailyCap)
    }

    /// Vitality is already 0–100, which is what the globe renders.
    static func globeHealth(vitality: Int) -> Double { Double(vitality) }
}
