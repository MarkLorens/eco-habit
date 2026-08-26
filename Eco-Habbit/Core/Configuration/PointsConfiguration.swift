//
//  PointsConfiguration.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : EarthStage
//  Dipakai : semua Service, UserState, dan test
//
//  SATU-SATUNYA tempat angka tunable didefinisikan. Kalau kamu menemukan angka
//  balancing di-hardcode di file lain, itu bug — pindahkan ke sini.
//  `Codable` supaya nanti bisa di-decode langsung dari Firebase Remote Config.
//

import Foundation

nonisolated struct PointsConfiguration: Codable, Equatable {

    /// Satu tingkat streak. `minimumStreakDay` = hari pertama tier ini berlaku.
    nonisolated struct StreakTier: Codable, Equatable {
        let minimumStreakDay: Int
        let multiplier: Double
    }

    // MARK: - Earth stage

    /// Ambang poin per stage, urut dari stage 0. Index = `EarthStage.rawValue`.
    ///
    /// Array (bukan `[EarthStage: Int]`) karena dictionary berkunci enum tidak
    /// ter-serialize sebagai map JSON.
    var stageThresholds: [Int]

    // MARK: - Multiplier

    /// Wajib urut naik berdasarkan `minimumStreakDay`.
    var streakTiers: [StreakTier]

    /// **Sengaja 1.0 — bonus foto dihapus dari ekonomi.**
    ///
    /// Field-nya dipertahankan, bukan dihapus: tiap `ActivityLog` yang sudah
    /// tersimpan membawa `evidenceBonus`, jadi menghapusnya mengubah bentuk data
    /// di disk tanpa keuntungan apa pun. Kamera tetap ada dan `hasEvidence` tetap
    /// mengisi `totalEvidencePhotoCount` untuk badge — yang hilang hanya
    /// pengalinya. Isi 1.2 lagi kalau bonusnya dihidupkan kembali.
    var evidenceBonusWithPhoto: Double
    var evidenceBonusWithoutPhoto: Double

    /// Dipakai kalau aktivitas termasuk prioritas provinsi user saat itu.
    var priorityMultiplierActive: Double

    /// Dipakai kalau tidak prioritas ATAU lokasi tidak tersedia.
    var priorityMultiplierInactive: Double

    // MARK: - Cap

    /// Cap dihitung dari **poin dasar**, bukan poin final. Multiplier tetap
    /// berlaku di atas base yang lolos cap, jadi poin final harian bisa > 100.
    var dailyBasePointsCap: Int

    /// Points one Fight attendance pays. Flat for now — Tio's tiers (Micro 40 /
    /// Standard 75 / Major 120) need a tier on `Fight`, which lands with the
    /// Fights step. This is the Standard value so the number is not a placeholder
    /// nobody chose.
    var fightAttendancePoints: Int

    var monthlyEventPointsCap: Int

    // MARK: - Decay

    var decayGracePeriodDays: Int

    /// Hari ke-berapa tanpa aktivitas notifikasi peringatan dikirim.
    var decayWarningDayThreshold: Int

    /// Porsi poin yang hilang per hari setelah grace lewat. 0.02 = 2%.
    var decayRatePerDay: Double

    var maxStageDropPerAbsence: Int

    /// Poin tidak pernah turun di bawah ini karena decay.
    var decayPointsFloor: Int

    // MARK: - Default

    static let `default` = PointsConfiguration(
        // EXHIBITION TUNING. Habits are worth 5–20 base points (mean ~10), so at a
        // booth somebody logs 4–8 actions in a couple of minutes. On the old ladder the
        // second stage needed 450 — a visitor saw the Earth move once, if at all, and
        // the whole point of the globe is that it answers back.
        //
        // Reading these as actions: 1 → Fragile, ~3 → Stabilizing, ~5 → Recovering,
        // ~8 → Flourishing, ~13 → Restored. A Fight check-in pays 75 on its own, so
        // scanning a code visibly leaps the globe, which is the demo worth showing.
        //
        // One line to put back: [0, 150, 450, 950, 1_600, 2_500] was the original.
        stageThresholds: [0, 10, 25, 50, 85, 130],
        streakTiers: [
            StreakTier(minimumStreakDay: 1,  multiplier: 1.0),
            StreakTier(minimumStreakDay: 7,  multiplier: 1.1),
            StreakTier(minimumStreakDay: 15, multiplier: 1.2),
            StreakTier(minimumStreakDay: 30, multiplier: 1.35),
            StreakTier(minimumStreakDay: 60, multiplier: 1.5)
        ],
        evidenceBonusWithPhoto: 1.0,
        evidenceBonusWithoutPhoto: 1.0,
        priorityMultiplierActive: 1.3,
        priorityMultiplierInactive: 1.0,
        // **The daily cap is off.** Set beyond anything reachable rather than deleted:
        // the mechanism stays — `countedBasePoints`, `atDailyCap`, the messaging — so
        // turning it back on is this one number, not a re-implementation. At 100 a
        // visitor hit the ceiling after ~7 taps and every action afterwards paid zero,
        // which at a booth reads as a broken app rather than a design decision.
        dailyBasePointsCap: 1_000_000,
        fightAttendancePoints: 75,
        monthlyEventPointsCap: 150,
        decayGracePeriodDays: 7,
        decayWarningDayThreshold: 5,
        decayRatePerDay: 0.02,
        maxStageDropPerAbsence: 1,
        // Scaled with the ladder above. Left at 150 it sat ABOVE the whole scale, so
        // decay could never touch anyone and the floor silently meant "never decay".
        decayPointsFloor: 10
    )

    // MARK: - Lookup

    func threshold(for stage: EarthStage) -> Int {
        let index = stage.rawValue
        guard stageThresholds.indices.contains(index) else { return 0 }
        return stageThresholds[index]
    }

    /// Stage tertinggi yang ambangnya sudah dilewati `points`.
    func stage(forPoints points: Int) -> EarthStage {
        for stage in EarthStage.allCases.reversed() where points >= threshold(for: stage) {
            return stage
        }
        return .critical
    }

    /// Tier terakhir yang ambangnya terlewati. Streak 0 tidak cocok tier mana pun
    /// (tier terendah mulai hari 1), jadi jatuh ke 1.0.
    func streakMultiplier(forStreak streak: Int) -> Double {
        var multiplier = 1.0
        for tier in streakTiers where streak >= tier.minimumStreakDay {
            multiplier = tier.multiplier
        }
        return multiplier
    }

    func evidenceBonus(hasEvidence: Bool) -> Double {
        hasEvidence ? evidenceBonusWithPhoto : evidenceBonusWithoutPhoto
    }

    /// `isPrioritized == false` juga mencakup kasus lokasi tidak tersedia —
    /// spec: jangan pernah kurangi poin di bawah nilai dasar karena alasan teknis.
    func priorityMultiplier(isPrioritized: Bool) -> Double {
        isPrioritized ? priorityMultiplierActive : priorityMultiplierInactive
    }
}
