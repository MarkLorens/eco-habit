//
//  MockActivityData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Activity, Resources/activities.json
//  Dipakai : MockActivityRepository, SwiftUI preview, test, ml/generate_vectors.py
//

import Foundation

/// Katalog aktivitas harian, dimuat dari `Resources/activities.json`.
///
/// The table used to live here as a Swift literal. It is JSON now so that
/// writing habit content — names, and the sourced impact copy still to come —
/// is not a code edit: a content owner cannot break the build, conflicts merge
/// line by line instead of as Swift syntax, and the same file seeds Firestore
/// `activities/{id}` unchanged (FIREBASE_SETUP §5).
///
/// The file carries **definition only**. `hasEvidence` and `lastCompletedDate`
/// are per-user progress and are absent by design — see `Activity.init(from:)`.
///
/// NOTE: the spec says "40 activities"; the table holds 38
/// (Food 8, Water 6, Waste 7, Energy 6, Mobility 6, Actions 5).
/// `validate()` checks for 38, matching what is actually there.
nonisolated enum MockActivityData {

    /// Bundled content, not user input — a failure here means a broken build,
    /// so this traps rather than silently yielding an empty catalogue.
    static let all: [Activity] = {
        guard let url = Bundle.main.url(forResource: "activities", withExtension: "json") else {
            fatalError("activities.json is missing from the bundle")
        }
        do {
            return try JSONDecoder().decode([Activity].self, from: Data(contentsOf: url))
        } catch {
            fatalError("activities.json failed to decode: \(error)")
        }
    }()

    // Per-category slices, derived rather than hand-maintained.
    static var foodConsumption: [Activity] { activities(in: .foodConsumption) }
    static var water: [Activity]           { activities(in: .water) }
    static var wasteManagement: [Activity] { activities(in: .wasteManagement) }
    static var energy: [Activity]          { activities(in: .energy) }
    static var mobility: [Activity]        { activities(in: .mobility) }
    static var actions: [Activity]         { activities(in: .actions) }

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
