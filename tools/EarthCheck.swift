// Runnable check — run via ./tools/run-checks.sh
// Runnable check for the Earth stage model. main has no test target.
let c = PointsConfiguration.default
var fails = 0
func eq(_ l: String, _ g: Int, _ w: Int) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }
func eqS(_ l: String, _ g: EarthStage, _ w: EarthStage) { if g==w { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g) want \(w)"); fails+=1 } }

print("thresholds:", EarthStage.allCases.map { c.threshold(for: $0) })
eqS("0 pts",     c.stage(forPoints: 0),    .critical)
eqS("149 pts",   c.stage(forPoints: 149),  .critical)
eqS("150 pts",   c.stage(forPoints: 150),  .fragile)
eqS("949 pts",   c.stage(forPoints: 949),  .stabilizing)
eqS("950 pts",   c.stage(forPoints: 950),  .recovering)
eqS("2500 pts",  c.stage(forPoints: 2500), .restored)
eqS("9999 pts",  c.stage(forPoints: 9999), .restored)

// vitality derivation must reach exactly 100 at Restored, and never exceed it
func vitality(_ p: Int) -> Int {
    let r = c.threshold(for: .restored); return r > 0 ? min(100, p * 100 / r) : 0
}
eq("vitality at 0",    vitality(0), 0)
eq("vitality at 1250", vitality(1250), 50)
eq("vitality at 2500", vitality(2500), 100)
eq("vitality at 9999", vitality(9999), 100)
eq("stages count", EarthStage.allCases.count, 6)
print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
