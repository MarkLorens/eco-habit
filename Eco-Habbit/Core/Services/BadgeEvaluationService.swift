//
//  BadgeEvaluationService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Badge, UserState, Category
//  Dipakai : ActivityLoggingService, FightRepository, unit test
//

import Foundation

nonisolated struct BadgeEvaluationService {

    /// Angka yang dibandingkan dengan `badge.threshold`.
    ///
    /// Inilah alasan `Badge` punya `threshold` numerik di samping `criteria`
    /// yang berupa kalimat: seluruh evaluasi cukup satu fungsi, dan menambah
    /// badge baru tidak menyentuh kode ini sama sekali — hanya menambah data.
    func currentValue(for badge: Badge, state: UserState) -> Int {
        switch badge.type {
        case .streak:
            return state.currentStreak

        case .points:
            return state.currentPoints

        case .evidence:
            return state.totalEvidencePhotoCount

        case .event:
            return state.attendedEventIDs.count

        case .categoryMilestone:
            guard let category = badge.targetCategory else { return 0 }
            return state.actionCount(for: category)

        // Nothing counts toward a Fight reward. It is handed over by an organiser
        // at check-in, so it has no progress and `newlyUnlocked` skips it — see
        // there for why inferring it from a threshold of 1 was a mistake.
        case .fightReward:
            return 0
        }
    }

    /// Progres 0.0–1.0 untuk ditampilkan di UI.
    func progress(for badge: Badge, state: UserState) -> Double {
        guard badge.threshold > 0 else { return 0 }
        let value = Double(currentValue(for: badge, state: state))
        return min(1.0, value / Double(badge.threshold))
    }

    /// Awards to write for badges the user has just reached.
    ///
    /// **Earned is permanent** — passing `alreadyEarned` is what guarantees it. A
    /// `.points` badge is its own permanent record: somebody who once touched
    /// 1,000 points keeps it after decay takes those points away, and no separate
    /// high-water mark is needed to remember that.
    ///
    /// `.fightReward` badges are excluded outright. They are given by an organiser
    /// at check-in, so there is nothing to count and no threshold to cross —
    /// modelling them as "threshold 1, satisfied by a flag on `UserState`" made the
    /// evaluator responsible for a fact it had no way of knowing, and put half the
    /// record in one place and half in another.
    func newlyEarned(from badges: [Badge],
                     state: UserState,
                     alreadyEarned: Set<String>,
                     at date: Date = Date()) -> [EarnedBadge] {
        badges
            .filter { $0.type != .fightReward }
            .filter { !alreadyEarned.contains($0.id) }
            .filter { currentValue(for: $0, state: state) >= $0.threshold }
            .map { EarnedBadge(awarding: $0, at: date, source: .threshold($0.threshold)) }
    }

    /// The catalogue joined with what the user owns, for display.
    ///
    /// An award whose catalogue entry has gone is rebuilt from its own snapshot
    /// rather than dropped — losing a badge because someone edited a data file is
    /// exactly the failure this design exists to prevent.
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
                      description: "Earned before this badge was retired.",
                      type: .fightReward,
                      criteria: "",
                      threshold: 1,
                      isUnlocked: true,
                      unlockedDate: award.earnedAt)
            }

        return listed + orphans
    }
}
