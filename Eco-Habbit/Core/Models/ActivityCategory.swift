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
    
    var icon: String {
        switch self {
        case .energy: return Tokens.Icons.lightBulb
        case .waste: return Tokens.Icons.trash
        case .actions: return Tokens.Icons.tree
        case.water: return Tokens.Icons.water
        case .mobility: return Tokens.Icons.smoke
        case .consumption: return Tokens.Icons.burger
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
}

