//
//  EarthStage.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  PointsConfiguration, UserState, DecayService, View progres

import Foundation

/// Ambang poinnya TIDAK ada di sini, tapi di `PointsConfiguration.stageThresholds`,
/// karena angka itu akan dikalibrasi ulang dan mungkin pindah ke Remote Config.
nonisolated enum EarthStage: Int, Codable, CaseIterable, Comparable {
    case critical = 0
    case fragile = 1
    case stabilizing = 2
    case recovering = 3
    case flourishing = 4
    case restored = 5

    var displayName: String {
        switch self {
        case .critical:     return "Critical"
        case .fragile:      return "Fragile"
        case .stabilizing:  return "Stabilizing"
        case .recovering:   return "Recovering"
        case .flourishing:  return "Flourishing"
        case .restored:     return "Restored"
        }
    }

    /// `nil` kalau sudah tahap tertinggi.
    var next: EarthStage? {
        EarthStage(rawValue: rawValue + 1)
    }

    var previous: EarthStage? {
        EarthStage(rawValue: rawValue - 1)
    }

    static func < (lhs: EarthStage, rhs: EarthStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
