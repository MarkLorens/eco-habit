// Runnable check — run via ./tools/run-checks.sh
import Foundation
// Runnable check for the QR payload and code-based check-in. main has no test target.
var fails = 0
func yes(_ l: String, _ g: Bool) { if g { print("  ok   \(l)") } else { print("  FAIL \(l)"); fails+=1 } }
func eq<T: Equatable>(_ l: String, _ g: T, _ w: T) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }

let now = Date(timeIntervalSince1970: 1_800_000_000)
func fight(_ id: String = "f1", code: String = "BERAWA", startsIn h: Double = 0,
           status: Fight.Status = .published, tier: EventTier = .standard) -> Fight {
    let s = now.addingTimeInterval(h*3600)
    return Fight(id: id, title: "Cleanup", type: .beachCleanup,
                 startsAt: s, endsAt: s.addingTimeInterval(3*3600),
                 status: status, tier: tier, checkInCode: code)
}

// --- payload round trip ---
eq("payload", fight().checkInPayload, "ecohabit://fight/BERAWA")
eq("parse back", Fight.code(fromPayload: "ecohabit://fight/BERAWA"), "BERAWA")

// THE GATE: anything without the scheme must resolve to nothing at all
for raw in ["BERAWA", "https://example.com/fight/BERAWA", "WIFI:S:Cafe;T:WPA;P:x;;",
            "ecohabit://badge/BERAWA", "ecohabit://fight/", "", "   "] {
    yes("rejected: \(raw.isEmpty ? "(empty)" : raw)", Fight.code(fromPayload: raw) == nil)
}
// case / whitespace tolerance
yes("tolerates case+space", fight().matchesCheckInCode(Fight.code(fromPayload: "  ECOHABIT://FIGHT/berawa\n") ?? ""))

// --- deterministic seeding: same id => same code, every time ---
eq("seeded code is stable", Fight.makeCheckInCode(seed: "f1"), Fight.makeCheckInCode(seed: "f1"))
yes("different ids differ", Fight.makeCheckInCode(seed: "f1") != Fight.makeCheckInCode(seed: "f2"))
yes("no ambiguous chars", Fight.makeCheckInCode(seed: "f1").allSatisfy { !"O0I1".contains($0) })

// --- check-in ---
var s = PersistedState()
if case .checkedIn(let pts) = FightRepository.checkIn(to: fight(), code: "BERAWA", in: &s, now: now) {
    eq("standard tier pays 75", pts, 75)
} else { print("  FAIL check-in did not succeed"); fails += 1 }
eq("points credited", s.currentPoints, 75)
eq("second scan pays nothing", FightRepository.checkIn(to: fight(), code: "BERAWA", in: &s, now: now), .alreadyCheckedIn)
eq("points unchanged", s.currentPoints, 75)

var s2 = PersistedState()
eq("wrong code", FightRepository.checkIn(to: fight(), code: "ZZZZZZ", in: &s2, now: now), .wrongCode)
eq("draft reports notPublished, not windowClosed",
   FightRepository.checkIn(to: fight(status: .draft), code: "BERAWA", in: &s2, now: now), .notPublished)

var s3 = PersistedState()
if case .checkedIn(let pts) = FightRepository.checkIn(to: fight(tier: .major), code: "BERAWA", in: &s3, now: now) {
    eq("major tier pays 120", pts, 120)
} else { print("  FAIL major check-in"); fails += 1 }

// code presented => signup not required
var s4 = PersistedState()
yes("no signup needed with a code",
    { if case .checkedIn = FightRepository.checkIn(to: fight(), code: "BERAWA", in: &s4, now: now) { return true }; return false }())

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
