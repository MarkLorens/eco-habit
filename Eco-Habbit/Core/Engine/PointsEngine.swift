import Foundation

/// What the day's rings read against.
///
/// **Mostly handed over.** `PointsCalculationService` now owns pricing; the two
/// numbers left here are the progress denominators the dashboard draws, and they
/// come from `PointsConfiguration` so there is one place to retune the economy.
enum PointsEngine {

    /// A good day. Not a limit — the ring simply fills at this point.
    ///
    /// Left at main's value. The friction economy has no "target" concept of its
    /// own, and moving this would change what the dashboard ring reads without
    /// anybody deciding to.
    static let dailyTarget = 30

    /// The base-point ceiling for one day.
    static var dailyCap: Int { PointsConfiguration.default.dailyBasePointsCap }

    /// Points earned on one day, as they were awarded.
    ///
    /// Summed from the logs rather than recomputed from the catalogue: each log
    /// froze its own multipliers at the moment it was made, and the cap was
    /// already applied there. Re-deriving here would let today's streak restate
    /// what yesterday was worth.
    static func dailyTotal(logs: [HabitLog]) -> Int {
        var counted = Set<String>()
        var total = 0
        for log in logs where counted.insert(log.habitId).inserted {
            total += log.finalPoints
        }
        return total
    }

    /// Vitality is already 0–100, which is what the globe renders.
    static func globeHealth(vitality: Int) -> Double { Double(vitality) }
}
