import SwiftUI

enum HabitCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case energy
    case waste
    case actions
    case water
    case mobility
    case consumption

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy: return "Energy"
        case .waste: return "Waste"
        case .actions: return "Actions"
        case .water: return "Water"
        case .mobility: return "Mobility"
        case .consumption: return "Consumption"
        }
    }

    var caption: String {
        switch self {
        case .energy: return "Safe energy\nPower a better future"
        case .waste: return "Less waste today\nCleaner tomorrow"
        case .actions: return "Small steps\nCreate big impacts"
        case .water: return "Every drop matters"
        case .mobility: return "Move smarter\nTravel greener"
        case .consumption: return "Consume less\nLive better"
        }
    }
    
    nonisolated var icon: String {
        switch self {
        case .energy: return Tokens.Icons.energyIcon
        case .waste: return Tokens.Icons.wasteIcon
        case .actions: return Tokens.Icons.actionIcon
        case.water: return Tokens.Icons.waterIcon
        case .mobility: return Tokens.Icons.mobilityIcon
        case .consumption: return Tokens.Icons.consumptionIcon
        }
    }
    
    nonisolated var iconDetail: String {
        switch self {
        case .energy: return Tokens.Icons.energyDetail
        case .waste: return Tokens.Icons.wasteDetail
        case .actions: return Tokens.Icons.actionDetail
        case.water: return Tokens.Icons.waterDetail
        case .mobility: return Tokens.Icons.mobilityDetail
        case .consumption: return Tokens.Icons.consumptionDetail
        }
    }
    
    var tint: Color {
        switch self{
        case .energy: return Tokens.Palette.yellowCard
        case .waste: return Tokens.Palette.purpleCard
        case .actions: return Tokens.Palette.limeCard
        case .water: return Tokens.Palette.blueCard
        case .mobility: return Tokens.Palette.greenCard
        case .consumption: return Tokens.Palette.orangeCard
        }
    }
    
    var background: Color {
        switch self {
        case .energy:      return Tokens.Semantic.pointTagYellow
        case .waste:       return Tokens.Semantic.pointTagPurple
        case .actions:     return Tokens.Semantic.pointTagLime
        case .water:       return Tokens.Semantic.pointTagBlue
        case .mobility:    return Tokens.Semantic.pointTagGreen
        case .consumption: return Tokens.Semantic.pointTagOrange
        }
    }
    
    var iconScale: CGFloat {
        switch self {
        case .energy:      return 0.95
        case .waste:       return 1.04
        case .actions:     return 1.23
        case .water:       return 0.87
        case .mobility:    return 0.96
        case .consumption: return 1.06
        }
    }
}

