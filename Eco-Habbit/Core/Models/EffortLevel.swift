import Foundation

/// What the third onboarding question asks for: how much effort the user is willing
/// to spend on a suggested action.
///
/// **Three answers over four friction bands**, deliberately. F1–F4 is the economy's
/// scale and it is not something to ask a user about directly — "F3" means nothing to
/// anybody. `moderate` therefore sits *between* F2 and F3 rather than pretending to
/// pick one of them, which is what `frictionCentre` encodes.
nonisolated enum EffortLevel: String, Codable, CaseIterable, Identifiable {
    case easy
    case moderate
    case challenging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        }
    }

    /// Sub-label for the onboarding card. Describes the commitment, not the points —
    /// the number is the economy's business and would only invite optimising.
    var caption: String {
        switch self {
        case .easy: return "Small things that fit around what you already do"
        case .moderate: return "A bit of planning, nothing drastic"
        case .challenging: return "Worth the effort, and priced that way"
        }
    }

    /// Where this answer sits on the F1–F4 scale.
    var frictionCentre: Double {
        switch self {
        case .easy: return 1
        case .moderate: return 2.5
        case .challenging: return 4
        }
    }

    /// How well a friction band matches this answer: `1` for a direct hit, tapering
    /// toward `0` three bands away.
    ///
    /// **A ranking weight, never a filter.** The catalogue has empty cells — mobility
    /// has no F1 and no F4, energy nothing above F2 — so "Energy + Mobility, and I want
    /// a challenge" has an exact intersection of two habits, both needing a bicycle. A
    /// hard filter on effort returns an empty screen for answers real users will give.
    /// Scoring degrades instead: the best available fit still wins, it just wins by
    /// less.
    func fit(_ friction: FrictionLevel) -> Double {
        max(0, 1 - abs(Double(friction.rank) - frictionCentre) / 3)
    }
}

extension FrictionLevel {

    /// 1…4, ascending with effort.
    ///
    /// A restatement rather than a new fact: `CaseIterable` declares the cases in
    /// order and `basePoints` climbs with them. Derived from the case order so it
    /// cannot drift from the enum the way a hand-written table would.
    var rank: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}
