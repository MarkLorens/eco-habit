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

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
