//
//  ActivityLog.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Category
//  Dipakai : ActivityLogRepository, PointsCalculationService,
//            ActivityLoggingService, BadgeEvaluationService, riwayat di UI
//

import Foundation

/// Dari mana aktivitas dicatat. Keduanya berbagi satu log yang sama (dedup),
/// field ini hanya untuk analitik dan tampilan riwayat.
nonisolated enum LogSource: String, Codable, CaseIterable {
    case manualChecklist
    case camera
}

/// Satu catatan aktivitas selesai.
///
/// Menyimpan setiap multiplier yang berlaku saat itu, bukan cuma hasil akhir,
/// supaya poin di riwayat lama tetap bisa dijelaskan ke user walaupun lokasi
/// atau streak-nya sudah berubah.
nonisolated struct ActivityLog: Identifiable, Codable, Hashable {

    let id: String
    let userId: String
    let activityId: String

    /// Kategori disalin ke sini supaya menghitung badge kategori tidak perlu
    /// menggabungkan log dengan katalog aktivitas.
    let category: Category

    /// Waktu pencatatan persisnya.
    let loggedAt: Date

    /// Hari kalender dari `loggedAt`, format "2026-08-11". Bagian dari kunci dedup
    /// dan dipakai menjumlahkan cap harian tanpa perbandingan tanggal.
    let dayKey: String

    // MARK: - Rincian perhitungan poin

    /// Poin dasar aktivitas sebelum cap harian.
    let basePoints: Int

    /// Poin dasar yang benar-benar dihitung setelah cap harian.
    /// Lebih kecil dari `basePoints` kalau log ini menabrak batas 100.
    let countedBasePoints: Int

    let evidenceBonus: Double
    let streakMultiplier: Double
    let priorityMultiplier: Double

    /// Hasil akhir yang masuk ke poin user.
    let finalPoints: Int

    // MARK: - Konteks

    let hasEvidence: Bool
    let source: LogSource

    /// `nil` = lokasi tidak tersedia saat pencatatan.
    let provinceCode: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        activityId: String,
        category: Category,
        loggedAt: Date,
        dayKey: String,
        basePoints: Int,
        countedBasePoints: Int,
        evidenceBonus: Double,
        streakMultiplier: Double,
        priorityMultiplier: Double,
        finalPoints: Int,
        hasEvidence: Bool,
        source: LogSource,
        provinceCode: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.activityId = activityId
        self.category = category
        self.loggedAt = loggedAt
        self.dayKey = dayKey
        self.basePoints = basePoints
        self.countedBasePoints = countedBasePoints
        self.evidenceBonus = evidenceBonus
        self.streakMultiplier = streakMultiplier
        self.priorityMultiplier = priorityMultiplier
        self.finalPoints = finalPoints
        self.hasEvidence = hasEvidence
        self.source = source
        self.provinceCode = provinceCode
    }

    /// Kunci unik userId + activityId + hari. Nanti dipakai sebagai document ID
    /// di Firestore, sehingga dedup dijamin oleh database, bukan cuma oleh
    /// pengecekan di app.
    var dedupKey: String {
        ActivityLog.dedupKey(userId: userId, activityId: activityId, dayKey: dayKey)
    }

    static func dedupKey(userId: String, activityId: String, dayKey: String) -> String {
        "\(userId)_\(activityId)_\(dayKey)"
    }

    /// Sebagian base points log ini terpotong cap harian.
    var wasCappedByDailyLimit: Bool {
        countedBasePoints < basePoints
    }
}
