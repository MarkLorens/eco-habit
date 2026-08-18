//
//  MockUserStateData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : UserState, Category
//  Dipakai : DashboardView, SwiftUI preview
//

import Foundation

/// User contoh untuk mengisi Dashboard selama Services belum ada.
///
/// SEMENTARA: begitu ActivityLoggingService jadi, angka-angka ini datang dari
/// UserStateRepository yang benar-benar diperbarui tiap user mencatat aksi.
/// Ditaruh di MockData, bukan di dalam View, supaya saat penggantian itu terjadi
/// yang perlu disunting hanya satu tempat.
enum MockUserStateData {

    static let demoDisplayName = "Fel"

    /// 1.200 poin jatuh di stage Recovering (ambang 950–1.600), streak 30 hari
    /// mengikuti angka di Sketch.
    static let demo = UserState(
        userId: "demo-user",
        currentPoints: 1_200,
        currentStreak: 30,
        lastActivityDate: Date(),
        totalEvidencePhotoCount: 12,
        attendedEventIDs: ["event_sanur_beach_cleanup"],
        actionCountsByCategoryRaw: [
            Category.water.rawValue: 34,
            Category.energy.rawValue: 28,
            Category.wasteManagement.rawValue: 21,
            Category.foodConsumption.rawValue: 19,
            Category.mobility.rawValue: 11,
            Category.actions.rawValue: 7
        ]
    )
}
