//
//  MockActivityData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Activity, Category, FrictionLevel, EvidenceStrength
//  Dipakai : MockActivityRepository, MockActivityDetector, SwiftUI preview, test
//

import Foundation

/// Katalog aktivitas harian.
///
/// CATATAN: spec menyebut "40 aktivitas" tapi tabelnya berisi 38 baris
/// (Food 8, Water 6, Waste 7, Energy 6, Mobility 6, Actions 5). Yang
/// diimplementasikan di sini 38 sesuai tabel — `validate()` juga mengecek 38.
nonisolated enum MockActivityData {

    static let all: [Activity] =
        foodConsumption + water + wasteManagement + energy + mobility + actions

    // MARK: - Food & Consumption

    static let foodConsumption: [Activity] = [
        Activity(id: "food_reusable_bottle",
                 name: "Bring a reusable bottle",
                 category: .foodConsumption,
                 frictionLevel: .f1,
                 evidenceStrength: .direct),

        Activity(id: "food_reusable_bag",
                 name: "Bring a reusable shopping bag",
                 category: .foodConsumption,
                 frictionLevel: .f1,
                 evidenceStrength: .direct),

        Activity(id: "food_refuse_single_use_cutlery",
                 name: "Refuse single-use cutlery/straw",
                 category: .foodConsumption,
                 frictionLevel: .f1,
                 evidenceStrength: .notDetectable),

        Activity(id: "food_own_container",
                 name: "Bring your own food container",
                 category: .foodConsumption,
                 frictionLevel: .f2,
                 evidenceStrength: .direct),

        Activity(id: "food_finish_food",
                 name: "Finish your food",
                 category: .foodConsumption,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "food_buy_local",
                 name: "Buy local products",
                 category: .foodConsumption,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "food_plant_based_meal",
                 name: "Eat a plant-based meal",
                 category: .foodConsumption,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "food_buy_secondhand",
                 name: "Buy secondhand",
                 category: .foodConsumption,
                 frictionLevel: .f3,
                 evidenceStrength: .contextual)
    ]

    // MARK: - Water

    static let water: [Activity] = [
        Activity(id: "water_tap_off_brushing",
                 name: "Turn off tap while brushing",
                 category: .water,
                 frictionLevel: .f1,
                 evidenceStrength: .contextual),

        Activity(id: "water_shorter_shower",
                 name: "Shorter shower (< 5 min)",
                 category: .water,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "water_reuse_washing_water",
                 name: "Reuse washing water for plants",
                 category: .water,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "water_full_loads_only",
                 name: "Wash full loads only",
                 category: .water,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "water_collect_rainwater",
                 name: "Collect rainwater",
                 category: .water,
                 frictionLevel: .f3,
                 evidenceStrength: .contextual),

        Activity(id: "water_fix_leaking_tap",
                 name: "Fix a leaking tap",
                 category: .water,
                 frictionLevel: .f4,
                 evidenceStrength: .contextual,
                 cooldownDays: 30)
    ]

    // MARK: - Waste Management

    static let wasteManagement: [Activity] = [
        Activity(id: "waste_refuse_plastic_bag",
                 name: "Refuse plastic bag",
                 category: .wasteManagement,
                 frictionLevel: .f1,
                 evidenceStrength: .notDetectable),

        Activity(id: "waste_digital_receipt",
                 name: "Choose digital receipt",
                 category: .wasteManagement,
                 frictionLevel: .f1,
                 evidenceStrength: .notDetectable),

        Activity(id: "waste_segregate",
                 name: "Segregate organic/inorganic waste",
                 category: .wasteManagement,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "waste_compost",
                 name: "Compost food scraps",
                 category: .wasteManagement,
                 frictionLevel: .f3,
                 evidenceStrength: .contextual),

        Activity(id: "waste_refill_product",
                 name: "Refill household product",
                 category: .wasteManagement,
                 frictionLevel: .f3,
                 evidenceStrength: .contextual),

        Activity(id: "waste_repair_instead_replace",
                 name: "Repair instead of replacing",
                 category: .wasteManagement,
                 frictionLevel: .f4,
                 evidenceStrength: .contextual,
                 cooldownDays: 7),

        Activity(id: "waste_bank_sampah_dropoff",
                 name: "Drop off waste at bank sampah",
                 category: .wasteManagement,
                 frictionLevel: .f4,
                 evidenceStrength: .contextual)
    ]

    // MARK: - Energy

    static let energy: [Activity] = [
        Activity(id: "energy_lights_off",
                 name: "Turn off unused lights",
                 category: .energy,
                 frictionLevel: .f1,
                 evidenceStrength: .contextual),

        Activity(id: "energy_unplug_chargers",
                 name: "Unplug idle chargers",
                 category: .energy,
                 frictionLevel: .f1,
                 evidenceStrength: .contextual),

        Activity(id: "energy_monitor_off",
                 name: "Turn off monitor when away",
                 category: .energy,
                 frictionLevel: .f1,
                 evidenceStrength: .contextual),

        Activity(id: "energy_cold_water_wash",
                 name: "Wash clothes with cold water",
                 category: .energy,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "energy_air_dry_clothes",
                 name: "Air-dry clothes",
                 category: .energy,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "energy_ac_24_or_above",
                 name: "Set AC to 24°C or above",
                 category: .energy,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual)
    ]

    // MARK: - Mobility

    static let mobility: [Activity] = [
        Activity(id: "mobility_combine_errands",
                 name: "Combine errands into one trip",
                 category: .mobility,
                 frictionLevel: .f2,
                 evidenceStrength: .notDetectable),

        Activity(id: "mobility_walk_instead",
                 name: "Walk instead of riding",
                 category: .mobility,
                 frictionLevel: .f2,
                 evidenceStrength: .notDetectable),

        Activity(id: "mobility_carpool",
                 name: "Carpool / ride-share",
                 category: .mobility,
                 frictionLevel: .f2,
                 evidenceStrength: .contextual),

        Activity(id: "mobility_skip_commute_wfh",
                 name: "Skip commute (WFH)",
                 category: .mobility,
                 frictionLevel: .f2,
                 evidenceStrength: .notDetectable),

        Activity(id: "mobility_public_transport",
                 name: "Take public transport",
                 category: .mobility,
                 frictionLevel: .f3,
                 evidenceStrength: .direct),

        Activity(id: "mobility_cycle",
                 name: "Cycle instead of motor vehicle",
                 category: .mobility,
                 frictionLevel: .f3,
                 evidenceStrength: .direct)
    ]

    // MARK: - Actions

    static let actions: [Activity] = [
        Activity(id: "actions_learning_card",
                 name: "Complete in-app learning card",
                 category: .actions,
                 frictionLevel: .f1,
                 evidenceStrength: .notDetectable),

        Activity(id: "actions_share_progress",
                 name: "Share your progress",
                 category: .actions,
                 frictionLevel: .f1,
                 evidenceStrength: .notDetectable),

        Activity(id: "actions_educate_someone",
                 name: "Educate someone about local issue",
                 category: .actions,
                 frictionLevel: .f2,
                 evidenceStrength: .notDetectable),

        Activity(id: "actions_regional_daily_mission",
                 name: "Regional daily mission",
                 category: .actions,
                 frictionLevel: .f3,
                 evidenceStrength: .notDetectable),

        Activity(id: "actions_visit_refill_station",
                 name: "Visit refill station / bank sampah",
                 category: .actions,
                 frictionLevel: .f4,
                 evidenceStrength: .contextual)
    ]

    // MARK: - Query helper

    static func activities(in category: Category) -> [Activity] {
        all.filter { $0.category == category }
    }

    static func activity(withID id: String) -> Activity? {
        all.first { $0.id == id }
    }

    /// Kandidat hasil deteksi kamera.
    static var cameraEligible: [Activity] {
        all.filter { $0.evidenceStrength.isCameraEligible }
    }

    // MARK: - Validasi

    /// Mengembalikan daftar masalah pada mock data. Kosong = sehat.
    ///
    /// Mengembalikan array alih-alih `assert` supaya SwiftUI preview tidak crash;
    /// test-lah yang menegaskan hasilnya kosong. Mock data yang salah diam-diam
    /// adalah sumber bug yang paling membingungkan saat men-debug UI.
    static func validate() -> [String] {
        var problems: [String] = []

        let expectedCount = 38
        if all.count != expectedCount {
            problems.append("Jumlah aktivitas \(all.count), seharusnya \(expectedCount).")
        }

        let duplicateIDs = Dictionary(grouping: all, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateIDs.isEmpty {
            problems.append("ID duplikat: \(duplicateIDs.joined(separator: ", ")).")
        }

        for activity in all where activity.basePoints != activity.frictionLevel.basePoints {
            problems.append(
                "\(activity.id): basePoints \(activity.basePoints) tidak cocok "
                + "\(activity.frictionLevel.rawValue) (\(activity.frictionLevel.basePoints))."
            )
        }

        for activity in all where activity.name.isEmpty {
            problems.append("\(activity.id): name kosong.")
        }

        // Cooldown 0 kemungkinan salah tulis — maksudnya `nil` (tanpa cooldown).
        for activity in all {
            if let cooldown = activity.cooldownDays, cooldown <= 0 {
                problems.append("\(activity.id): cooldownDays \(cooldown), seharusnya nil.")
            }
        }

        return problems
    }
}
