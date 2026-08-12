import SwiftUI

enum HabitCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case waste
    case energy
    case water
    case food
    case transport
    case consumption

    var id: String { rawValue }

    var name: String {
        switch self {
        case .waste: return "Waste Reduction"
        case .energy: return "Energy Saving"
        case .water: return "Water Conservation"
        case .food: return "Food"
        case .transport: return "Transport"
        case .consumption: return "Consumption"
        }
    }

    var shortName: String {
        switch self {
        case .waste: return "Waste"
        case .energy: return "Energy"
        case .water: return "Water"
        case .food: return "Food"
        case .transport: return "Transport"
        case .consumption: return "Reuse"
        }
    }

    var blurb: String {
        switch self {
        case .waste: return "Cut what you throw away"
        case .energy: return "Use less at home"
        case .water: return "Every litre counts"
        case .food: return "Eat greener"
        case .transport: return "Get there cleaner"
        case .consumption: return "Buy less, reuse more"
        }
    }

    var glyph: IconGlyph {
        switch self {
        case .waste: return .bag
        case .energy: return .bolt
        case .water: return .droplet
        case .food: return .bag
        case .transport: return .bike
        case .consumption: return .bag
        }
    }
}

