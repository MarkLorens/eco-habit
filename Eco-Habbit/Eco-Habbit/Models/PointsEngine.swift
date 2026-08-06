import Foundation

/// Earth stages, keyed on *cumulative* Earth Points.
nonisolated enum EarthStage: Int, CaseIterable, Codable, Identifiable {
    case critical = 0
    case earlyRecovery = 1
    case recovering = 2
    case healthy = 3
    case thriving = 4

    var id: Int { rawValue }

    var threshold: Int {
        switch self {
        case .critical: return 0
        case .earlyRecovery: return 300
        case .recovering: return 800
        case .healthy: return 1_800
        case .thriving: return 3_500
        }
    }

    var name: String {
        switch self {
        case .critical: return "Critical"
        case .earlyRecovery: return "Early Recovery"
        case .recovering: return "Recovering"
        case .healthy: return "Healthy"
        case .thriving: return "Thriving"
        }
    }

    var blurb: String {
        switch self {
        case .critical: return "Your Earth needs you."
        case .earlyRecovery: return "The first green is showing."
        case .recovering: return "It's coming back to life."
        case .healthy: return "Oceans are blue again."
        case .thriving: return "A planet in full bloom."
        }
    }

    static func stage(for earthPoints: Int) -> EarthStage {
        allCases.last { earthPoints >= $0.threshold } ?? .critical
    }

    var next: EarthStage? {
        EarthStage(rawValue: rawValue + 1)
    }
}

/// All point arithmetic in one place: multipliers, bonuses and decay.
nonisolated enum PointsEngine {

    /// Streak multiplier, capped at 2x from day 30.
    static func streakMultiplier(streakDays: Int) -> Double {
        switch streakDays {
        case ..<7: return 1.0
        case 7..<14: return 1.25
        case 14..<30: return 1.5
        default: return 2.0
        }
    }

    /// Evidence bonus sits in the middle of the 20–30% band.
    static let evidenceBonusRate = 0.25

    /// "1", "1.25", "1.5", "2" — never "1.2", which is what `%g` would give for 1.25.
    static func multiplierLabel(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// Points actually credited for one logged action.
    static func award(basePoints: Int, streakDays: Int, hasEvidence: Bool) -> Int {
        let withEvidence = Double(basePoints) * (hasEvidence ? 1 + evidenceBonusRate : 1)
        let multiplied = withEvidence * streakMultiplier(streakDays: streakDays)
        return Int(multiplied.rounded())
    }

    /// What an action *would* be worth — used for the "+N pts" labels.
    static func preview(basePoints: Int, streakDays: Int) -> Int {
        award(basePoints: basePoints, streakDays: streakDays, hasEvidence: false)
    }

    // MARK: - Globe health

    /// Maps Earth Points onto the 0–100 the globe renders. Floored at 8 so a fresh
    /// account picks up exactly where the onboarding story animation left off.
    static func globeHealth(earthPoints: Int) -> Double {
        let top = Double(EarthStage.thriving.threshold)
        let ratio = min(1, max(0, Double(earthPoints) / top))
        return 8 + 92 * ratio
    }

    // MARK: - Decay

    /// Warn the user once they hit this many days without a logged action.
    static let inactivityWarningDays = 5
    /// Earth Points lost per full inactive week, once decay kicks in.
    static let weeklyDecayRate = 0.075

    /// How many full inactive weeks have elapsed. Decay only starts after a week.
    static func decayWeeks(daysInactive: Int) -> Int {
        max(0, daysInactive / 7)
    }

    static func decayed(earthPoints: Int, weeks: Int) -> Int {
        guard weeks > 0 else { return earthPoints }
        let factor = pow(1 - weeklyDecayRate, Double(weeks))
        return max(0, Int((Double(earthPoints) * factor).rounded()))
    }
}
