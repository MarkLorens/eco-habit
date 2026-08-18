//
//  EvidenceStrength.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Activity, MockActivityData, layer kamera


import Foundation

nonisolated enum EvidenceStrength: String, Codable, CaseIterable {

    /// Objek pada foto = bukti langsung aksinya.
    case direct

    /// Objek hanya konteks. Contoh: foto keran tidak membuktikan keran dimatikan.
    case contextual

    /// Tidak ada objek untuk difoto. Contoh: "Skip commute (WFH)".
    case notDetectable

    var isCameraEligible: Bool {
        switch self {
        case .direct:        return true
        case .contextual:    return true
        case .notDetectable: return false
        }
    }

    var canAutoSubmitPoints: Bool {
        switch self {
        case .direct:        return true
        case .contextual:    return false
        case .notDetectable: return false
        }
    }

    var requiresUserConfirmation: Bool {
        switch self {
        case .direct:        return false
        case .contextual:    return true
        case .notDetectable: return false
        }
    }
}
