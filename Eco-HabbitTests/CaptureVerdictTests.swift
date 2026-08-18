import XCTest
@testable import Eco_Habbit

/// The rule deciding whether a photo logs itself or asks.
///
/// Worth testing hard: the failure mode is silent. A too-permissive rule logs
/// the wrong activity and celebrates, and the user has no reason to doubt it.
/// Asking when unsure costs one tap; auto-logging wrongly costs trust.
final class CaptureVerdictTests: XCTestCase {

    private let minimum: Float = 0.15
    private let autoLog: Float = 0.30
    private let margin: Float = 0.05
    private let distractorMargin: Float = 0.02

    /// `food_reusable_bottle` is `.direct`; `waste_compost` is `.contextual`.
    private func evidence(_ id: String) -> EvidenceStrength? {
        switch id {
        case "direct_a", "direct_b": .direct
        case "contextual_a": .contextual
        case "undetectable": .notDetectable
        default: nil
        }
    }

    /// Confidence defaults high so the older tests exercise the gates they were
    /// written for; the softmax gate has its own cases below.
    private func verdict(
        _ matches: [HabitMatch],
        distractor: DistractorMatch? = nil,
        confidence: Float = 1.0
    ) -> CaptureVerdict {
        HabitClassifier.verdict(
            for: RankedFrame(habits: matches, topDistractor: distractor, confidence: confidence),
            evidence: evidence,
            minSimilarity: minimum,
            autoLogSimilarity: autoLog,
            autoLogConfidence: 0.55,
            decisiveMargin: margin,
            distractorMargin: distractorMargin
        )
    }

    private func match(_ id: String, _ score: Float) -> HabitMatch {
        HabitMatch(habitId: id, similarity: score)
    }

    private func plastic(_ score: Float) -> DistractorMatch {
        DistractorMatch(id: "plastic_bottle", label: "a single-use plastic bottle", similarity: score)
    }

    // MARK: - The confident path

    func testHighScoringLoneDirectMatchAutoLogs() {
        XCTAssertEqual(verdict([match("direct_a", 0.42)]),
                       .confident(match("direct_a", 0.42)))
    }

    func testDirectMatchWellClearOfRunnerUpAutoLogs() {
        let matches = [match("direct_a", 0.40), match("contextual_a", 0.20)]
        XCTAssertEqual(verdict(matches), .confident(match("direct_a", 0.40)))
    }

    // MARK: - Everything else asks

    func testTornBetweenTwoAsksEvenWhenScoringHigh() {
        // 0.42 and 0.40 — high, but the model cannot tell them apart.
        let matches = [match("direct_a", 0.42), match("direct_b", 0.40)]
        XCTAssertEqual(verdict(matches), .unsure(matches),
                       "a narrow lead is not confidence")
    }

    func testExactlyAtTheMarginAsks() {
        // Margin is 0.05; a gap of exactly 0.05 passes, 0.049 does not.
        XCTAssertEqual(verdict([match("direct_a", 0.40), match("direct_b", 0.35)]),
                       .confident(match("direct_a", 0.40)))
        XCTAssertEqual(verdict([match("direct_a", 0.40), match("direct_b", 0.351)]).isUnsure,
                       true)
    }

    func testBelowTheAutoLogThresholdButOverTheFloorAsks() {
        let matches = [match("direct_a", 0.29)]
        XCTAssertEqual(verdict(matches), .unsure(matches))
    }

    /// Ranking is deliberately unfiltered so the tuning readout can show weak
    /// scores. The floor lives here instead — a top match under `minSimilarity`
    /// is "nothing", however many rows the model returned.
    func testBelowTheFloorIsNothingEvenThoughMatchesExist() {
        XCTAssertEqual(verdict([match("direct_a", 0.14), match("contextual_a", 0.11)]),
                       .nothing)
    }

    /// The important one. A photo of a compost bin does not prove anything was
    /// composted, however certain the model is that it is a compost bin.
    func testContextualNeverAutoLogsHoweverConfident() {
        let matches = [match("contextual_a", 0.95)]
        XCTAssertEqual(verdict(matches), .unsure(matches),
                       "contextual evidence must always be confirmed")
    }

    func testUnknownActivityNeverAutoLogs() {
        let matches = [match("not_in_catalogue", 0.95)]
        XCTAssertEqual(verdict(matches), .unsure(matches))
    }

    func testNoMatchesIsNothing() {
        XCTAssertEqual(verdict([]), .nothing)
    }

    // MARK: - Distractors
    //
    // The reason this whole mechanism exists. Ranking against habits alone is a
    // closed set: a plastic bottle has nowhere to land except "reusable bottle".

