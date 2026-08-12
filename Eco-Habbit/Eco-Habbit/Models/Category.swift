//
//  Category.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//  Activity, Badge, UserState, MockActivityData, MockBadgeData


import Foundation

/// 6 kategori tetap. Raw value String agar dokumen Firestore terbaca saat debug.
nonisolated enum Category: String, Codable, CaseIterable, Identifiable {
    case foodConsumption
    case water
    case wasteManagement
    case energy
    case mobility
    case actions

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foodConsumption:  return "Food & Consumption"
        case .water:            return "Water"
        case .wasteManagement:  return "Waste Management"
        case .energy:           return "Energy"
        case .mobility:         return "Mobility"
        case .actions:          return "Actions"
        }
    }
}

