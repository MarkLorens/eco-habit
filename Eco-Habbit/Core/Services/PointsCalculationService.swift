//
//  PointsCalculationService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Activity, PointsConfiguration
//  Dipakai : ActivityLoggingService, unit test
//
//  Fungsi murni tanpa I/O: masukkan angka, dapat angka. Tidak menyentuh
//  repository maupun UserState, jadi bisa dites tanpa setup apa pun.
//

import Foundation

/// Rincian perhitungan satu pencatatan aksi.
/// Disimpan utuh ke `ActivityLog` supaya poin di riwayat lama tetap bisa
/// dijelaskan ke user walaupun streak dan lokasinya sudah berubah.
nonisolated struct PointsBreakdown: Equatable {

    /// Poin dasar aksi sebelum cap harian.
    let basePoints: Int

    /// Poin dasar yang benar-benar dihitung setelah cap harian.
    let countedBasePoints: Int

    let evidenceBonus: Double
    let streakMultiplier: Double
    let priorityMultiplier: Double

    /// Hasil akhir yang masuk ke poin user.
    let finalPoints: Int

    var wasCappedByDailyLimit: Bool { countedBasePoints < basePoints }
}

nonisolated struct PointsCalculationService {

    let config: PointsConfiguration

    init(config: PointsConfiguration = .default) {
        self.config = config
    }

    /// Menghitung poin satu pencatatan.
    ///
    /// - Parameter basePointsUsedToday: jumlah poin DASAR yang sudah terpakai
    ///   hari ini dari aksi harian. Poin Fight tidak ikut dihitung di sini.
    func breakdown(
        activity: Activity,
        hasEvidence: Bool,
        currentStreak: Int,
        isPrioritized: Bool,
        basePointsUsedToday: Int
    ) -> PointsBreakdown {

        // Cap harian dipotong SEBELUM multiplier, dan diukur dari poin dasar.
        // Konsekuensinya yang disengaja: poin final harian bisa melebihi 100,
        // misal 100 dasar × 1,2 evidence × 1,5 streak = 180. Kalau cap
        // diterapkan pada poin final, user dengan streak panjang justru kena
        // batas lebih cepat daripada user baru — multiplier akan terasa
        // seperti hukuman, bukan hadiah.
        let remainingBaseToday = max(0, config.dailyBasePointsCap - basePointsUsedToday)
        let countedBase = min(activity.basePoints, remainingBaseToday)

        let evidenceBonus = config.evidenceBonus(hasEvidence: hasEvidence)
        let streakMultiplier = config.streakMultiplier(forStreak: currentStreak)
        let priorityMultiplier = config.priorityMultiplier(isPrioritized: isPrioritized)

        // Urutan perkalian ini WAJIB dipertahankan persis seperti ini.
        // Perkalian floating point tidak asosiatif secara sempurna, jadi urutan
        // yang berbeda bisa menghasilkan selisih satu poin pada kasus tertentu —
        // cukup untuk membuat hasil test tidak konsisten dengan produksi.
        let raw = Double(countedBase)
            * evidenceBonus
            * streakMultiplier
            * priorityMultiplier

        return PointsBreakdown(
            basePoints: activity.basePoints,
            countedBasePoints: countedBase,
            evidenceBonus: evidenceBonus,
            streakMultiplier: streakMultiplier,
            priorityMultiplier: priorityMultiplier,
            finalPoints: Int(raw.rounded())
        )
    }

    /// Total poin dasar yang sudah terpakai pada sekumpulan log satu hari.
    /// Memakai `countedBasePoints`, bukan `basePoints` — yang terpotong cap
    /// tidak boleh ikut menghabiskan jatah lagi.
    func basePointsUsed(in logs: [ActivityLog]) -> Int {
        logs.reduce(0) { $0 + $1.countedBasePoints }
    }
}
