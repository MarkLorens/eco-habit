// Runnable check — run via ./tools/run-checks.sh
// Runnable check for badge evaluation. main has no test target.
let s = BadgeEvaluationService(); let today = "2026-08-20"
var fails = 0
func yes(_ l: String, _ g: Bool) { if g { print("  ok   \(l)") } else { print("  FAIL \(l)"); fails+=1 } }
func eq(_ l: String, _ g: Int, _ w: Int) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }

let cat = MockData.badges
eq("catalogue size", cat.count, 13)
yes("every badge kept its icon", cat.allSatisfy { !$0.icon.isEmpty })
yes("every badge kept its tier", cat.allSatisfy { !$0.tier.isEmpty })
yes("categoryMilestone badges name a category",
    cat.filter { $0.type == .categoryMilestone }.allSatisfy { $0.targetCategory != nil })

// seasonal + fightReward must never be auto-awarded
var st = PersistedState(); st.currentPoints = 999_999; st.streakDays = 999
let all = s.newlyEarned(from: cat, state: st, alreadyEarned: [], today: today)
yes("seasonal never auto-awarded", !all.contains { $0.badgeId == "b4" })

// earned is permanent: reach Flourishing then decay away
let flourishing = PointsConfiguration.default.threshold(for: .flourishing)
var rich = PersistedState(); rich.currentPoints = flourishing
let reef = s.newlyEarned(from: cat, state: rich, alreadyEarned: [], today: today).filter { $0.badgeId == "b6" }
eq("Reef Guardian awarded at Flourishing", reef.count, 1)
rich.earnedBadges = reef
rich.currentPoints = 10                                   // decay wipes the points
let shown = s.display(catalogue: cat, earned: rich.earnedBadges)
yes("badge survives decay", shown.first { $0.id == "b6" }!.isUnlocked)

// idempotent: already-earned is never re-awarded
let again = s.newlyEarned(from: cat, state: rich, alreadyEarned: ["b6"], today: today)
yes("no duplicate award", !again.contains { $0.badgeId == "b6" })

// orphan award (catalogue entry gone) is rebuilt, not dropped
let orphan = EarnedBadge(badgeId: "retired_x", name: "Retired One", source: .threshold(1))
let withOrphan = s.display(catalogue: cat, earned: [orphan])
yes("orphan award still shown", withOrphan.contains { $0.id == "retired_x" && $0.isUnlocked })

// progress
// Expectation derived the same way the code derives it, so this tests the RATIO
// rather than a number that moves whenever the ladder is retuned.
let part = flourishing / 2
var p = PersistedState(); p.currentPoints = part
let b6 = cat.first { $0.id == "b6" }!
eq("Reef progress at \(part)/\(flourishing) (%)",
   Int(s.progress(for: b6, state: p, today: today) * 100), part * 100 / flourishing)
print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
