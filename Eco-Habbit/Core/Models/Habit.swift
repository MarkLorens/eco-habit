import Foundation

/// A catalogue entry, loaded from `Resources/habits.json` and never mutated.
/// Per-day state lives in `HabitLog`, so the checklist, the camera and the dashboard
/// all read one source of truth (PRD §9.7).
struct Habit: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: HabitCategory
    let tier: Tier
    let frequency: Frequency
    let isCameraDetectable: Bool
    var shortDescription: String = ""
    var howTo: [String] = []
    var impactStatement: String = ""
    /// PRD §3.5: mandatory for every habit, no unsourced claims. Optional in the type
    /// only because the catalogue is still being researched — see §12 Q2.
    var impactSource: String? = nil

    var basePoints: Int { isFoundation ? 0 : tier.points }
    var isFoundation: Bool { frequency == .foundation }

    /// PRD §3.3 — three tiers by combined impact × effort.
    enum Tier: String, Codable {
        case light      // Tier 1
        case moderate   // Tier 2
        case high       // Tier 3

        var points: Int {
            switch self {
            case .light: return 5
            case .moderate: return 10
            case .high: return 20
            }
        }

        var label: String {
            switch self {
            case .light: return "Light"
            case .moderate: return "Moderate"
            case .high: return "High"
            }
        }
    }

    /// PRD §3.2. Encoded in JSON as `"daily"`, `"foundation"`, or `"weekly"` paired with
    /// a sibling `weeklyLimit` key on the habit object — *not* nested inside `frequency`.
    enum Frequency: Codable, Hashable {
        case daily
        case weekly(Int)
        case foundation
    }
}

// MARK: - Decoding

extension Habit {
    private enum CodingKeys: String, CodingKey {
        case id, name, category, tier, frequency, weeklyLimit, isCameraDetectable
        case shortDescription, howTo, impactStatement, impactSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(HabitCategory.self, forKey: .category)
        tier = try container.decode(Tier.self, forKey: .tier)
        isCameraDetectable = try container.decodeIfPresent(Bool.self, forKey: .isCameraDetectable) ?? false
        shortDescription = try container.decodeIfPresent(String.self, forKey: .shortDescription) ?? ""
        howTo = try container.decodeIfPresent([String].self, forKey: .howTo) ?? []
        impactStatement = try container.decodeIfPresent(String.self, forKey: .impactStatement) ?? ""
        impactSource = try container.decodeIfPresent(String.self, forKey: .impactSource)

        // `weeklyLimit` sits alongside `frequency`, so it is read from the habit's own
        // container. Reading it through a nested container is what silently emptied the
        // whole catalogue before: `frequency` is a string, and asking a string for a
        // keyed container throws, which `try?` at the call site then swallowed.
        switch try container.decode(String.self, forKey: .frequency) {
        case "daily": frequency = .daily
        case "foundation": frequency = .foundation
        case "weekly":
            let limit = try container.decodeIfPresent(Int.self, forKey: .weeklyLimit) ?? 1
            frequency = .weekly(limit)
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .frequency, in: container,
                debugDescription: "Unknown frequency '\(other)' for habit '\(id)'"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(tier, forKey: .tier)
        try container.encode(isCameraDetectable, forKey: .isCameraDetectable)
        try container.encode(shortDescription, forKey: .shortDescription)
        try container.encode(howTo, forKey: .howTo)
        try container.encode(impactStatement, forKey: .impactStatement)
        try container.encodeIfPresent(impactSource, forKey: .impactSource)

        switch frequency {
        case .daily: try container.encode("daily", forKey: .frequency)
        case .foundation: try container.encode("foundation", forKey: .frequency)
        case .weekly(let limit):
            try container.encode("weekly", forKey: .frequency)
            try container.encode(limit, forKey: .weeklyLimit)
        }
    }
}

// MARK: - Logs

/// One completion. Authoritative — every number in the app is derived from these
/// (PRD §9.7: never store a derived total).
struct HabitLog: Codable, Hashable, Identifiable {
    var id = UUID()
    let habitId: String
    /// Written at log time, never re-derived from `loggedAt` (PRD §9.5).
    let localDate: String
    let loggedAt: Date
    let source: Source

    init(id: UUID = UUID(), habitId: String, localDate: String, loggedAt: Date = Date(), source: Source) {
        self.id = id
        self.habitId = habitId
        self.localDate = localDate
        self.loggedAt = loggedAt
        self.source = source
    }

    enum Source: String, Codable {
        case checklist
        case visualSearch
        case fightCheckIn
    }
}

/// Catalogue entry joined with today's state — what a list row renders.
struct HabitRow: Identifiable, Hashable {
    let habit: Habit
    let log: HabitLog?

    var id: String { habit.id }
    var isCompletedToday: Bool { log != nil }
}
