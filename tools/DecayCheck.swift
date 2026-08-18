// Runnable check — run via ./tools/run-checks.sh
// Runnable check for decay. main has no test target — this compiles the REAL sources.
let d = DecayService(); let c = PointsConfiguration.default
var fails = 0
func mk(points: Int, lastActive: String?, baseline: Int? = nil, applied: String? = nil) -> PersistedState {
    var s = PersistedState(); s.currentPoints = points; s.lastActiveDay = lastActive
    s.decayBaselinePoints = baseline; s.lastDecayAppliedDay = applied; return s
}
func eq(_ l: String, _ g: Int, _ w: Int) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }
func yes(_ l: String, _ g: Bool) { if g { print("  ok   \(l)") } else { print("  FAIL \(l)"); fails+=1 } }

print("grace=\(c.decayGracePeriodDays)d warn=\(c.decayWarningDayThreshold)d rate=\(c.decayRatePerDay) floor=\(c.decayPointsFloor) maxDrop=\(c.maxStageDropPerAbsence)")

var s = mk(points: 1000, lastActive: "2026-08-20")
eq("day 0 — no decay", d.apply(to: &s, today: "2026-08-20").pointsAfter, 1000)

s = mk(points: 1000, lastActive: "2026-08-14")
let o6 = d.apply(to: &s, today: "2026-08-20")     // 6 days: inside grace
eq("day 6 — inside grace", o6.pointsAfter, 1000)
yes("day 6 — warns (>=5)", o6.shouldWarn)

s = mk(points: 1000, lastActive: "2026-08-13")
eq("day 7 — grace boundary, no decay", d.apply(to: &s, today: "2026-08-20").pointsAfter, 1000)

// day 8: one chargeable day -> 1000 * 0.98 = 980
s = mk(points: 1000, lastActive: "2026-08-12")
eq("day 8 — one day charged", d.apply(to: &s, today: "2026-08-20").pointsAfter, 980)

// idempotent within the same day
s = mk(points: 1000, lastActive: "2026-08-12")
_ = d.apply(to: &s, today: "2026-08-20")
eq("same day twice — unchanged", d.apply(to: &s, today: "2026-08-20").pointsAfter, 980)

// points floor
s = mk(points: 160, lastActive: "2026-06-01")
let lo = d.apply(to: &s, today: "2026-08-20")
eq("floor holds at 150", lo.pointsAfter, 150)
yes("reports points floor", lo.limitedByPointsFloor)

// already below floor must not be RAISED
s = mk(points: 100, lastActive: "2026-06-01")
eq("below floor — not raised", d.apply(to: &s, today: "2026-08-20").pointsAfter, 100)

// one-stage-drop limit: 2500 (restored) can fall no further than flourishing (1600)
s = mk(points: 2500, lastActive: "2026-01-01")
let st = d.apply(to: &s, today: "2026-08-20")
eq("max one stage drop", st.pointsAfter, 1600)
yes("reports stage floor", st.limitedByStageFloor)

// never logged -> untouched
s = mk(points: 900, lastActive: nil)
eq("never logged — untouched", d.apply(to: &s, today: "2026-08-20").pointsAfter, 900)

// clock moved backwards -> untouched
s = mk(points: 900, lastActive: "2026-09-20")
eq("future date — untouched", d.apply(to: &s, today: "2026-08-20").pointsAfter, 900)

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
