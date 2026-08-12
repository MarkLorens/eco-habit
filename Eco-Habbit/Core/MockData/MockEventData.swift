//
//  MockEventData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Event, EventTier
//  Dipakai : MockEventRepository, SwiftUI preview, test
//

import Foundation

/// 7 event contoh dari partner, tanggalnya tersebar di Agustus 2026.
nonisolated enum MockEventData {

    static let all: [Event] = [
        Event(id: "event_sanur_beach_cleanup",
              title: "Sanur Beach Clean-Up",
              organizer: "Komunitas Peduli Pesisir",
              tier: .standard,
              date: date(2026, 8, 3),
              location: "Sanur Beach, Denpasar",
              provinceCode: "BA",
              requiresCheckInCode: true),

        Event(id: "event_refill_workshop_kemang",
              title: "Refill & Zero-Waste Workshop",
              organizer: "Saraswati Coffee House",
              tier: .micro,
              date: date(2026, 8, 8),
              location: "Kemang, Jakarta Selatan",
              provinceCode: "JK",
              requiresCheckInCode: false),

        Event(id: "event_composting_101_bandung",
              title: "Composting 101 for Beginners",
              organizer: "Bandung Urban Farming",
              tier: .micro,
              date: date(2026, 8, 12),
              location: "Taman Cikapayang, Bandung",
              provinceCode: "JB",
              requiresCheckInCode: false),

        Event(id: "event_mangrove_planting_ubud",
              title: "Mangrove Planting Day",
              organizer: "Green Ubud Resort",
              tier: .major,
              date: date(2026, 8, 16),
              location: "Ngurah Rai Forest Park, Badung",
              provinceCode: "BA",
              requiresCheckInCode: true),

        Event(id: "event_bank_sampah_open_day",
              title: "Bank Sampah Open Day",
              organizer: "Bank Sampah Melati",
              tier: .standard,
              date: date(2026, 8, 22),
              location: "Cempaka Putih, Jakarta Pusat",
              provinceCode: "JK",
              requiresCheckInCode: true),

        Event(id: "event_car_free_day_dago",
              title: "Car Free Day Ride",
              organizer: "Bandung Bike Community",
              tier: .micro,
              date: date(2026, 8, 23),
              location: "Dago, Bandung",
              provinceCode: "JB",
              requiresCheckInCode: false),

        Event(id: "event_sustainability_festival",
              title: "Nusantara Sustainability Festival",
              organizer: "Yayasan Bumi Lestari",
              tier: .major,
              date: date(2026, 8, 29),
              location: "Senayan, Jakarta Pusat",
              provinceCode: "JK",
              requiresCheckInCode: true)
    ]

    // MARK: - Query helper

    static func event(withID id: String) -> Event? {
        all.first { $0.id == id }
    }

    static func upcoming(from referenceDate: Date = Date()) -> [Event] {
        all.filter { $0.date >= referenceDate }.sorted { $0.date < $1.date }
    }

    // MARK: - Helper tanggal

    /// Kalender Gregorian dipaksa agar tanggal mock sama di semua device,
    /// termasuk device dengan kalender non-Gregorian.
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 9

        let calendar = Calendar(identifier: .gregorian)
        // Mock data statis; kalau komponennya valid ini tidak pernah nil.
        return calendar.date(from: components) ?? Date()
    }

    // MARK: - Validasi

    static func validate() -> [String] {
        var problems: [String] = []

        let duplicateIDs = Dictionary(grouping: all, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateIDs.isEmpty {
            problems.append("ID event duplikat: \(duplicateIDs.joined(separator: ", ")).")
        }

        for event in all where event.points != event.tier.points {
            problems.append(
                "\(event.id): points \(event.points) tidak cocok tier "
                + "\(event.tier.rawValue) (\(event.tier.points))."
            )
        }

        // Minimal satu event per tier supaya UI dan test cap bulanan
        // punya bahan untuk ketiga skala.
        for tier in EventTier.allCases where !all.contains(where: { $0.tier == tier }) {
            problems.append("Tidak ada event contoh untuk tier \(tier.rawValue).")
        }

        return problems
    }
}
