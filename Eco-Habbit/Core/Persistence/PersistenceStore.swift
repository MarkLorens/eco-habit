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

    /// Set once, when the account finishes the onboarding questions. Lives here rather
    /// than in UserDefaults so it travels with the account: signing in on a second
    /// device should not ask the same questions again.
    var hasCompletedOnboarding = false

    /// Opt-in preference set from Settings — sorts favoured categories to the top of the
    /// Habits tab and biases the dashboard's suggestions. Empty is a valid state.
    var favouriteCategories: Set<HabitCategory> = []

    /// Onboarding question three — how much effort they want suggestions to ask of them.
    /// Read by `RecommendationService` to weight the friction bands.
    ///
    /// Optional, and `nil` means **not answered**, which is a different thing from
    /// `.easy`: accounts created before this field existed have no answer, and defaulting
    /// them to the low end would quietly bias every deck toward F1. The service scores
    /// `nil` as no signal instead.
    var preferredEffort: EffortLevel?

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

    /// Fights the user has saved. Replaces signup as the only thing an attendee does
    /// to a Fight before the day itself.
    ///
    /// Private to the user by design — a host cannot see who saved their event. It is a
    /// bookmark, not an RSVP, so it promises the organiser nothing and needs no
    /// cross-user write.
    var favouriteFightIds: Set<String> = []

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
    
    /// **Award records, not flags.** A badge is earned once and stays earned; the
    /// catalogue is joined onto these for display. Recomputing `isUnlocked` from
    /// live criteria meant decay could silently take a badge back.
    var earnedBadges: [EarnedBadge] = []

    // Badge unlock "event" testing
    var announcedBadgeIds: Set<String> = []

    /// Highest globe stage whose unlock animation has already been shown. Lags
    /// `globeStage` whenever a new stage is reached and catches up one step at a
    /// time, so every transition gets its own animation.
    ///
    /// Optional on purpose: synthesized `Codable` *throws* on a missing key rather than
    /// using the default, and `load()` reads any throw as "no save", so a non-optional
    /// field here would wipe every state file written before it existed. `nil` means
    /// "pre-dates this field" and `AppState` backfills it at launch.
    var announcedGlobeStage: Int?
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
        hasCompletedOnboarding = try v(.hasCompletedOnboarding, false)
        favouriteCategories = try v(.favouriteCategories, [])
        // Optional for the reason documented on the property: absent means the question
        // was never asked, not that the answer was "easy".
        preferredEffort     = try c.decodeIfPresent(EffortLevel.self, forKey: .preferredEffort)
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
        favouriteFightIds   = try v(.favouriteFightIds, [])
        logs                = try v(.logs, [])
        fightSignups        = try v(.fightSignups, [:])
        fightAttendance     = try v(.fightAttendance, [:])

        isOrganization      = try v(.isOrganization, false)
        orgName             = try v(.orgName, "")
        hostedFights        = try v(.hostedFights, [])
        hostScans           = try v(.hostScans, [:])
        earnedBadges        = try v(.earnedBadges, [])
        announcedBadgeIds   = try v(.announcedBadgeIds, [])
        // Mark's, and Optional for exactly the reason documented above — nil
        // means "pre-dates this field" and AppState backfills it at launch.
        announcedGlobeStage = try c.decodeIfPresent(Int.self, forKey: .announcedGlobeStage)
    }
}

/// The local store, **one file per account**.
///
/// It used to be a single `ecohabit-state.json` for the whole device, which was fine
/// while there was exactly one implicit user. With real sign-in two accounts on one
/// phone would silently overwrite each other, so the uid is now part of the filename.
enum PersistenceStore {

    /// The pre-accounts filename. Still read once, by `migrateLegacyFile`, and never
    /// written again.
    private static let legacyFileName = "ecohabit-state.json"

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Signed-out state lives under a reserved id rather than a separate code path, so
    /// there is only ever one way to read and write.
    static let signedOutUserId = "local"

    private static func url(for userId: String) -> URL {
        documents.appendingPathComponent("ecohabit-state-\(userId).json")
    }

    /// `nil` means **this device has no copy of this account** — a fresh install, or a
    /// device signing into the account for the first time.
    ///
    /// Optional rather than a blank `PersistedState`, because the caller has to be able
    /// to tell those two apart. Returning a blank state for a missing file is what let
    /// a reinstall upload zeros over a perfectly good server copy: the app could not
    /// distinguish "no data yet" from "an account that is genuinely at zero", so it
    /// treated the empty file as truth and echoed it upward.
    static func load(userId: String) -> PersistedState? {
        migrateLegacyFile(to: userId)
        guard let data = try? Data(contentsOf: url(for: userId)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // A file that exists but will not decode is still "this device has been here".
        // Falling back to blank keeps the app usable; `init(from:)` above is what makes
        // reaching this line very unlikely.
        return (try? decoder.decode(PersistedState.self, from: data)) ?? PersistedState()
    }

    static func save(_ state: PersistedState, userId: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url(for: userId), options: .atomic)
    }

    static func wipe(userId: String) {
        try? FileManager.default.removeItem(at: url(for: userId))
    }

    /// Adopt the pre-accounts file the first time an account reads.
    ///
    /// Without this, everything on the device before sign-in — points, streak, badges,
    /// every log — disappears the moment somebody signs in, because the app starts
    /// looking at a filename that has never existed.
    ///
    /// Moved rather than copied, and only when the destination is absent, so it happens
    /// exactly once and cannot resurrect itself over a real account later.
    private static func migrateLegacyFile(to userId: String) {
        let legacy = documents.appendingPathComponent(legacyFileName)
        let destination = url(for: userId)
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacy.path),
              !fm.fileExists(atPath: destination.path)
        else { return }
        try? fm.moveItem(at: legacy, to: destination)
    }
}
