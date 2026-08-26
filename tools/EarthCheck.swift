// Runnable check — run via ./tools/run-checks.sh
// Runnable check for the Earth stage model. main has no test target.
let c = PointsConfiguration.default
var fails = 0
func eq(_ l: String, _ g: Int, _ w: Int) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }
func eqS(_ l: String, _ g: EarthStage, _ w: EarthStage) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }

print("thresholds:", EarthStage.allCases.map { c.threshold(for: $0) })

// Driven by the CONFIG, not by literals. These used to assert "150 pts -> fragile",
// which meant retuning a balance number failed a test that was not protecting
// anything: the mapping was still correct, the numbers had simply moved. What must
// hold is the RELATIONSHIP — every threshold enters its stage, one point below it
// does not, and the ladder is monotonic.
eqS("0 pts is always critical", c.stage(forPoints: 0), .critical)

for stage in EarthStage.allCases {
    let at = c.threshold(for: stage)
    eqS("\(at) pts enters \(stage)", c.stage(forPoints: at), stage)

    // One below a threshold must be the stage beneath it. Skipped where two
    // thresholds are equal or adjacent, which leaves no gap to test.
    if stage.rawValue > 0 {
        let below = EarthStage(rawValue: stage.rawValue - 1)!
        if at - 1 >= c.threshold(for: below) {
            eqS("\(at - 1) pts is still \(below)", c.stage(forPoints: at - 1), below)
        }
    }
}

let top = c.threshold(for: .restored)
eqS("far past the top stays restored", c.stage(forPoints: top * 4 + 1), .restored)

// Monotonic, or `stage(forPoints:)` — which walks the cases in reverse — would
// return a stage somebody could never climb out of.
var ascending = true
for stage in EarthStage.allCases.dropFirst() where
    c.threshold(for: stage) <= c.threshold(for: EarthStage(rawValue: stage.rawValue - 1)!) {
    ascending = false
}
if ascending { print("  ok   thresholds ascend") } else { print("  FAIL thresholds do not ascend"); fails += 1 }

// vitality derivation must reach exactly 100 at Restored, and never exceed it
func vitality(_ p: Int) -> Int {
    let r = c.threshold(for: .restored); return r > 0 ? min(100, p * 100 / r) : 0
}
eq("vitality at 0", vitality(0), 0)
eq("vitality at half of Restored", vitality(top / 2), 50)
eq("vitality at Restored", vitality(top), 100)
eq("vitality past Restored is capped", vitality(top * 4), 100)
eq("stages count", EarthStage.allCases.count, 6)
print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
