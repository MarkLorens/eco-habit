//
//  FrictionLevel.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : —
//  Dipakai : Activity, MockActivityData, PointsCalculationService
//

import Foundation

/// Tingkat usaha sebuah aksi. F1 = hampir tanpa usaha, F4 = butuh perencanaan/biaya.
nonisolated enum FrictionLevel: String, Codable, CaseIterable {
    case f1 = "F1"
    case f2 = "F2"
    case f3 = "F3"
    case f4 = "F4"

    var basePoints: Int {
        switch self {
        case .f1: return 5
        case .f2: return 10
        case .f3: return 15
        case .f4: return 20
        }
    }

    var displayName: String { rawValue }
}
