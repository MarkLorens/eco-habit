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

    /// **Cumulative Earth points.** Unbounded and only ever spent by decay — this
    /// is the number the stages are drawn against.
    ///
    /// Replaces the old 0–100 `vitality`, which was a *level*, not a total. The
    /// two cannot be migrated into one another: 30 vitality is not 30 points and
    /// never was. An account carried over from that model starts the new Earth at
    /// zero, which is honest — its history was scored under different rules.
    var currentPoints = 0

    var streakDays = 0
    var longestStreak = 0
    var lastActiveDay: String?
    /// The last day the evaluation loop has **scored**. See `EvaluationLoop`.
    var lastEvaluatedDate: String?

    /// Points at the START of the current absence. The "drop at most one stage"
    /// limit is measured from here, not from the current total — measured from
    /// the current total, someone who opens the app every few days during a long
    /// absence loses a stage on every single open.
    ///
    /// Cleared when anything is logged, because the absence is over.
    var decayBaselinePoints: Int?
    /// Last day decay was charged for, so re-opening the app twice in a day
    /// cannot charge twice. Cleared on log, like the baseline.
    var lastDecayAppliedDay: String?

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

    init() {}

    // MARK: - Decoding

    /// Hand-written, and it has to stay that way.
    ///
    /// Synthesized `Decodable` **ignores property default values** — a key missing
    /// from the file throws `keyNotFound` rather than falling back. `load()` then
    /// swallows that into a fresh `PersistedState()`, so adding one field to this
    /// struct silently wiped every existing account: name, streak, logs, badges,
    /// all of it, with no error anywhere.
    ///
    /// That was not hypothetical. `announcedBadgeIds` was added on 18 Aug and any
    /// state saved before it decoded to a blank account on the next launch.
    ///
    /// Reading every field with `decodeIfPresent` makes adding a field a
    /// non-event, which is the only way this is safe to keep evolving.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: k) ?? fallback
        }

        isLoggedIn          = try v(.isLoggedIn, false)
        userName            = try v(.userName, "")
        email               = try v(.email, "")
        favouriteCategories = try v(.favouriteCategories, [])
        notificationsEnabled = try v(.notificationsEnabled, true)

        currentPoints       = try v(.currentPoints, 0)
        streakDays          = try v(.streakDays, 0)
        longestStreak       = try v(.longestStreak, 0)
        lastActiveDay       = try c.decodeIfPresent(String.self, forKey: .lastActiveDay)
        lastEvaluatedDate   = try c.decodeIfPresent(String.self, forKey: .lastEvaluatedDate)

        decayBaselinePoints = try c.decodeIfPresent(Int.self, forKey: .decayBaselinePoints)
        lastDecayAppliedDay = try c.decodeIfPresent(String.self, forKey: .lastDecayAppliedDay)

        shieldsAvailable    = try v(.shieldsAvailable, 0)
        shieldedDates       = try v(.shieldedDates, [])
        lastShieldGrantMonth = try c.decodeIfPresent(String.self, forKey: .lastShieldGrantMonth)

        fightAttendedDates  = try v(.fightAttendedDates, [])
        logs                = try v(.logs, [])
        fightSignups        = try v(.fightSignups, [:])
        fightAttendance     = try v(.fightAttendance, [:])

        isOrganization      = try v(.isOrganization, false)
        orgName             = try v(.orgName, "")
        hostedFights        = try v(.hostedFights, [])
        hostScans           = try v(.hostScans, [:])
        announcedBadgeIds   = try v(.announcedBadgeIds, [])
    }
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
