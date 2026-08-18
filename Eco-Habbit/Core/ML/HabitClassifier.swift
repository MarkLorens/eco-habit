import CoreML
import CoreImage
import Vision

// ============================================================================
// The image tower and the text vectors MUST be the same MobileCLIP variant.
//
// Here: MobileCLIP-S2 (v1), image tower `mobileclip_s2_image.mlpackage`, text
// vectors from `ml/generate_vectors.py` with MODEL_NAME = "MobileCLIP-S2".
//
// v1 vs v2, or S0 vs S2, produces scores in a completely normal-looking range
// that mean nothing at all. There is no error, no warning — just plausible
// nonsense. Do not swap one side without the other.
// ============================================================================

/// Zero-shot visual search over the habit catalogue.
///
/// **There is no trained classifier and no training photographs.** Each habit is
/// described in words, the MobileCLIP *text* tower turns those descriptions into
/// a vector offline, and this class embeds camera frames with the *image* tower
/// and ranks them by cosine similarity. Adding a habit costs five sentences.
///
/// ## Why distractors exist
///
/// Ranking against habits alone is a **closed set**: whatever you point at, the
/// nearest of N habits wins, because there is no option to return nothing. A
/// single-use plastic bottle is overwhelmingly "a bottle", so it lands on
/// *reusable water bottle* with a perfectly healthy score.
///
/// Neither obvious fix works. Raising the threshold fails because the plastic
/// bottle genuinely scores high — you would have to raise it past where real
/// reusable bottles land. Writing negation into the prompt ("a metal bottle, not
/// a plastic one") actively backfires: CLIP has no negation, and the words
/// "plastic bottle" drag the vector toward plastic bottles.
///
/// What works is giving the wrong answer somewhere correct to go. Distractor
/// vectors are encoded exactly like habits and ranked in the same pass; if one
/// of them wins, the frame is rejected and we can say *what* it looked like.
///
/// This was cut once, when the camera was a pure search box and a false
/// suggestion cost a glance. It is back because the camera now auto-logs points,
/// and a false *log* costs trust.
nonisolated final class HabitClassifier: @unchecked Sendable {

    private static let modelFileName = "mobileclip_s2_image"
    /// The output of Apple's pre-converted encoders (apple/coreml-mobileclip).
    /// Check the .mlpackage's Predictions tab in Xcode if this ever changes.
    private static let outputFeatureName = "final_emb_1"
    private static let vectorsFileName = "habit_vectors"

    /// Below this cosine we claim nothing.
    ///
    /// PRD §5.3 specifies 0.15, "low and permissive, deliberately" — a false
    /// suggestion costs a glance, a missing one costs the whole feature.
    ///
    /// TUNE ME ON PHOTOGRAPHS, not on `test_vectors.py`. Text-to-text cosines run
    /// 0.6–0.9; image-to-text cosines for the same pairing run far lower, because
    /// a real frame carries background, clutter and lighting the prompts never
    /// mention.
    var minSimilarity: Float = 0.15

    /// At most three candidates offered when the model isn't sure.
    var maxResults = 3

    /// Above this cosine, a `.direct` match may be logged without asking.
    ///
    /// TUNE ME ON PHOTOGRAPHS. Image-to-text cosines run far lower than the
    /// text-to-text numbers `ml/test_vectors.py` reports, so this cannot be set
    /// from that output. Too low and the camera logs the wrong thing silently,
    /// which is far worse than asking.
    var autoLogSimilarity: Float = 0.30

    /// …and it must also beat the runner-up habit by this much. A photo that
    /// scores 0.31 and 0.30 for two different activities is not confident, it is
    /// torn.
    var decisiveMargin: Float = 0.05

    /// …and it must beat the best **distractor** by this much.
    ///
    /// Separate from `decisiveMargin` and deliberately larger. Two habits being
    /// close is ambiguity — asking resolves it. A habit being close to "a
    /// single-use plastic bottle" is the failure this whole mechanism exists to
    /// catch, and there the safe answer is to refuse rather than to ask, because
    /// a plausible-looking question invites a wrong yes.
    var distractorMargin: Float = 0.02

    /// Minimum softmax probability for the top habit across the whole field.
    ///
    /// More stable than the raw cosine: cosines drift with lighting and clutter,
    /// but the *share* the winner takes of the field holds up. Both gates apply
    /// — this one and `autoLogSimilarity` — because a confident share of a field
    /// where everything scored badly is still a bad frame.
    var autoLogConfidence: Float = 0.55

    /// **Load once per process.** Constructing this reads and prepares a 68 MB
    /// Core ML model — on device that is seconds, not milliseconds, and the
    /// Neural Engine specialisation on a cold install is slower still.
    ///
    /// `static let` gives lazy, thread-safe, exactly-once initialisation for
    /// free. The `Result` keeps the failure reason instead of flattening it to
    /// nil, so the view can still say *why* the camera has no chips.
    static let shared: Result<HabitClassifier, Error> = Result { try HabitClassifier() }

    private let visionModel: VNCoreMLModel
    private let vectors: [(id: String, vec: [Float])]

    /// Things that are **not** habits, encoded the same way. Empty is legal —
    /// the app then behaves exactly as it did before distractors existed, which
    /// is what keeps an older `habit_vectors.json` working.
    private let distractors: [(id: String, label: String, vec: [Float])]

    /// CLIP's learned temperature, exported by the generator. Cosines are
    /// compressed into a narrow band; multiplying by this before softmax is what
    /// turns them into probabilities that mean something.
    private let logitScale: Float

    /// Reused across frames. Vision requests are cheap but not free, and this one
    /// is only ever touched from the capture queue, serially.
    private let request: VNCoreMLRequest

    var habitIDs: [String] { vectors.map(\.id) }
    var distractorCount: Int { distractors.count }

    /// Compiling the model is slow. Build this off the main actor — or better,
    /// don't build it at all and use `shared`.
    private init() throws {
        guard let modelURL =
                Bundle.main.url(forResource: Self.modelFileName, withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: Self.modelFileName, withExtension: "mlpackage")
        else { throw ClassifierError.modelMissing(Self.modelFileName) }

        let config = MLModelConfiguration()
        config.computeUnits = .all
        visionModel = try VNCoreMLModel(for: try MLModel(contentsOf: modelURL, configuration: config))

        request = VNCoreMLRequest(model: visionModel)
        // MobileCLIP was trained on centre-cropped squares. `scaleFill` would
        // squash a 4:3 frame and shift every embedding.
        request.imageCropAndScaleOption = .centerCrop

        guard let vectorsURL = Bundle.main.url(forResource: Self.vectorsFileName, withExtension: "json")
        else { throw ClassifierError.vectorsMissing(Self.vectorsFileName) }

        let payload = try JSONDecoder().decode(VectorPayload.self, from: Data(contentsOf: vectorsURL))
        guard !payload.habits.isEmpty else { throw ClassifierError.emptyVectors }
        vectors = payload.habits.map { ($0.id, $0.vec) }
        distractors = (payload.distractors ?? []).map { ($0.id, $0.label, $0.vec) }
        logitScale = payload.logitScale ?? 100
    }

    /// Scores one frame against the habits *and* the distractors.
    ///
    /// Call this on a background queue **while the buffer is still valid** —
    /// AVFoundation recycles it the moment the delegate call returns.
    func search(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> RankedFrame {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return rank(try embed(handler))
    }

    // MARK: - Internals

    private func embed(_ handler: VNImageRequestHandler) throws -> [Float] {
        #if DEBUG
        let startedAt = CFAbsoluteTimeGetCurrent()
        defer {
            let ms = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
            // Sampled, not every frame — logging 3x a second is its own slowdown.
            if Int.random(in: 0..<10) == 0 {
                print(String(format: "[HabitClassifier] inference %.1f ms", ms))
            }
        }
        #endif

        try handler.perform([request])

        guard let observation = (request.results as? [VNCoreMLFeatureValueObservation])?
            .first(where: { $0.featureName == Self.outputFeatureName })
            ?? request.results?.first as? VNCoreMLFeatureValueObservation,
              let raw = observation.featureValue.multiArrayValue
        else { throw ClassifierError.noEmbedding(Self.outputFeatureName) }

        var embedding = [Float](repeating: 0, count: raw.count)
        for i in 0..<raw.count { embedding[i] = raw[i].floatValue }

        // The image tower does not normalise its output; the text vectors are
        // unit length. Normalising here is what makes the dot product a cosine.
        var magnitude: Float = 0
        for value in embedding { magnitude += value * value }
        magnitude = sqrtf(magnitude)
        guard magnitude > 1e-6 else { throw ClassifierError.zeroEmbedding }
        for i in embedding.indices { embedding[i] /= magnitude }

        return embedding
    }

    /// Scores everything, then reports the top habits, the strongest distractor,
    /// and how much of the field the winner actually took.
    ///
    /// Deliberately unfiltered: `minSimilarity` is applied by `verdict`, not
    /// here, so the caller can always see what the model actually scored. A
    /// ranking that silently returns [] is impossible to tune against.
    func rank(_ embedding: [Float]) -> RankedFrame {
        guard let first = vectors.first, first.vec.count == embedding.count else {
            return RankedFrame(habits: [], topDistractor: nil, confidence: 0)
        }

        let habitScores = vectors
            .map { HabitMatch(habitId: $0.id, similarity: Self.dot($0.vec, embedding)) }
            .sorted { $0.similarity > $1.similarity }

        let distractorScores = distractors
            .map { DistractorMatch(id: $0.id, label: $0.label, similarity: Self.dot($0.vec, embedding)) }
            .sorted { $0.similarity > $1.similarity }

        // Softmax over the WHOLE field — habits and distractors together. Over
        // habits alone the winner's share is meaningless, because the shares are
        // forced to sum to 1 among options that might all be wrong.
        let all = habitScores.map(\.similarity) + distractorScores.map(\.similarity)
        let confidence = Self.softmaxTop(of: all, scale: logitScale)

        return RankedFrame(
            habits: Array(habitScores.prefix(maxResults)),
            topDistractor: distractorScores.first,
            confidence: habitScores.first?.similarity == all.max() ? confidence : 0
        )
    }

    /// Probability mass on the single highest logit. Shifted by the max before
    /// exponentiating — `exp(100 * 0.35)` overflows `Float` otherwise.
    static func softmaxTop(of similarities: [Float], scale: Float) -> Float {
        guard let peak = similarities.max() else { return 0 }
        var total: Float = 0
        for s in similarities { total += expf(scale * (s - peak)) }
        return total > 0 ? 1 / total : 0
    }

    /// Both sides are unit length, so the dot product *is* the cosine.
    private static func dot(_ a: [Float], _ b: [Float]) -> Float {
        var total: Float = 0
        for i in a.indices { total += a[i] * b[i] }
        return total
    }

    private struct VectorPayload: Decodable {
        struct Entry: Decodable { let id: String; let vec: [Float] }
        struct Distractor: Decodable { let id: String; let label: String; let vec: [Float] }
        let model: String
        let dim: Int
        /// Both optional so a vectors file generated before distractors existed
        /// still loads, and the app falls back to its old behaviour.
        let logitScale: Float?
        let habits: [Entry]
        let distractors: [Distractor]?
    }
}

/// One ranked habit. Carries the catalogue id only — the activity itself is
/// looked up in `MockData`, so a name never lives in two places.
struct HabitMatch: Identifiable, Equatable {
    let habitId: String
    let similarity: Float

    var id: String { habitId }
}

/// One ranked *non*-habit. Unlike a habit it carries its own label, because
/// there is no catalogue to look "a single-use plastic bottle" up in — and the
/// label is the whole value: it lets the camera say what it thinks it saw.
struct DistractorMatch: Identifiable, Equatable {
    let id: String
    let label: String
    let similarity: Float
}

/// Everything one frame scored.
struct RankedFrame: Equatable {
    /// Best-first, capped at `maxResults`. Unfiltered.
    let habits: [HabitMatch]
    /// The strongest non-habit. `nil` when no distractors are bundled.
    let topDistractor: DistractorMatch?
    /// Softmax share the top habit took of the whole field, or 0 if a distractor
    /// won outright.
    let confidence: Float

    static let empty = RankedFrame(habits: [], topDistractor: nil, confidence: 0)
}

/// What a single shutter press amounted to.
enum CaptureVerdict: Equatable {
    /// Nothing cleared `minSimilarity`.
    case nothing
    /// A distractor beat every habit — we can name what it looked like instead.
    case rejected(DistractorMatch)
    /// Log it and celebrate — no question asked.
    case confident(HabitMatch)
    /// Plausible candidates; the user picks.
    case unsure([HabitMatch])
}

extension HabitClassifier {

    /// Decides what a frame amounted to.
    ///
    /// The gates run in this order, and the order is the design:
    ///
    /// 1. **Did a distractor win?** Checked first, before anything else, because
    ///    "this is a plastic bottle" outranks every question we could ask about
    ///    which habit it might be. This is the gate that fixes the closed-set
    ///    problem; the rest only refine a frame that already passed it.
    /// 2. **The floor.** Below `minSimilarity` we claim nothing.
    /// 3. **The activity.** Only `.direct` evidence may auto-submit. A photo of
    ///    a tap does not prove the tap was turned off, however certain the model
    ///    is that it is a tap. `.contextual` always asks.
    /// 4. **Three confidence gates**, all required: absolute score, a clear gap
    ///    to the runner-up habit, and a clear gap to the best distractor.
    ///
    /// Pure and injectable so it can be tested without the model.
    static func verdict(
        for frame: RankedFrame,
        evidence: (String) -> EvidenceStrength?,
        minSimilarity: Float,
        autoLogSimilarity: Float,
        autoLogConfidence: Float,
        decisiveMargin: Float,
        distractorMargin: Float
    ) -> CaptureVerdict {
        guard let top = frame.habits.first else { return .nothing }

        // 1. A non-habit scored higher than every habit. Say so — "that looks
        //    like a single-use bottle" is far more useful than "nothing found",
        //    and it is the honest answer rather than a forced pick.
        if let distractor = frame.topDistractor, distractor.similarity >= top.similarity {
            return .rejected(distractor)
        }

        guard top.similarity >= minSimilarity else { return .nothing }

        let clearOfRunnerUp = frame.habits.count == 1
            || (top.similarity - frame.habits[1].similarity) >= decisiveMargin

        // No distractors bundled means no evidence either way, so this gate
        // cannot fail — an older vectors file keeps the previous behaviour.
        let clearOfDistractors = frame.topDistractor
            .map { top.similarity - $0.similarity >= distractorMargin } ?? true

        let canAutoSubmit = evidence(top.habitId)?.canAutoSubmitPoints ?? false

        if canAutoSubmit,
           top.similarity >= autoLogSimilarity,
           frame.confidence >= autoLogConfidence,
           clearOfRunnerUp,
           clearOfDistractors {
            return .confident(top)
        }
        return .unsure(frame.habits)
    }

    /// Convenience over the app's catalogue.
    func verdict(for frame: RankedFrame) -> CaptureVerdict {
        Self.verdict(
            for: frame,
            evidence: { MockData.habitsById[$0]?.evidenceStrength },
            minSimilarity: minSimilarity,
            autoLogSimilarity: autoLogSimilarity,
            autoLogConfidence: autoLogConfidence,
            decisiveMargin: decisiveMargin,
            distractorMargin: distractorMargin
        )
    }
}

enum ClassifierError: Error, LocalizedError {
    case modelMissing(String)
    case vectorsMissing(String)
    case emptyVectors
    case noEmbedding(String)
    case zeroEmbedding

    var errorDescription: String? {
        switch self {
        case .modelMissing(let name):
            return "\(name).mlpackage is not in the bundle. It belongs in Resources/."
        case .vectorsMissing(let name):
            return "\(name).json is not in the bundle. Run ml/generate_vectors.py."
        case .emptyVectors:
            return "habit_vectors.json decoded to zero habits."
        case .noEmbedding(let expected):
            return "Model produced no output named '\(expected)'."
        case .zeroEmbedding:
            return "Model returned an all-zero embedding."
        }
    }
}
