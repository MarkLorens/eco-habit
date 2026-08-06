import SwiftUI

/// The five impact types the app is organised around.
nonisolated enum ActivityCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case waste       // Kurangi Sampah — waste reduction
    case energy      // Hemat Energi — energy saving
    case water       // Jaga Air — water conservation
    case mobility    // Transportasi Hijau — sustainable mobility
    case community   // Aksi Komunitas — community / local action

    var id: String { rawValue }

    var name: String {
        switch self {
        case .waste: return "Waste Reduction"
        case .energy: return "Energy Saving"
        case .water: return "Water Conservation"
        case .mobility: return "Green Mobility"
        case .community: return "Community Action"
        }
    }

    /// Fits in a tab-width grid cell and in the camera correction chips.
    var shortName: String {
        switch self {
        case .waste: return "Waste"
        case .energy: return "Energy"
        case .water: return "Water"
        case .mobility: return "Mobility"
        case .community: return "Community"
        }
    }

    var blurb: String {
        switch self {
        case .waste: return "Cut what you throw away"
        case .energy: return "Use less at home"
        case .water: return "Every litre counts"
        case .mobility: return "Get there greener"
        case .community: return "Act with your neighbours"
        }
    }

    var glyph: IconGlyph {
        switch self {
        case .waste: return .bag
        case .energy: return .bolt
        case .water: return .droplet
        case .mobility: return .bike
        case .community: return .people
        }
    }
}

/// What the user is here for. Multi-select during onboarding.
nonisolated enum Motivation: String, Codable, CaseIterable, Identifiable, Hashable {
    case saveMoney, health, planet, community

    var id: String { rawValue }

    var label: String {
        switch self {
        case .saveMoney: return "Save money"
        case .health: return "Feel healthier"
        case .planet: return "Protect the planet"
        case .community: return "Join my community"
        }
    }
}
