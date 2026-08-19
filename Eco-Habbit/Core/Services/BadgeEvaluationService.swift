import Foundation

/// Evaluates every badge with one function.
///
/// Tio's design: a badge carries a numeric `threshold` and a `type` naming which
/// number to compare it against, so adding a badge is data and never touches this
/// file. Adapted to read `PersistedState` and main's counters.
nonisolated struct BadgeEvaluationService {

    /// The number compared against `badge.threshold`.
    func currentValue(for badge: Badge, state: PersistedState, today: String) -> Int {
        switch badge.type {
        case .totalActions:
            return state.logs.count

        case .streak:
            return max(state.streakDays, state.longestStreak)

        case .points:
            return state.currentPoints

        case .evidence:
            return state.logs.filter { $0.source == .visualSearch }.count

        case .event:
            return state.fightAttendance.count

        case .categoryMilestone:
            guard let category = badge.targetCategory else { return 0 }
            return state.logs.filter { MockData.habitsById[$0.habitId]?.category == category }.count

        // Neither of these is reached by counting, so neither can be inferred
        // from a threshold. `.seasonal` opens on a date; `.fightReward` is handed
        // over by an organiser at check-in. `newlyEarned` skips both.
        case .seasonal, .fightReward:
            return 0
        }
    }

    /// 0.0–1.0, for the progress ring on a locked badge.
    func progress(for badge: Badge, state: PersistedState, today: String) -> Double {
        guard badge.threshold > 0 else { return 0 }
        let value = Double(currentValue(for: badge, state: state, today: today))
        return min(1.0, value / Double(badge.threshold))
    }

    /// Awards to write for badges just reached.
    ///
    /// **Earned is permanent** — passing `alreadyEarned` is what guarantees it. A
    /// `.points` badge becomes its own permanent record: somebody who once
    /// reached Flourishing keeps the badge after decay takes those points away,
    /// with no separate high-water mark needed to remember it.
    func newlyEarned(from badges: [Badge],
                     state: PersistedState,
                     alreadyEarned: Set<String>,
                     today: String,
                     at date: Date = Date()) -> [EarnedBadge] {
        badges
            .filter { $0.type != .fightReward && $0.type != .seasonal }
            .filter { !alreadyEarned.contains($0.id) }
            .filter { currentValue(for: $0, state: state, today: today) >= $0.threshold }
            .map { EarnedBadge(awarding: $0, at: date, source: .threshold($0.threshold)) }
    }

    /// The catalogue joined with what the user owns, for display.
    ///
    /// An award whose catalogue entry has gone is rebuilt from its own snapshot
    /// rather than dropped — losing a badge because somebody edited a data file
    /// is exactly the failure this design exists to prevent.
    func display(catalogue: [Badge], earned: [EarnedBadge]) -> [Badge] {
        let earnedById = Dictionary(earned.map { ($0.badgeId, $0) },
                                    uniquingKeysWith: { first, _ in first })

        let listed = catalogue.map { badge -> Badge in
            guard let award = earnedById[badge.id] else { return badge }
            return badge.unlocked(at: award.earnedAt)
        }

        let catalogueIds = Set(catalogue.map(\.id))
        let orphans = earned
            .filter { !catalogueIds.contains($0.badgeId) }
            .map { award in
                Badge(id: award.badgeId,
                      name: award.name,
                      tier: "Retired",
                      detail: "Earned before this badge was retired.",
                      icon: "b1",
                      type: .totalActions,
                      threshold: 0,
                      isUnlocked: true,
                      unlockedDate: award.earnedAt)
            }

        return listed + orphans
    }
}
