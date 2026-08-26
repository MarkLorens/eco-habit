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

// --- 2. the daily cap, where the cap actually lives -------------------------------
//
// The SHIPPED config disables the cap for the exhibition — `dailyBasePointsCap` is set
// beyond anything reachable, because a visitor hitting a ceiling after seven taps and
// then earning nothing reads as a broken app. So this exercises
// `PointsCalculationService` with an explicit small cap instead of driving it through
// `HabitRepository`, which uses the shipped one.
//
// That is the right place for it regardless: the cap is this type's rule. Testing it
// through the repository only ever worked by coincidence of the shipped number.
let capped = PointsCalculationService(config: {
    var c = PointsConfiguration.default
    c.dailyBasePointsCap = 100
    return c
}())

func priced(_ base: Int, used: Int) -> PointsBreakdown {
    capped.breakdown(habit: habit("h", base), hasEvidence: false,
                     currentStreak: 0, isPrioritized: false, basePointsUsedToday: used)
}

eq("under the cap pays in full", priced(25, used: 0).finalPoints, 25)
eq("still under the cap pays in full", priced(25, used: 50).finalPoints, 25)

// The log that straddles the ceiling pays the remainder, not nothing.
let straddle = priced(25, used: 95)
eq("the straddling log pays the remainder", straddle.finalPoints, 5)
ok("a partly-capped log is NOT flagged as capped", straddle.countedBasePoints > 0)

// Past it, a log pays nothing and says so — `countedBasePoints == 0` is what
// `HabitRepository` turns into `atDailyCap`.
let over = priced(25, used: 100)
eq("past the cap pays nothing", over.finalPoints, 0)
eq("past the cap counts nothing against the allowance", over.countedBasePoints, 0)
eq("well past the cap still pays nothing", priced(25, used: 500).finalPoints, 0)

// And the shipped config really is uncapped, or the exhibition build has a ceiling
// nobody meant to leave in.
var uncapped = PersistedState()
for i in 1...20 { log(habit("u\(i)", 20), &uncapped) }
eq("shipped config pays all 20 logs", uncapped.currentPoints, 400)

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
