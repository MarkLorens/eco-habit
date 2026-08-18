//
//  ProvincePriority.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : HabitCategory
//  Dipakai : MockProvincePriorityData, PointsCalculationService
//

import Foundation

/// Kategori yang diprioritaskan sebuah provinsi. Aktivitas di kategori ini
/// mendapat `priorityMultiplier` 1.3× saat user berada di provinsi tersebut.
///
/// BELUM AKTIF: app belum meminta izin lokasi, `UserState.currentProvinceCode`
/// selalu `nil`, jadi semua user dapat multiplier 1.0. Datanya sudah disiapkan
/// supaya nanti tinggal mengaktifkan sumber lokasinya.
nonisolated struct ProvincePriority: Codable, Hashable {
    let provinceCode: String
    let provinceName: String
    let prioritizedCategories: [HabitCategory]
}
