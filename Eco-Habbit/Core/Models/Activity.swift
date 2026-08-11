import Foundation

struct Habit: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: HabitCategory
    let tier: Tier
    let frequency: Frequency
    let isCameraDetectable: Bool
    var impactStatement: String = ""
    var citationURL: String? = nil

    var basePoints: Int { tier.points }
    var isFoundation: Bool { frequency == .foundation }

    enum Tier: String, Codable {
        case light
        case moderate
        case high

        var points: Int {
            switch self {
            case .light: return 5
            case .moderate: return 10
            case .high: return 20
            }
        }
    }

    enum Frequency: Codable, Hashable {
        case daily
        case weekly(Int)
        case foundation

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "daily": self = .daily
            case "foundation": self = .foundation
            default:
                let keyed = try decoder.container(keyedBy: CodingKeys.self)
                let limit = try keyed.decodeIfPresent(Int.self, forKey: .weeklyLimit) ?? 1
                self = .weekly(limit)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .daily: try container.encode("daily")
            case .foundation: try container.encode("foundation")
            case .weekly(let n): try container.encode("weekly")
                var keyed = encoder.container(keyedBy: CodingKeys.self)
                try keyed.encode(n, forKey: .weeklyLimit)
            }
        }

        enum CodingKeys: String, CodingKey {
            case weeklyLimit
        }
    }
}

struct HabitLog: Codable, Hashable, Identifiable {
    var id = UUID()
    let habitId: String
    let localDate: String
    let source: Source

    enum Source: String, Codable {
        case checklist
        case visualSearch
        case fightCheckIn
    }
}

struct HabitRow: Identifiable, Hashable {
    let habit: Habit
    let log: HabitLog?

    var id: String { habit.id }
    var isCompletedToday: Bool { log != nil }
}

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tier: String
    let detail: String
    let requirement: Requirement

    enum Requirement: Codable, Hashable {
        case totalActions(Int)
        case streak(Int)
        case vitality(Int)
        case categoryActions(HabitCategory, Int)
        case seasonal
    }
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let categoryRaw: String
    let points: Int
    let date: Date
    let sourceRaw: String

    var category: HabitCategory? { HabitCategory(rawValue: categoryRaw) }
    var source: HabitLog.Source? { HabitLog.Source(rawValue: sourceRaw) }
}

struct Award: Identifiable, Equatable {
    let id = UUID()
    let habit: Habit
    let points: Int
}

struct Toast: Identifiable, Equatable {
    enum Kind {
        case success, info, warning

        var tint: Color {
            switch self {
            case .success: return Theme.C.accent2_600
            case .info: return Theme.C.neutral800
            case .warning: return Theme.C.accent600
            }
        }

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

import SwiftUI
