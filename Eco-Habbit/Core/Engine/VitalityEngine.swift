import Foundation

/// PRD §2.3 — five visual stages. The bands are contiguous and cover the whole clamped
/// range [5, 100]; nothing else in the app maps Vitality to a look.
enum VitalityStage: Int, CaseIterable, Codable, Identifiable {
    case barren = 0
    case stirring = 1
    case recovering = 2
    case thriving = 3
    case flourishing = 4

    var id: Int { rawValue }

    var range: ClosedRange<Int> {
        switch self {
        case .barren: return 5...20
        case .stirring: return 21...40
        case .recovering: return 41...60
        case .thriving: return 61...85
        case .flourishing: return 86...100
        }
    }

    var name: String {
        switch self {
        case .barren: return "Barren"
        case .stirring: return "Stirring"
        case .recovering: return "Recovering"
        case .thriving: return "Thriving"
        case .flourishing: return "Flourishing"
        }
    }

    var blurb: String {
        switch self {
        case .barren: return "Your Earth needs you."
        case .stirring: return "The first green is showing."
        case .recovering: return "It's coming back to life."
        case .thriving: return "Oceans are blue again."
        case .flourishing: return "A planet in full bloom."
        }
    }

    static func stage(for vitality: Int) -> VitalityStage {
        allCases.last { vitality >= $0.range.lowerBound } ?? .barren
    }

    var next: VitalityStage? { VitalityStage(rawValue: rawValue + 1) }
}

/// PRD §2.2 — the daily Vitality delta table, and nothing else. Pure functions over
/// values: no storage, no SwiftUI, no dates.
enum VitalityEngine {
    static let minVitality = 5
    static let maxVitality = 100
    /// PRD §6.0 — a new account starts at Stage 2 (Stirring), not at the floor.
    static let startingVitality = 30

    static let decayPerZeroDay = 3
    static let partialDayGain = 1
    static let targetMetGain = 3
    static let streakBonus = 5
    static let streakBonusInterval = 7
    static let foundationBoost = 2
    static let fightBoost = 10

    static func clamp(_ value: Int) -> Int {
        max(minVitality, min(maxVitality, value))
    }

    /// One day's Vitality change.
    ///
    /// - Parameter streak: the streak value *after* this day has been counted, used only
    ///   for the 7-day bonus.
    ///
    /// Precedence is Shield → Fight → points, matching the order of the PRD table: a
    /// Shield zeroes the day outright, and a Fight "replaces the above for that day".
    static func dailyDelta(
        points: Int,
        shielded: Bool = false,
        fightAttended: Bool = false,
        streak: Int = 0
    ) -> Int {
        if shielded { return 0 }
        if fightAttended { return fightBoost }
        if points <= 0 { return -decayPerZeroDay }
        if points < PointsEngine.dailyTarget { return partialDayGain }

        // ponytail: PRD §2.2 says "+3, plus a one-off +5" for 7 consecutive target days
        // but doesn't say whether that repeats. Read as every 7th day of the run.
        // Change to `streak == streakBonusInterval` if the team means once-ever.
        let hitsBonus = streak > 0 && streak % streakBonusInterval == 0
        return targetMetGain + (hitsBonus ? streakBonus : 0)
    }

    static func apply(
        points: Int,
        to vitality: Int,
        shielded: Bool = false,
        fightAttended: Bool = false,
        streak: Int = 0
    ) -> Int {
        clamp(vitality + dailyDelta(
            points: points, shielded: shielded, fightAttended: fightAttended, streak: streak
        ))
    }
}
