import Foundation

/// The whole local database, one `Codable` blob. Small enough that an atomic write per
/// mutation beats Core Data at this stage; Phase 3 replaces it with SwiftData.
///
/// **Nothing summable is stored here** (PRD §9.7). `logs` is authoritative; points,
/// history and category counts are all derived from it. `vitality`, `streakDays` and
/// `shieldsAvailable` are the deliberate exceptions — they are the *output* of the
/// evaluation loop rather than a cached sum of anything.
struct PersistedState: Codable {
    var isLoggedIn = false
    var userName = ""
    var email = ""

    /// Opt-in preference set from Settings — sorts favoured categories to the top of the
    /// Habits tab and biases the dashboard's suggestions. Empty is a valid state.
    var favouriteCategories: Set<HabitCategory> = []

    var notificationsEnabled = true

    var vitality = VitalityEngine.startingVitality
    var streakDays = 0
    var longestStreak = 0
    var lastActiveDay: String?
    /// The last day the evaluation loop has **scored**. See `EvaluationLoop`.
    var lastEvaluatedDate: String?

    var shieldsAvailable = 0
    /// Days a Shield covers. The consecutive-run limit is derived from this, not stored.
    var shieldedDates: Set<String> = []
    /// Idempotency key for the monthly Shield grant.
    var lastShieldGrantMonth: String?

    /// PRD §4.5 — days a Fight was attended. `EvaluationLoop` reads this to apply +10;
    /// `fightAttendance` below is the record it is derived from.
    var fightAttendedDates: Set<String> = []

    var logs: [HabitLog] = []

    /// Keyed by fight id — the local stand-in for `/events/{id}/signups/{uid}`.
    var fightSignups: [String: FightSignup] = [:]
    /// Keyed by fight id — the local stand-in for `/attendance/{eventId}_{uid}`, where
    /// the composite document ID gives one-check-in-per-attendee for free (§9.3).
    var fightAttendance: [String: FightAttendance] = [:]

    // MARK: - Host mode (PRD §6.5.1)

    /// PRD §4.3 — verified organisations only, and verification is a human
    /// flipping a flag. Until the admin surface exists this is set from the
    /// debug menu; it is **never** user-writable in the shipped UI, and §9.6
    /// makes that a Security Rules requirement in Phase 10.
    var isOrganization = false
    var orgName = ""

    /// Events this account hosts. Seeded Fights live in the bundle; these live
    /// here, and the two are merged for browsing.
    var hostedFights: [Fight] = []
    /// Scans taken on this device, keyed by fight id.
    var hostScans: [String: [HostScan]] = [:]
    
    // Badge unlock "event" testing
    var announcedBadgeIds: Set<String> = []

    /// Customer-side saved ("loved") events, by Fight id. Optional so state
    /// files written before this field existed still decode; read it through
    /// `AppState.isLoved(_:)` which defaults to empty.
    var lovedFightIds: Set<String>? = []
}

enum PersistenceStore {
    private static let fileName = "ecohabit-state.json"

    private static var url: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func load() -> PersistedState {
        guard let data = try? Data(contentsOf: url) else { return PersistedState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PersistedState.self, from: data)) ?? PersistedState()
    }

    static func save(_ state: PersistedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: url)
    }
}
