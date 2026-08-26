import Foundation

/// Which number is compared against `Badge.threshold`.
///
/// Tio's badge model: one numeric threshold plus a type saying what to measure,
/// so the whole evaluator is a single function and adding a badge is data, not
/// code.
///
/// `totalActions` and `seasonal` are **additions to his set**. His catalogue has
/// no badge counting logged actions and none that unlocks on a date, but main's
/// thirteen include four that do — First Step, Century Club, Groundwork and Earth
/// Day Hero. Dropping them to match his enum exactly would have thrown away badge
/// content and artwork that already exists.
nonisolated enum BadgeType: String, Codable, CaseIterable {
    /// Number of actions logged, all categories.
    case totalActions
    case streak
    /// Actions in one category; requires `targetCategory`.
    case categoryMilestone
    /// Photo-evidence logs.
    case evidence
    /// Fights attended.
    case event
    /// Cumulative Earth points.
    case points
    /// Unlocks on a date rather than by counting. Never satisfied by a threshold.
    case seasonal
    /// Handed over by a Fight organiser rather than reached by counting.
    case fightReward
}

/// A badge in the catalogue.
///
/// **Presentation is main's, criteria are Tio's.** `tier`, `detail` and `icon` are
/// what the profile grid and the detail sheet render and are unchanged. What was
/// a `Requirement` enum carrying its own numbers is now a `type` plus a numeric
/// `threshold`, which is what lets one function evaluate every badge.
nonisolated struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tier: String
    let detail: String
    let icon: String

    let type: BadgeType
    /// The target number, compared against whatever `type` points at.
    let threshold: Int
    /// Only meaningful for `.categoryMilestone`.
    let targetCategory: HabitCategory?

    // MARK: - User progress

    /// Filled in by `BadgeEvaluationService.display` from the award record — the
    /// catalogue itself is shared and owns nobody's progress.
    var isUnlocked: Bool
    var unlockedDate: Date?

    init(id: String,
         name: String,
         tier: String,
         detail: String,
         icon: String,
         type: BadgeType,
         threshold: Int = 0,
         targetCategory: HabitCategory? = nil,
         isUnlocked: Bool = false,
         unlockedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.tier = tier
        self.detail = detail
        self.icon = icon
        self.type = type
        self.threshold = threshold
        self.targetCategory = targetCategory
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
    }

    /// Sets `isUnlocked` and `unlockedDate` together, so a badge can never be
    /// unlocked without a date or dated without being unlocked.
    func unlocked(at date: Date) -> Badge {
        var copy = self
        copy.isUnlocked = true
        copy.unlockedDate = date
        return copy
    }
}

