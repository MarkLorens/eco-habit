// Runnable check — run via ./tools/run-checks.sh
// Runnable check for the classifier verdict gates. main has no test target.
// verdict() is static and takes its thresholds + evidence lookup as parameters,
// so the whole decision layer tests without loading the 68 MB model.
var fails = 0
func check(_ l: String, _ got: CaptureVerdict, _ want: String) {
    let g: String
    switch got {
    case .nothing: g = "nothing"
    case .rejected(let d): g = "rejected(\(d.id))"
    case .confident(let m): g = "confident(\(m.habitId))"
    case .unsure(let m): g = "unsure(\(m.count))"
    }
    if g == want { print("  ok   \(l): \(g)") } else { print("  FAIL \(l): got \(g), want \(want)"); fails += 1 }
}
func frame(_ habits: [(String, Float)], distractor: (String, Float)? = nil, confidence: Float = 0.9) -> RankedFrame {
    RankedFrame(habits: habits.map { HabitMatch(habitId: $0.0, similarity: $0.1) },
                topDistractor: distractor.map { DistractorMatch(id: $0.0, label: $0.0, similarity: $0.1) },
                confidence: confidence)
}
// evidence lookup: "direct_*" is direct, "ctx_*" is contextual, "none_*" not detectable
func ev(_ id: String) -> EvidenceStrength? {
    id.hasPrefix("direct") ? .direct : id.hasPrefix("ctx") ? .contextual : .notDetectable
}
func v(_ f: RankedFrame) -> CaptureVerdict {
    HabitClassifier.verdict(for: f, evidence: ev, minSimilarity: 0.15,
                            autoLogSimilarity: 0.30, autoLogConfidence: 0.55,
                            decisiveMargin: 0.05, distractorMargin: 0.02)
}

check("empty frame", v(frame([])), "nothing")
check("below the floor", v(frame([("direct_a", 0.10)])), "nothing")

// THE FIX: a distractor beating the habits is rejected, checked BEFORE anything else
check("distractor wins -> rejected",
      v(frame([("direct_a", 0.40)], distractor: ("plastic_bottle", 0.45))), "rejected(plastic_bottle)")
check("distractor wins even with huge confidence",
      v(frame([("direct_a", 0.40)], distractor: ("tote", 0.50), confidence: 0.99)), "rejected(tote)")

// contextual evidence can never auto-submit, however certain
check("contextual never auto-logs",
      v(frame([("ctx_a", 0.90)], distractor: ("x", 0.10), confidence: 0.99)), "unsure(1)")

// direct + clear of runner-up + clear of distractor + confident -> confident
check("direct, decisive -> confident",
      v(frame([("direct_a", 0.50), ("direct_b", 0.20)], distractor: ("x", 0.10), confidence: 0.90)),
      "confident(direct_a)")

// direct but runner-up too close -> unsure
check("runner-up within margin -> unsure",
      v(frame([("direct_a", 0.50), ("direct_b", 0.48)], distractor: ("x", 0.10), confidence: 0.90)), "unsure(2)")

// direct but distractor too close -> unsure
check("distractor within margin -> unsure",
      v(frame([("direct_a", 0.50)], distractor: ("x", 0.49), confidence: 0.90)), "unsure(1)")

// direct, decisive, but low softmax confidence -> unsure
check("low confidence -> unsure",
      v(frame([("direct_a", 0.50), ("direct_b", 0.20)], distractor: ("x", 0.10), confidence: 0.20)), "unsure(2)")

// direct, above floor but below autoLog -> unsure
check("above floor, below auto-log -> unsure",
      v(frame([("direct_a", 0.25)], distractor: ("x", 0.05), confidence: 0.90)), "unsure(1)")

print(fails == 0 ? "\nALL PASS" : "\n\(fails) FAILED")
