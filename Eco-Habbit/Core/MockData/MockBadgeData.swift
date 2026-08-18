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
        + eventBadges + pointBadges + fightRewards

    // MARK: - Hadiah Fight

    /// Daftar TETAP yang bisa dipilih penyelenggara saat membuat Fight.
    ///
    /// Sengaja tidak berupa teks bebas: nama badge karangan sendiri membuat
    /// koleksi user berantakan dan tidak ada yang bisa menjamin mutunya. Enam
    /// pilihan menutup jenis Fight yang ada, dan menambah pilihan cukup menambah
    /// satu baris di sini.
    ///
    /// `threshold: 1` — lihat `BadgeType.fightReward`.
    static let fightRewards: [Badge] = [
        Badge(id: "fight_badge_shoreline",
              name: "Shoreline Keeper",
              description: "Kamu ikut membersihkan garis pantai bersama orang lain.",
              type: .fightReward,
              criteria: "Hadiri Fight bersih-bersih pantai atau sungai.",
              threshold: 1),

        Badge(id: "fight_badge_planter",
              name: "Planter",
              description: "Pohon yang kamu tanam akan hidup lebih lama darimu.",
              type: .fightReward,
              criteria: "Hadiri Fight penanaman pohon atau mangrove.",
              threshold: 1),

        Badge(id: "fight_badge_reef",
              name: "Reef Mender",
              description: "Terumbu tumbuh lambat. Kamu memberi awalannya.",
              type: .fightReward,
              criteria: "Hadiri Fight restorasi terumbu.",
              threshold: 1),

        Badge(id: "fight_badge_sorter",
              name: "Drive Volunteer",
              description: "Sehari memilah yang orang lain buang begitu saja.",
              type: .fightReward,
              criteria: "Hadiri Fight pengumpulan atau pemilahan sampah.",
              threshold: 1),

        Badge(id: "fight_badge_learner",
              name: "Workshop Graduate",
              description: "Kamu datang untuk belajar, bukan cuma hadir.",
              type: .fightReward,
              criteria: "Hadiri Fight berbentuk workshop.",
              threshold: 1),

        Badge(id: "fight_badge_wildlife",
              name: "Wildlife Ally",
              description: "Sebagian makhluk tidak akan pernah tahu kamu menolong.",
              type: .fightReward,
              criteria: "Hadiri Fight perlindungan satwa.",
              threshold: 1)
    ]

    static func fightReward(withID id: String) -> Badge? {
        fightRewards.first { $0.id == id }
    }

    // MARK: - Streak

    static let streakBadges: [Badge] = [
        Badge(id: "badge_streak_7",
              name: "Seven Days In",
              description: "A small habit that lasted a whole week.",
              type: .streak,
              criteria: "Log an action 7 days in a row.",
              threshold: 7),

        Badge(id: "badge_streak_30",
              name: "One Month Strong",
              description: "A month unbroken. This isn't an experiment any more.",
              type: .streak,
              criteria: "Log an action 30 days in a row.",
              threshold: 30),

        Badge(id: "badge_streak_100",
              name: "Hundred Day Habit",
              description: "A hundred days. This one is yours now.",
              type: .streak,
              criteria: "Log an action 100 days in a row.",
              threshold: 100)
    ]

    // MARK: - Milestone kategori

    static let categoryBadges: [Badge] = [
        Badge(id: "badge_water_50",
              name: "Water Guardian",
              description: "Fifty small decisions about water.",
              type: .categoryMilestone,
              criteria: "Log 50 Water actions.",
              threshold: 50,
              targetCategory: .water),

        Badge(id: "badge_waste_30",
              name: "Waste Sorter",
              description: "Waste you sort doesn't go to waste.",
              type: .categoryMilestone,
              criteria: "Log 30 Waste Management actions.",
              threshold: 30,
              targetCategory: .wasteManagement),

        Badge(id: "badge_energy_40",
              name: "Watt Watcher",
              description: "Forty times you chose not to switch it on.",
              type: .categoryMilestone,
              criteria: "Log 40 Energy actions.",
              threshold: 40,
              targetCategory: .energy),

        Badge(id: "badge_food_40",
              name: "Mindful Plate",
              description: "What you carry and what you finish turns out to matter.",
              type: .categoryMilestone,
              criteria: "Log 40 Food & Consumption actions.",
              threshold: 40,
              targetCategory: .foodConsumption),

        Badge(id: "badge_mobility_25",
              name: "Low-Carbon Commuter",
              description: "Twenty-five journeys with a lighter footprint.",
              type: .categoryMilestone,
              criteria: "Log 25 Mobility actions.",
              threshold: 25,
              targetCategory: .mobility),

        Badge(id: "badge_actions_20",
              name: "Voice for Change",
              description: "Change spreads through people, not just habits.",
              type: .categoryMilestone,
              criteria: "Log 20 Actions.",
              threshold: 20,
              targetCategory: .actions)
    ]

    // MARK: - Evidence

    static let evidenceBadges: [Badge] = [
        Badge(id: "badge_evidence_25",
              name: "Proof in Pictures",
              description: "Twenty-five real proofs, not just ticks.",
              type: .evidence,
              criteria: "Submit 25 photo proofs.",
              threshold: 25)
    ]

    // MARK: - Fight attendance

    static let eventBadges: [Badge] = [
        Badge(id: "badge_event_1",
              name: "First Step Out",
              description: "The first event is always the hardest.",
              type: .event,
              criteria: "Attend 1 event.",
              threshold: 1),

        Badge(id: "badge_event_5",
              name: "Community Regular",
              description: "Five events. People are starting to know you.",
              type: .event,
              criteria: "Attend 5 events.",
              threshold: 5),

        Badge(id: "badge_event_10",
              name: "Movement Builder",
              description: "Ten events. You're part of the movement.",
              type: .event,
              criteria: "Attend 10 events.",
              threshold: 10)
    ]

    // MARK: - Poin

    static let pointBadges: [Badge] = [
        Badge(id: "badge_points_1000",
              name: "Thousand Points",
              description: "A thousand points from hundreds of small choices.",
              type: .points,
              criteria: "Reach 1,000 points.",
              threshold: 1_000),

        Badge(id: "badge_points_2500",
              name: "Restored",
              description: "The Earth in your app is whole again.",
              type: .points,
              criteria: "Reach 2,500 points.",
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

        // 15 badge capaian + 6 hadiah Fight.
        let minimumCount = 21
        if all.count < minimumCount {
            problems.append("Jumlah badge \(all.count), minimal \(minimumCount).")
        }

        for badge in fightRewards where badge.threshold != 1 {
            problems.append("\(badge.id): hadiah Fight harus threshold 1, bukan \(badge.threshold).")
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
            case .streak, .evidence, .event, .points, .fightReward:
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
