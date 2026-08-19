// Runnable check — run via ./tools/run-checks.sh
//
// Guards the contract between the local model and what goes to Firestore. Firestore's
// own encoder cannot be exercised without a live project, but everything that actually
// breaks in practice is structural — a document id that stops matching the security
// rules, or an enum that does not survive a round trip — and that is all testable here.
import Foundation

var fails = 0
func ok(_ l: String, _ pass: Bool) { if pass { print("  ok   \(l)") } else { print("  FAIL \(l)"); fails += 1 } }
func eq<T: Equatable>(_ l: String, _ g: T, _ w: T) {
    if g == w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails += 1 }
}

let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601

// --- log document id must match what the security rules expect -------------------
// rules: logId == request.resource.data.habitId + '_' + request.resource.data.localDate
let log = HabitLog(habitId: "food_reusable_bottle", localDate: "2026-08-24", source: .checklist)
eq("log remoteId", log.remoteId, "food_reusable_bottle_2026-08-24")
ok("remoteId is habitId + '_' + localDate", log.remoteId == "\(log.habitId)_\(log.localDate)")

// --- HabitLog round trip, including the points breakdown -------------------------
let priced = HabitLog(habitId: "h1", localDate: "2026-08-24", source: .visualSearch,
                      breakdown: PointsBreakdown(basePoints: 20, countedBasePoints: 15,
                                                 evidenceBonus: 1.2, streakMultiplier: 1.5,
                                                 priorityMultiplier: 1.0, finalPoints: 27))
let logBack = try dec.decode(HabitLog.self, from: enc.encode(priced))
eq("log finalPoints survives", logBack.finalPoints, 27)
eq("log countedBasePoints survives", logBack.countedBasePoints, 15)
eq("log source survives", logBack.source, HabitLog.Source.visualSearch)

// --- EarnedBadge.Source has associated values; it encodes as a nested map ---------
for source in [EarnedBadge.Source.threshold(7), .fight(fightId: "f1")] {
    let badge = EarnedBadge(badgeId: "b2", name: "7-Day Streak", source: source)
    let back = try dec.decode(EarnedBadge.self, from: enc.encode(badge))
    ok("badge round trip \(source)", back.source == source && back.badgeId == "b2" && back.name == badge.name)
}

// --- UserDocument must carry every scalar, and carry it back ---------------------
var state = PersistedState()
state.userName = "Vincent"
state.currentPoints = 1_640
state.streakDays = 12
state.longestStreak = 30
state.shieldsAvailable = 2
state.shieldedDates = ["2026-08-20"]
state.favouriteCategories = [.energy, .waste]
state.announcedBadgeIds = ["b1", "b2"]
state.favouriteFightIds = ["fight-a", "fight-b"]
state.announcedGlobeStage = 4
state.lastActiveDay = "2026-08-24"
state.decayBaselinePoints = 1_700
state.isOrganization = true

let doc = try dec.decode(UserDocument.self, from: enc.encode(UserDocument(state)))
var restored = PersistedState()
doc.apply(to: &restored)

eq("userName", restored.userName, "Vincent")
eq("currentPoints", restored.currentPoints, 1_640)
eq("streakDays", restored.streakDays, 12)
eq("longestStreak", restored.longestStreak, 30)
eq("shieldsAvailable", restored.shieldsAvailable, 2)
ok("shieldedDates", restored.shieldedDates == ["2026-08-20"])
ok("favouriteCategories", restored.favouriteCategories == [.energy, .waste])
ok("announcedBadgeIds", restored.announcedBadgeIds == ["b1", "b2"])
// Saved Fights replaced signup, so they are the only record that a user cared about an
// event before the day. Losing them on a reinstall would empty the "Saved" list.
ok("favouriteFightIds", restored.favouriteFightIds == ["fight-a", "fight-b"])
eq("announcedGlobeStage", restored.announcedGlobeStage, 4)
eq("lastActiveDay", restored.lastActiveDay, "2026-08-24")
eq("decayBaselinePoints", restored.decayBaselinePoints, 1_700)

// isOrganization is deliberately NOT applied from the server: it is admin-set, the
// rules refuse a client that changes it, and applying it locally would make the app
// briefly believe something it cannot act on.
ok("isOrganization is not applied from remote", restored.isOrganization == false)

// --- the document must not carry the arrays ---------------------------------------
state.logs = [log]
let json = String(data: try enc.encode(UserDocument(state)), encoding: .utf8) ?? ""
ok("UserDocument excludes logs", !json.contains("\"logs\""))
ok("UserDocument excludes earnedBadges", !json.contains("earnedBadges"))
ok("UserDocument excludes hostedFights", !json.contains("hostedFights"))

// --- "no local file" must be distinguishable from "an account at zero" -----------
//
// THE REINSTALL BUG. Deleting the app removes the state file but NOT the Firebase
// sign-in, which lives in the keychain and survives deletion. So the app relaunches
// already signed in, with nothing on disk. When `load` answered a missing file with a
// blank `PersistedState`, the app could not tell that apart from a real account at
// zero — so it treated the blank as truth, echoed it to Firestore, and destroyed the
// copy it was about to restore from. Streak, points and Earth all came back as 0.
let ghost = "synccheck-\(UUID().uuidString)"
PersistenceStore.wipe(userId: ghost)
ok("load returns nil when there is no file", PersistenceStore.load(userId: ghost) == nil)

