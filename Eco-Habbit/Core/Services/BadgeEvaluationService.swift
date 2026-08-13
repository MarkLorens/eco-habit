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

        // Threshold is 1, so this reads as "earned or not" without the evaluator
        // needing to know anything special about Fight rewards.
        case .fightReward:
            return state.earnedFightBadgeIds.contains(badge.id) ? 1 : 0
        }
    }

    /// Progres 0.0–1.0 untuk ditampilkan di UI.
    func progress(for badge: Badge, state: UserState) -> Double {
        guard badge.threshold > 0 else { return 0 }
        let value = Double(currentValue(for: badge, state: state))
        return min(1.0, value / Double(badge.threshold))
    }

    /// Badge yang BARU terbuka. Yang sudah terbuka tidak pernah diperiksa lagi.
    ///
    /// Sekali terbuka, permanen — termasuk saat poin turun karena decay. Badge
    /// bertipe `.points` justru menjadi rekaman permanennya sendiri: user yang
    /// pernah menyentuh 1.000 poin tetap memegang badge itu walau poinnya
    /// kemudian tergerus, dan tidak perlu penghitung terpisah untuk mengingatnya.
    func newlyUnlocked(from badges: [Badge],
                       state: UserState,
                       at date: Date = Date()) -> [Badge] {
        badges
            .filter { !$0.isUnlocked }
            .filter { currentValue(for: $0, state: state) >= $0.threshold }
            .map { $0.unlocked(at: date) }
    }

    /// Menggabungkan badge yang baru terbuka ke dalam daftar lengkap.
    func merged(_ badges: [Badge], with unlocked: [Badge]) -> [Badge] {
        guard !unlocked.isEmpty else { return badges }

        let unlockedByID = Dictionary(unlocked.map { ($0.id, $0) },
                                      uniquingKeysWith: { first, _ in first })

        return badges.map { unlockedByID[$0.id] ?? $0 }
    }
}
