//
//  Activity.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Category, FrictionLevel, EvidenceStrength
//  Dipakai : MockActivityData, PointsCalculationService, View daftar aksi harian

import Foundation

/// Satu aksi harian yang bisa dicatat user.
///
/// Struct ini mencampur definisi katalog (id…cooldownDays) dengan progress user
/// (hasEvidence, lastCompletedDate). Digabung selama masih mock; di Firestore
/// nanti dipisah jadi `activities/{id}` dan `users/{uid}/activityProgress/{id}`.
nonisolated struct Activity: Identifiable, Codable, Hashable {

    // MARK: - Definisi katalog

    /// Slug stabil, contoh "food_reusable_bottle". Dirujuk oleh progress user,
    /// jadi tidak boleh di-generate ulang tiap app launch.
    let id: String

    let name: String
    let category: Category
    let frictionLevel: FrictionLevel

    /// Default diturunkan dari `frictionLevel`. Disimpan (bukan computed) agar
    /// poin yang pernah diberikan tetap terekam apa adanya kalau tabel friksi
    /// diubah nanti, dan agar bisa di-override untuk aksi bonus.
    let basePoints: Int

    let evidenceStrength: EvidenceStrength

    /// Jeda minimum sebelum boleh dicatat lagi. `nil` = boleh harian.
    let cooldownDays: Int?

    // MARK: - Progress user

    /// Pencatatan terakhir disertai foto. Untuk badge tipe evidence.
    var hasEvidence: Bool

    /// Sumber tunggal untuk "sudah dikerjakan hari ini?" dan cooldown.
    var lastCompletedDate: Date?

    init(
        id: String,
        name: String,
        category: Category,
        frictionLevel: FrictionLevel,
        evidenceStrength: EvidenceStrength,
        cooldownDays: Int? = nil,
        basePoints: Int? = nil,
        hasEvidence: Bool = false,
        lastCompletedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.frictionLevel = frictionLevel
        self.evidenceStrength = evidenceStrength
        self.cooldownDays = cooldownDays
        self.basePoints = basePoints ?? frictionLevel.basePoints
        self.hasEvidence = hasEvidence
        self.lastCompletedDate = lastCompletedDate
    }

    // MARK: - Status turunan

    /// Computed, bukan stored Bool — flag tersimpan akan basi lewat tengah malam.
    var isCompletedToday: Bool {
        isCompleted(on: Date())
    }

    /// Versi dengan tanggal & kalender yang bisa disuntik, untuk test.
    func isCompleted(on referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let lastCompletedDate else { return false }
        return calendar.isDate(lastCompletedDate, inSameDayAs: referenceDate)
    }

    /// Sisa hari cooldown, `0` = sudah boleh dicatat.
    ///
    /// Dihitung pada level hari kalender (`startOfDay`), bukan selisih jam, agar
    /// tidak bergantung pada jam berapa user mencatat sebelumnya.
    func cooldownRemainingDays(asOf referenceDate: Date = Date(),
                               calendar: Calendar = .current) -> Int {
        guard let cooldownDays, let lastCompletedDate else { return 0 }

        let lastDay = calendar.startOfDay(for: lastCompletedDate)
        let currentDay = calendar.startOfDay(for: referenceDate)
        let daysPassed = calendar.dateComponents([.day], from: lastDay, to: currentDay).day ?? 0

        // max(0,) juga menjaga kasus lastCompletedDate di masa depan (jam device diubah).
        return max(0, cooldownDays - daysPassed)
    }

    func isOnCooldown(asOf referenceDate: Date = Date(),
                      calendar: Calendar = .current) -> Bool {
        cooldownRemainingDays(asOf: referenceDate, calendar: calendar) > 0
    }
}