    /// The headline case. A plastic bottle scores *well* on "a metal water
    /// bottle" — they are both overwhelmingly a bottle — so the habit score
    /// alone can never separate them. Only the distractor can.
    func testAPlasticBottleIsRejectedRatherThanLogged() {
        let matches = [match("direct_a", 0.34)]
        XCTAssertEqual(verdict(matches, distractor: plastic(0.36)), .rejected(plastic(0.36)),
                       "a high-scoring habit must still lose to a higher-scoring distractor")
    }

    /// A tie goes to the distractor. If the model cannot separate a reusable
    /// bottle from a disposable one, refusing is the safe answer — logging is
    /// irreversible and celebrated.
    func testATieGoesToTheDistractor() {
        XCTAssertEqual(verdict([match("direct_a", 0.30)], distractor: plastic(0.30)),
                       .rejected(plastic(0.30)))
    }

    /// Rejection outranks the floor. Naming what it saw beats "nothing found"
    /// even when the habit was never plausible.
    func testRejectionIsCheckedBeforeTheFloor() {
        XCTAssertEqual(verdict([match("direct_a", 0.05)], distractor: plastic(0.40)),
                       .rejected(plastic(0.40)))
    }

    /// Beating the distractor is not enough — it has to be beaten *clearly*.
    /// Barely edging out "a plastic bottle" is exactly the frame that should ask
    /// rather than log.
    func testWinningTooNarrowlyOverADistractorAsksInsteadOfLogging() {
        let matches = [match("direct_a", 0.35)]
        // +0.01 lead, under the 0.02 distractor margin.
        XCTAssertEqual(verdict(matches, distractor: plastic(0.34)), .unsure(matches))
    }

    func testClearOfTheDistractorAutoLogs() {
        let matches = [match("direct_a", 0.40)]
        XCTAssertEqual(verdict(matches, distractor: plastic(0.20)), .confident(match("direct_a", 0.40)))
    }

    /// A vectors file generated before distractors existed must keep working —
    /// the gate cannot fail on evidence that isn't there.
    func testNoDistractorsBundledKeepsTheOldBehaviour() {
        let matches = [match("direct_a", 0.40)]
        XCTAssertEqual(verdict(matches, distractor: nil), .confident(match("direct_a", 0.40)))
    }

    // MARK: - Softmax confidence

    /// Both score gates apply. A frame where the winner took a decisive share of
    /// a field in which everything scored badly is still a bad frame.
    func testLowConfidenceAsksEvenWithAGoodCosine() {
        let matches = [match("direct_a", 0.40)]
        XCTAssertEqual(verdict(matches, distractor: plastic(0.20), confidence: 0.20),
                       .unsure(matches))
    }

    func testSoftmaxConcentratesOnAClearWinner() {
        // One clear leader against a flat field.
        let peaked = HabitClassifier.softmaxTop(of: [0.40, 0.20, 0.19, 0.18], scale: 100)
        XCTAssertGreaterThan(peaked, 0.9)

        // Four-way tie: the winner can only hold a quarter.
        let flat = HabitClassifier.softmaxTop(of: [0.30, 0.30, 0.30, 0.30], scale: 100)
        XCTAssertEqual(flat, 0.25, accuracy: 0.001)
    }

    /// `exp(100 * 0.35)` overflows `Float`. The max has to be subtracted first,
    /// or every confidence comes back NaN and every gate silently fails open.
    func testSoftmaxDoesNotOverflowAtRealisticScale() {
        let value = HabitClassifier.softmaxTop(of: [0.35, 0.34, 0.33], scale: 100)
        XCTAssertFalse(value.isNaN)
        XCTAssertTrue((0...1).contains(value))
    }

    // MARK: - Against the real catalogue

    /// Every vector we ship must resolve to a real activity, or the verdict
    /// silently degrades to "unsure" for a match that should have auto-logged.
    func testShippedVectorsAllResolveToKnownEvidenceStrengths() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "habit_vectors", withExtension: "json")
                ?? Bundle.main.url(forResource: "habit_vectors", withExtension: "json")
        )
        struct Payload: Decodable { struct E: Decodable { let id: String }; let habits: [E] }
        let ids = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url)).habits.map(\.id)

        for id in ids {
            XCTAssertNotNil(MockActivityData.activity(withID: id)?.evidenceStrength,
                            "\(id) has a vector but no catalogue entry")
        }
        XCTAssertTrue(
            ids.contains { MockActivityData.activity(withID: $0)?.evidenceStrength == .direct },
            "no shipped vector can ever auto-log — the confident path is unreachable"
        )
    }
}

private extension CaptureVerdict {
    var isUnsure: Bool { if case .unsure = self { true } else { false } }
}
