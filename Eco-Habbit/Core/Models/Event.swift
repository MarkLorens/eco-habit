//
//  Event.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : —
//  Dipakai : MockEventData, PointsCalculationService
//

import Foundation

/// Skala event dan poinnya.
nonisolated enum EventTier: String, Codable, CaseIterable {
    case micro       // aktivitas kecil, < 1 jam
    case standard    // setengah hari, terorganisir
    case major       // acara besar, seharian

    /// Sumber tunggal tabel poin event.
    var points: Int {
        switch self {
        case .micro:    return 40
        case .standard: return 75
        case .major:    return 120
        }
    }

    var displayName: String {
        switch self {
        case .micro:    return "Micro"
        case .standard: return "Standard"
        case .major:    return "Major"
        }
    }
}

/// Kegiatan komunitas atau partner. Beda dari `Activity`: terjadi pada satu
/// tanggal, poinnya jauh lebih besar, dan bisa butuh kode check-in.
nonisolated struct Event: Identifiable, Codable, Hashable {

    /// Slug stabil, contoh "event_bali_beach_cleanup_aug".
    let id: String

    let title: String
    let organizer: String
    let tier: EventTier

    /// Default diturunkan dari `tier`. Disimpan dengan alasan sama seperti
    /// `Activity.basePoints`.
    let points: Int

    let date: Date
    let location: String

    /// Metadata saja untuk sekarang — fitur provinsi ditunda, belum memengaruhi poin.
    let provinceCode: String

    /// `false` = event terbuka, poin bisa diklaim mandiri.
    let requiresCheckInCode: Bool

    init(
        id: String,
        title: String,
        organizer: String,
        tier: EventTier,
        date: Date,
        location: String,
        provinceCode: String,
        requiresCheckInCode: Bool,
        points: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.organizer = organizer
        self.tier = tier
        self.date = date
        self.location = location
        self.provinceCode = provinceCode
        self.requiresCheckInCode = requiresCheckInCode
        self.points = points ?? tier.points
    }
}
