import Foundation

/// Firestore document id for a log: `{habitId}_{localDate}`.
///
/// Deliberately not the log's `UUID`. Making the id the natural key is what turns
/// once-per-day from a rule the client is trusted to follow into something the database
/// enforces — a second log that day is a write to an existing document, which the
/// security rules refuse. No unique constraint, no race, no lock.
///
/// Lives here rather than beside the Firestore client so it can be tested without
/// linking Firebase.
extension HabitLog {
    var remoteId: String { "\(habitId)_\(localDate)" }
}

/// What `/users/{uid}` holds — **the scalars only**.
///
/// `PersistedState` is one blob containing `logs`, `earnedBadges`, `hostedFights` and
/// the rest inline. That is fine for a file on disk and wrong for Firestore: a document
/// has a hard **1 MB limit**, and a user who logs every day would eventually cross it
/// and simply stop being able to save. Collections are also the only thing that can be
/// queried, and the cooldown check needs a query.
///
/// So the arrays move to subcollections (Stage 4) and this carries what is left. It is a
/// deliberate second shape rather than a `Codable` trick on `PersistedState`: the two
/// have different jobs, and letting the local blob dictate the remote schema is what
/// causes 1 MB documents in the first place.
///
/// `Set` becomes `[String]` throughout — Firestore has no set type. Order is not
/// meaningful and the mapping back re-forms the set.
struct UserDocument: Codable, Equatable {

    var userName: String
    var email: String
    var favouriteCategories: [String]
    var notificationsEnabled: Bool

    var currentPoints: Int
    var streakDays: Int
    var longestStreak: Int
    var lastActiveDay: String?
    var lastEvaluatedDate: String?

    var decayBaselinePoints: Int?
    var lastDecayAppliedDay: String?

    var shieldsAvailable: Int
    var shieldedDates: [String]
    var lastShieldGrantMonth: String?

    var fightAttendedDates: [String]
    var favouriteFightIds: [String]

    var isOrganization: Bool
    var orgName: String

    var announcedBadgeIds: [String]
    var announcedGlobeStage: Int?

    // MARK: - Decoding

    /// Hand-written, and it has to stay that way — for the third time in this codebase.
    ///
    /// Synthesized `Decodable` **ignores property defaults**: a key missing from the
    /// document throws `keyNotFound` rather than falling back. Every document already in
    /// Firestore was written by an older build, so **adding one field here breaks the
    /// fetch for every existing account** — and because the fetch is the first thing
    /// `pullRemoteState` does, the failure takes the whole sync down with it.
    ///
    /// That is not hypothetical. `favouriteFightIds` was added on 18 Aug and every live
    /// account immediately failed with
    /// `keyNotFound: favouriteFightIds`, which read as "signed in but nothing syncs".
    /// `PersistedState` and `FightAttendance` already had this treatment; this did not.
    ///
    /// Reading every field with `decodeIfPresent` makes adding a field a non-event,
    /// which is the only way a schema that lives on other people's devices can evolve.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: k) ?? fallback
        }

        userName             = try v(.userName, "")
        email                = try v(.email, "")
        favouriteCategories  = try v(.favouriteCategories, [])
        notificationsEnabled = try v(.notificationsEnabled, true)

        currentPoints        = try v(.currentPoints, 0)
        streakDays           = try v(.streakDays, 0)
        longestStreak        = try v(.longestStreak, 0)
        lastActiveDay        = try c.decodeIfPresent(String.self, forKey: .lastActiveDay)
        lastEvaluatedDate    = try c.decodeIfPresent(String.self, forKey: .lastEvaluatedDate)

        decayBaselinePoints  = try c.decodeIfPresent(Int.self, forKey: .decayBaselinePoints)
        lastDecayAppliedDay  = try c.decodeIfPresent(String.self, forKey: .lastDecayAppliedDay)

        shieldsAvailable     = try v(.shieldsAvailable, 0)
        shieldedDates        = try v(.shieldedDates, [])
        lastShieldGrantMonth = try c.decodeIfPresent(String.self, forKey: .lastShieldGrantMonth)

        fightAttendedDates   = try v(.fightAttendedDates, [])
        favouriteFightIds    = try v(.favouriteFightIds, [])

        isOrganization       = try v(.isOrganization, false)
        orgName              = try v(.orgName, "")

        announcedBadgeIds    = try v(.announcedBadgeIds, [])
        announcedGlobeStage  = try c.decodeIfPresent(Int.self, forKey: .announcedGlobeStage)
    }

    // MARK: - Mapping

    init(_ state: PersistedState) {
        userName = state.userName
        email = state.email
        favouriteCategories = state.favouriteCategories.map(\.rawValue).sorted()
        notificationsEnabled = state.notificationsEnabled

        currentPoints = state.currentPoints
        streakDays = state.streakDays
        longestStreak = state.longestStreak
        lastActiveDay = state.lastActiveDay
        lastEvaluatedDate = state.lastEvaluatedDate

        decayBaselinePoints = state.decayBaselinePoints
        lastDecayAppliedDay = state.lastDecayAppliedDay

        shieldsAvailable = state.shieldsAvailable
        shieldedDates = state.shieldedDates.sorted()
        lastShieldGrantMonth = state.lastShieldGrantMonth

        fightAttendedDates = state.fightAttendedDates.sorted()
        favouriteFightIds = state.favouriteFightIds.sorted()

        isOrganization = state.isOrganization
        orgName = state.orgName

        announcedBadgeIds = state.announcedBadgeIds.sorted()
        announcedGlobeStage = state.announcedGlobeStage
    }

    /// Overlay this document onto local state.
    ///
    /// **Only the fields this document owns are touched.** `logs`, `earnedBadges`,
    /// `hostedFights` and the fight dictionaries are left exactly as they were, because
    /// they live in subcollections and are not this document's to overwrite — clearing
    /// them here would delete a user's history on every sign-in.
    ///
    /// `isOrganization` is deliberately **not** applied *here* — `AppState.pullRemoteState`
    /// copies it down separately and unconditionally. It is the one field the server
    /// owns, so it must survive the "does this device already have a file" gate that
    /// governs everything else: the device being promoted to an organisation is
    /// precisely the one that already has local state.
    func apply(to state: inout PersistedState) {
        state.userName = userName
        state.email = email
        state.favouriteCategories = Set(favouriteCategories.compactMap(HabitCategory.init(rawValue:)))
        state.notificationsEnabled = notificationsEnabled

        state.currentPoints = currentPoints
        state.streakDays = streakDays
        state.longestStreak = longestStreak
        state.lastActiveDay = lastActiveDay
        state.lastEvaluatedDate = lastEvaluatedDate

        state.decayBaselinePoints = decayBaselinePoints
        state.lastDecayAppliedDay = lastDecayAppliedDay

        state.shieldsAvailable = shieldsAvailable
        state.shieldedDates = Set(shieldedDates)
        state.lastShieldGrantMonth = lastShieldGrantMonth

        state.fightAttendedDates = Set(fightAttendedDates)
        state.favouriteFightIds = Set(favouriteFightIds)

        state.orgName = orgName

        state.announcedBadgeIds = Set(announcedBadgeIds)
        state.announcedGlobeStage = announcedGlobeStage
    }
}
