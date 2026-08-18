// Runnable check — run via ./tools/run-checks.sh
// Runnable check for the streak rule. main has no test target, so this is
// the substitute — it compiles the REAL sources, not a copy.
let s = StreakService()
var fails = 0
func check(_ label: String, _ got: Int, _ want: Int) {
    if got == want { print("  ok   \(label): \(got)") }
    else { print("  FAIL \(label): got \(got), want \(want)"); fails += 1 }
}
// outcome(): logging on 2026-08-20
check("no history -> 1",
      s.outcome(lastActiveDay: nil, currentStreak: 0, shieldedDates: [], loggingOn: "2026-08-20").newStreak, 1)
check("same day  -> unchanged",
      s.outcome(lastActiveDay: "2026-08-20", currentStreak: 7, shieldedDates: [], loggingOn: "2026-08-20").newStreak, 7)
check("gap 1     -> extend",
      s.outcome(lastActiveDay: "2026-08-19", currentStreak: 7, shieldedDates: [], loggingOn: "2026-08-20").newStreak, 8)
check("gap 2 no shield -> reset",
      s.outcome(lastActiveDay: "2026-08-18", currentStreak: 7, shieldedDates: [], loggingOn: "2026-08-20").newStreak, 1)
check("gap 2 shielded  -> extend",
      s.outcome(lastActiveDay: "2026-08-18", currentStreak: 7, shieldedDates: ["2026-08-19"], loggingOn: "2026-08-20").newStreak, 8)
check("gap 3 shielded  -> still reset",
      s.outcome(lastActiveDay: "2026-08-17", currentStreak: 7, shieldedDates: ["2026-08-18","2026-08-19"], loggingOn: "2026-08-20").newStreak, 1)
check("future date -> untouched",
      s.outcome(lastActiveDay: "2026-08-25", currentStreak: 7, shieldedDates: [], loggingOn: "2026-08-20").newStreak, 7)
// displayStreak()
check("display: logged today",     s.displayStreak(lastActiveDay: "2026-08-20", currentStreak: 12, shieldedDates: [], asOf: "2026-08-20"), 12)
check("display: logged yesterday", s.displayStreak(lastActiveDay: "2026-08-19", currentStreak: 12, shieldedDates: [], asOf: "2026-08-20"), 12)
check("display: 2 days, no shield -> 0", s.displayStreak(lastActiveDay: "2026-08-18", currentStreak: 12, shieldedDates: [], asOf: "2026-08-20"), 0)
check("display: 2 days, shielded",       s.displayStreak(lastActiveDay: "2026-08-18", currentStreak: 12, shieldedDates: ["2026-08-19"], asOf: "2026-08-20"), 12)
check("display: never logged -> 0",      s.displayStreak(lastActiveDay: nil, currentStreak: 12, shieldedDates: [], asOf: "2026-08-20"), 0)
print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
