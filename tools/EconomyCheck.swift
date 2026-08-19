// Runnable check — run via ./tools/run-checks.sh
//
// Guards the two invariants that keep the points economy honest, both of which were
// broken in shipped code and neither of which any other check covered:
//
//   1. Undo is the exact inverse of logging. It was not — `unlog` deleted the log and
//      left the points behind, so toggling one checkbox paid out every time.
//   2. A log that pays nothing says so. The daily cap silently clamped the payout to
//      zero and the app still announced "+0 pts", which reads as broken.
import Foundation

var fails = 0
func ok(_ l: String, _ pass: Bool) { if pass { print("  ok   \(l)") } else { print("  FAIL \(l)"); fails += 1 } }
func eq<T: Equatable>(_ l: String, _ g: T, _ w: T) {
    if g == w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails += 1 }
}

let today = "2026-08-18"
let cap = PointsConfiguration.default.dailyBasePointsCap

func habit(_ id: String, _ points: Int) -> Habit {
    Habit(id: id, name: id, category: .waste, frictionLevel: .f3,
          evidenceStrength: .notDetectable, basePoints: points)
}

@discardableResult
func log(_ h: Habit, _ s: inout PersistedState) -> HabitRepository.LogResult {
    HabitRepository.log(h, on: today, today: today, source: .checklist, in: &s)
}

// --- 1. undo must refund ---------------------------------------------------------
//
// THE FARM. `unlog` used to remove the log and leave `currentPoints` untouched, and
// because the daily cap is measured from the logs, removing one handed the allowance
// back too. Five toggles was 125 points with zero logs on record — reachable by any
// booth visitor tapping a checkbox on and off.
var s = PersistedState()
let bottle = habit("bottle", 25)

log(bottle, &s)
let afterLog = s.currentPoints
ok("logging pays something", afterLog > 0)

HabitRepository.unlog("bottle", on: today, today: today, habits: [bottle], in: &s)
eq("undo returns points to where they started", s.currentPoints, 0)
eq("undo removes the log", s.logs.count, 0)

for _ in 1...5 {
    log(bottle, &s)
    HabitRepository.unlog("bottle", on: today, today: today, habits: [bottle], in: &s)
}
eq("five log/undo cycles net zero", s.currentPoints, 0)
eq("five log/undo cycles leave no logs", s.logs.count, 0)

// Re-logging after an undo pays the same as the first time — the allowance came back
// with the log, which is correct, and the points came back with it, which is the fix.
log(bottle, &s)
eq("re-logging after undo pays the normal amount", s.currentPoints, afterLog)

// --- undo must not overdraw ------------------------------------------------------
// Decay can take `currentPoints` below what a log originally paid.
var drained = PersistedState()
log(bottle, &drained)
drained.currentPoints = 3            // as if decay had run
HabitRepository.unlog("bottle", on: today, today: today, habits: [bottle], in: &drained)
ok("undo cannot drive points negative", drained.currentPoints >= 0)

// --- 2. hitting the daily cap must be visible ------------------------------------
var capped = PersistedState()
var paid = 0
var reachedCap = false

for i in 1...12 {
    let result = log(habit("h\(i)", 25), &capped)
    guard case .logged(let points, let atDailyCap) = result else {
        ok("log \(i) unexpectedly refused", false); break
    }
    paid += points
    if atDailyCap {
        reachedCap = true
        eq("a log flagged atDailyCap pays nothing", points, 0)
        break
    }
    ok("log \(i) pays \(points) and is not flagged", points > 0)
}

ok("the cap is actually reachable", reachedCap)
eq("total base points paid stops at the cap", paid, cap)

// A capped log is still a REAL log. It counts for the streak, for badges and for
// history — which is exactly why it is a flag on success rather than a refusal.
let cappedCount = capped.logs.count
ok("the capped log is still recorded", cappedCount > 0)
ok("the capped log still advanced the streak", capped.streakDays == 1)
eq("every attempted log is on record", capped.logs.filter { $0.localDate == today }.count, cappedCount)

// And a partial cap — the log that straddles the ceiling — pays the remainder rather
// than nothing, so it must NOT be flagged.
var partial = PersistedState()
log(habit("big", cap - 5), &partial)
let straddle = log(habit("straddle", 25), &partial)
if case .logged(let points, let atDailyCap) = straddle {
    eq("the straddling log pays the remainder", points, 5)
    ok("a partly-capped log is not flagged as capped", !atDailyCap)
} else {
    ok("the straddling log was logged", false)
}

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
