//
//  MockBadgeData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Badge, BadgeType, Category
//  Dipakai : MockBadgeRepository, BadgeEvaluationService, preview, test
//

import Foundation

/// 15 badge nasional.
///
/// Semua `provinceCode: nil` karena fitur provinsi ditunda. Badge regional nanti
/// ditambahkan di sini juga, dengan `type: .categoryMilestone` + `provinceCode`
/// terisi — dan wajib kumulatif, bukan streak.
nonisolated enum MockBadgeData {

    static let all: [Badge] = streakBadges + categoryBadges + evidenceBadges
        + eventBadges + pointBadges

    // MARK: - Streak

    static let streakBadges: [Badge] = [
        Badge(id: "badge_streak_7",
              name: "Seven Days In",
              description: "Kebiasaan kecil yang bertahan seminggu penuh.",
              type: .streak,
              criteria: "Catat aksi 7 hari berturut-turut.",
              threshold: 7),

        Badge(id: "badge_streak_30",
              name: "One Month Strong",
              description: "Sebulan tanpa putus. Ini bukan lagi coba-coba.",
              type: .streak,
              criteria: "Catat aksi 30 hari berturut-turut.",
              threshold: 30),

        Badge(id: "badge_streak_100",
              name: "Hundred Day Habit",
              description: "Seratus hari. Kebiasaan ini sudah jadi milikmu.",
              type: .streak,
              criteria: "Catat aksi 100 hari berturut-turut.",
              threshold: 100)
    ]

    // MARK: - Milestone kategori

    static let categoryBadges: [Badge] = [
        Badge(id: "badge_water_50",
              name: "Water Guardian",
              description: "Lima puluh keputusan kecil soal air.",
              type: .categoryMilestone,
              criteria: "Catat 50 aksi kategori Water.",
              threshold: 50,
              targetCategory: .water),

        Badge(id: "badge_waste_30",
              name: "Waste Sorter",
              description: "Sampah yang dipilah tidak berakhir sia-sia.",
              type: .categoryMilestone,
              criteria: "Catat 30 aksi kategori Waste Management.",
              threshold: 30,
              targetCategory: .wasteManagement),

        Badge(id: "badge_energy_40",
              name: "Watt Watcher",
              description: "Empat puluh kali memilih tidak menyalakan.",
              type: .categoryMilestone,
              criteria: "Catat 40 aksi kategori Energy.",
              threshold: 40,
              targetCategory: .energy),

        Badge(id: "badge_food_40",
              name: "Mindful Plate",
              description: "Apa yang kamu bawa dan habiskan ternyata berarti.",
              type: .categoryMilestone,
              criteria: "Catat 40 aksi kategori Food & Consumption.",
              threshold: 40,
              targetCategory: .foodConsumption),

        Badge(id: "badge_mobility_25",
              name: "Low-Carbon Commuter",
              description: "Dua puluh lima perjalanan dengan jejak lebih ringan.",
              type: .categoryMilestone,
              criteria: "Catat 25 aksi kategori Mobility.",
              threshold: 25,
              targetCategory: .mobility),

        Badge(id: "badge_actions_20",
              name: "Voice for Change",
              description: "Perubahan menyebar lewat orang, bukan cuma kebiasaan.",
              type: .categoryMilestone,
              criteria: "Catat 20 aksi kategori Actions.",
              threshold: 20,
              targetCategory: .actions)
    ]

    // MARK: - Evidence

    static let evidenceBadges: [Badge] = [
        Badge(id: "badge_evidence_25",
              name: "Proof in Pictures",
              description: "Dua puluh lima bukti nyata, bukan sekadar centang.",
              type: .evidence,
              criteria: "Kirim 25 foto bukti.",
              threshold: 25)
    ]

    // MARK: - Event

    static let eventBadges: [Badge] = [
        Badge(id: "badge_event_1",
              name: "First Step Out",
              description: "Event pertama selalu yang paling berat.",
              type: .event,
              criteria: "Hadiri 1 event.",
              threshold: 1),

        Badge(id: "badge_event_5",
              name: "Community Regular",
              description: "Lima event. Orang-orang mulai mengenalmu.",
              type: .event,
              criteria: "Hadiri 5 event.",
              threshold: 5),

        Badge(id: "badge_event_10",
              name: "Movement Builder",
              description: "Sepuluh event. Kamu bagian dari gerakannya.",
              type: .event,
              criteria: "Hadiri 10 event.",
              threshold: 10)
    ]

    // MARK: - Poin

    static let pointBadges: [Badge] = [
        Badge(id: "badge_points_1000",
              name: "Thousand Points",
              description: "Seribu poin dari ratusan pilihan kecil.",
              type: .points,
              criteria: "Capai 1.000 poin.",
              threshold: 1_000),

        Badge(id: "badge_points_2500",
              name: "Restored",
              description: "Bumi di app-mu kembali utuh.",
              type: .points,
              criteria: "Capai 2.500 poin.",
              threshold: 2_500)
    ]

    // MARK: - Query helper

    static func badge(withID id: String) -> Badge? {
        all.first { $0.id == id }
    }

    static func badges(ofType type: BadgeType) -> [Badge] {
        all.filter { $0.type == type }
    }

    // MARK: - Validasi

    static func validate() -> [String] {
        var problems: [String] = []

        let minimumCount = 15
        if all.count < minimumCount {
            problems.append("Jumlah badge \(all.count), minimal \(minimumCount).")
        }

        let duplicateIDs = Dictionary(grouping: all, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateIDs.isEmpty {
            problems.append("ID badge duplikat: \(duplicateIDs.joined(separator: ", ")).")
        }

        for badge in all where badge.threshold <= 0 {
            problems.append("\(badge.id): threshold \(badge.threshold) harus > 0.")
        }

        // `targetCategory` wajib ada untuk .categoryMilestone dan wajib kosong
        // untuk tipe lain — kalau tertukar, evaluator akan menghitung angka yang salah.
        for badge in all {
            switch badge.type {
            case .categoryMilestone:
                if badge.targetCategory == nil {
                    problems.append("\(badge.id): .categoryMilestone tanpa targetCategory.")
                }
            case .streak, .evidence, .event, .points:
                if badge.targetCategory != nil {
                    problems.append(
                        "\(badge.id): targetCategory tidak relevan untuk \(badge.type.rawValue)."
                    )
                }
            }
        }

        for badge in all where badge.isUnlocked {
            problems.append("\(badge.id): mock badge seharusnya mulai terkunci.")
        }

        return problems
    }
}
