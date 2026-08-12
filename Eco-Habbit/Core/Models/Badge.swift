//
//  Badge.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Category
//  Dipakai : MockBadgeData, BadgeEvaluationService
//

import Foundation

/// Menentukan angka mana yang dibandingkan dengan `Badge.threshold`.
nonisolated enum BadgeType: String, Codable, CaseIterable {
    case streak             // dari UserState.currentStreak
    case categoryMilestone  // dari jumlah aksi satu kategori; wajib isi targetCategory
    case evidence           // dari jumlah foto bukti
    case event              // dari jumlah event dihadiri
    case points             // dari UserState.currentPoints
}

nonisolated struct Badge: Identifiable, Codable, Hashable {

    let id: String
    let name: String

    /// Kalimat naratif untuk kartu badge.
    let description: String

    let type: BadgeType

    /// Syarat dalam bahasa manusia, untuk ditampilkan. Jangan pernah di-parse —
    /// angka yang dipakai mesin ada di `threshold`.
    let criteria: String

    /// Angka target, dibandingkan dengan nilai yang ditunjuk `type`.
    let threshold: Int

    /// Hanya relevan untuk `.categoryMilestone`.
    let targetCategory: Category?

    /// `nil` = badge nasional. Semua badge nasional untuk sekarang (fitur
    /// provinsi ditunda). Badge regional nanti wajib kumulatif, bukan streak.
    let provinceCode: String?

    // MARK: - Progress user

    var isUnlocked: Bool
    var unlockedDate: Date?

    init(
        id: String,
        name: String,
        description: String,
        type: BadgeType,
        criteria: String,
        threshold: Int,
        targetCategory: Category? = nil,
        provinceCode: String? = nil,
        isUnlocked: Bool = false,
        unlockedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.criteria = criteria
        self.threshold = threshold
        self.targetCategory = targetCategory
        self.provinceCode = provinceCode
        self.isUnlocked = isUnlocked
        self.unlockedDate = unlockedDate
    }

    /// Mengisi `isUnlocked` dan `unlockedDate` sekaligus, agar tidak ada badge
    /// terbuka tanpa tanggal.
    func unlocked(at date: Date = Date()) -> Badge {
        var copy = self
        copy.isUnlocked = true
        copy.unlockedDate = date
        return copy
    }

    var isNational: Bool { provinceCode == nil }
}
