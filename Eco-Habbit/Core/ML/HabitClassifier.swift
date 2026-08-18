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

/// Zero-shot visual search over the habit catalogue (PRD §5).
///
/// **There is no trained classifier and no training photographs.** Each habit is
/// described in words, the MobileCLIP *text* tower turns those descriptions into
/// a vector offline, and this class embeds camera frames with the *image* tower
/// and ranks them by cosine similarity. Adding a habit costs five sentences.
///
/// It is a **search input, not a validator** (§5.1). Pointing at a single-use
/// plastic bottle will happily surface "Use a reusable water bottle" — CLIP has
/// no notion of negation, so both are simply "a bottle". That is the correct
/// result for a search box: it found the habit related to what you are looking
/// at. It never claims you performed it, which is exactly why 0.5 removed
/// verification.
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

    /// PRD §5.3 — at most three chips.
    var maxResults = 3

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
    /// Reused across frames. Vision requests are cheap but not free, and this one
    /// is only ever touched from the capture queue, serially.
    private let request: VNCoreMLRequest

    var habitIDs: [String] { vectors.map(\.id) }

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
    }

    /// Ranks the catalogue against one frame. Returns at most `maxResults`
    /// matches over `minSimilarity`, best first.
    ///
    /// Call this on a background queue **while the buffer is still valid** —
    /// AVFoundation recycles it the moment the delegate call returns.
    func search(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [HabitMatch] {
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

    private func rank(_ embedding: [Float]) -> [HabitMatch] {
        guard let first = vectors.first, first.vec.count == embedding.count else { return [] }

        return vectors
            .map { HabitMatch(habitId: $0.id, similarity: Self.dot($0.vec, embedding)) }
            .filter { $0.similarity >= minSimilarity }
            .sorted { $0.similarity > $1.similarity }
            .prefix(maxResults)
            .map { $0 }
    }

    /// Both sides are unit length, so the dot product *is* the cosine.
    private static func dot(_ a: [Float], _ b: [Float]) -> Float {
        var total: Float = 0
        for i in a.indices { total += a[i] * b[i] }
        return total
    }

    private struct VectorPayload: Decodable {
        struct Entry: Decodable { let id: String; let vec: [Float] }
        let model: String
        let dim: Int
        let habits: [Entry]
    }
}

/// One ranked result. Carries the catalogue id only — the habit itself is looked
/// up in `MockData`, so a name never lives in two places.
struct HabitMatch: Identifiable, Equatable {
    let habitId: String
    let similarity: Float

    var id: String { habitId }
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
