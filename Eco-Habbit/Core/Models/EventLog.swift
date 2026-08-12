//
//  EventLog.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : EventTier (dari Event.swift)
//  Dipakai : EventLogRepository, EventClaimService, BadgeEvaluationService
//

import Foundation

/// Catatan klaim kehadiran event.
///
/// `eventPoints` vs `awardedPoints` sengaja dipisah: saat cap bulanan 150 sudah
/// terpakai, klaim tetap dicatat dengan poin penuh (untuk riwayat dan hitungan
/// badge) tapi `awardedPoints` bisa 0 karena tidak menambah poin user.
nonisolated struct EventLog: Identifiable, Codable, Hashable {

    let id: String
    let userId: String
    let eventId: String
    let tier: EventTier

    let claimedAt: Date

    /// Periode cap bulanan, format "2026-08".
    let monthKey: String

    /// Poin penuh event sesuai tier.
    let eventPoints: Int

    /// Poin yang benar-benar ditambahkan ke user setelah cap bulanan.
    let awardedPoints: Int

    init(
        id: String = UUID().uuidString,
        userId: String,
        eventId: String,
        tier: EventTier,
        claimedAt: Date,
        monthKey: String,
        eventPoints: Int,
        awardedPoints: Int
    ) {
        self.id = id
        self.userId = userId
        self.eventId = eventId
        self.tier = tier
        self.claimedAt = claimedAt
        self.monthKey = monthKey
        self.eventPoints = eventPoints
        self.awardedPoints = awardedPoints
    }

    /// Klaim ini terpotong cap bulanan (sebagian atau seluruhnya).
    var wasCappedByMonthlyLimit: Bool {
        awardedPoints < eventPoints
    }

    /// Kunci unik: satu event hanya bisa diklaim sekali per user.
    var dedupKey: String {
        EventLog.dedupKey(userId: userId, eventId: eventId)
    }

    static func dedupKey(userId: String, eventId: String) -> String {
        "\(userId)_\(eventId)"
    }
}
