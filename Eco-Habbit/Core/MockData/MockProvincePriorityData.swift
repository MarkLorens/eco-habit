//
//  MockProvincePriorityData.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : ProvincePriority, Category
//  Dipakai : PointsCalculationService (lewat protocol ProvincePriorityProviding)
//

import Foundation

/// Mapping provinceCode → kategori prioritas. Provinsi yang tidak terdaftar
/// jatuh ke default nasional: tanpa prioritas, multiplier 1.0.
///
/// BELUM AKTIF: `UserState.currentProvinceCode` selalu `nil` untuk sekarang,
/// jadi `isPrioritized` selalu mengembalikan `false` dan semua user memperoleh
/// poin dengan cara yang sama.
nonisolated enum MockProvincePriorityData {

    static let all: [ProvincePriority] = [
        ProvincePriority(provinceCode: "BA",
                         provinceName: "Bali",
                         prioritizedCategories: [.water, .wasteManagement]),

        ProvincePriority(provinceCode: "JK",
                         provinceName: "DKI Jakarta",
                         prioritizedCategories: [.mobility, .energy]),

        ProvincePriority(provinceCode: "JB",
                         provinceName: "Jawa Barat",
                         prioritizedCategories: [.wasteManagement, .water])
    ]

    static func priority(forProvinceCode code: String?) -> ProvincePriority? {
        guard let code else { return nil }
        return all.first { $0.provinceCode == code }
    }

    /// `false` untuk provinsi yang tidak terdaftar maupun lokasi yang tidak tersedia.
    static func isPrioritized(category: Category, provinceCode: String?) -> Bool {
        guard let priority = priority(forProvinceCode: provinceCode) else { return false }
        return priority.prioritizedCategories.contains(category)
    }

    static func validate() -> [String] {
        var problems: [String] = []

        let duplicateCodes = Dictionary(grouping: all, by: \.provinceCode)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateCodes.isEmpty {
            problems.append("provinceCode duplikat: \(duplicateCodes.joined(separator: ", ")).")
        }

        for province in all where province.prioritizedCategories.isEmpty {
            problems.append("\(province.provinceCode): prioritizedCategories kosong.")
        }

        return problems
    }
}