var saved = PersistedState()
saved.currentPoints = 1_640
saved.streakDays = 12
PersistenceStore.save(saved, userId: ghost)
let reloaded = PersistenceStore.load(userId: ghost)
ok("load returns the state when the file is there", reloaded != nil)
eq("saved points survive a reload", reloaded?.currentPoints ?? -1, 1_640)
eq("saved streak survives a reload", reloaded?.streakDays ?? -1, 12)

PersistenceStore.wipe(userId: ghost)
ok("load returns nil again after a wipe", PersistenceStore.load(userId: ghost) == nil)

// --- attendance must carry what the security rules demand ------------------------
//
// rules: attendanceId == fightId + '_' + request.auth.uid
//     && request.resource.data.userId == request.auth.uid
//     && request.resource.data.code == fight(fightId).checkInCode
let attendance = FightAttendance(fightId: "f1", checkedInAt: Date(),
                                 localDate: "2026-08-24", userId: "uid123", code: "ABC234")
eq("attendance document id", "\(attendance.fightId)_\(attendance.userId)", "f1_uid123")

let attendanceBack = try dec.decode(FightAttendance.self, from: enc.encode(attendance))
eq("attendance userId survives", attendanceBack.userId, "uid123")
eq("attendance code survives", attendanceBack.code, "ABC234")

// --- an attendance record saved BEFORE those fields existed must still load -------
//
// This is the one that would have cost real accounts. `fightAttendance` is a dictionary
// inside `PersistedState`, and `decodeIfPresent` on a key whose VALUE fails to decode
// throws rather than returning nil — so a synthesized decoder here would not degrade to
// an empty dictionary, it would take the entire account down to blank.
var legacyState = PersistedState()
legacyState.userName = "Vincent"
legacyState.currentPoints = 1_640

var raw = try JSONSerialization.jsonObject(with: enc.encode(legacyState)) as? [String: Any] ?? [:]
raw["fightAttendance"] = [
    "f1": ["fightId": "f1",
           "checkedInAt": ISO8601DateFormatter().string(from: Date()),
           "localDate": "2026-08-24"]     // no userId, no code — the old shape
]
let recovered = try dec.decode(PersistedState.self,
                               from: JSONSerialization.data(withJSONObject: raw))

eq("a pre-Stage-5 account still loads its name", recovered.userName, "Vincent")
eq("a pre-Stage-5 account still loads its points", recovered.currentPoints, 1_640)
eq("the old attendance record survives", recovered.fightAttendance.count, 1)
eq("its missing userId reads as empty, not a throw", recovered.fightAttendance["f1"]?.userId ?? "?", "")

// --- every field must be somewhere, or deliberately nowhere ----------------------
//
// The reinstall bug is really one instance of "this field is not backed up anywhere".
// Rather than re-audit by hand each time, this fails whenever a field is added to
// `PersistedState` without a decision about where it lives remotely. If the new field
// is not meant to sync, add it to `notSynced` WITH a reason — that is the point.
let notSynced: [String: String] = [
    "isLoggedIn":      "dead field, kept only so old files still decode; userId replaced it",
    "fightSignups":    "dead — signup was replaced by favouriteFightIds, which does sync",
    "fightAttendance": "syncs to the SHARED /attendance/{fightId}_{uid}, not the user doc",
    "hostedFights":    "syncs to the SHARED /fights/{id} on publish, not the user doc",
    "hostScans":       "host's own scan roster; local by design, and /attendance replaces it",
]
let inSubcollections: Set<String> = ["logs", "earnedBadges"]

// Populate every optional, or synthesized `encode` skips the nil ones via
// `encodeIfPresent` and the key never appears to be counted.
state.lastEvaluatedDate = "2026-08-24"
state.lastDecayAppliedDay = "2026-08-24"
state.lastShieldGrantMonth = "2026-08"

let stateKeys = Set((try JSONSerialization.jsonObject(with: enc.encode(state)) as? [String: Any] ?? [:]).keys)
let docKeys = Set((try JSONSerialization.jsonObject(with: enc.encode(UserDocument(state))) as? [String: Any] ?? [:]).keys)

let unaccounted = stateKeys.subtracting(docKeys).subtracting(inSubcollections).subtracting(notSynced.keys)
ok("every PersistedState field is synced or listed as not-synced", unaccounted.isEmpty)
if !unaccounted.isEmpty {
    print("       unaccounted: \(unaccounted.sorted().joined(separator: ", "))")
    print("       → add it to UserDocument, or to `notSynced` above with a reason")
}

// And the reverse: a field listed as not-synced that no longer exists is stale.
let stale = Set(notSynced.keys).subtracting(stateKeys)
ok("no stale entries in the not-synced list", stale.isEmpty)
if !stale.isEmpty { print("       stale: \(stale.sorted().joined(separator: ", "))") }

print("\n  \(docKeys.count) fields synced · \(inSubcollections.count) subcollections · \(notSynced.count) deliberately local")
for (field, reason) in notSynced.sorted(by: { $0.key < $1.key }) {
    print("    local-only  \(field) — \(reason)")
}

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
