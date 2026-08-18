import Foundation

/// The daily target and the daily ceiling.
///
/// **Being replaced.** `PointsCalculationService` is the friction-based engine
/// this is handing over to; what is left here is the day's raw base-point total,
/// which the views still read. The tier table went with `Habit.Tier` — base
/// points now come off the habit itself, where a retune of the friction table
/// cannot rewrite what a past log was already worth.
enum PointsEngine {
    static let dailyTarget = 30
    static let dailyCap = 60

    /// Base points earned on one day, before any multiplier, capped.
    ///
    /// The cap is applied here rather than at write time on purpose: the user
    /// really did the work past the ceiling and it belongs in their history, it
    /// just stops moving the Earth.
    static func dailyTotal(logs: [HabitLog], habits: [Habit]) -> Int {
        let byId = Dictionary(habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var counted = Set<String>()
        var total = 0

        for log in logs where counted.insert(log.habitId).inserted {
            guard let habit = byId[log.habitId] else { continue }
            total += habit.basePoints
        }
        return min(total, dailyCap)
    }

    /// Vitality is already 0–100, which is what the globe renders.
    static func globeHealth(vitality: Int) -> Double { Double(vitality) }
}
