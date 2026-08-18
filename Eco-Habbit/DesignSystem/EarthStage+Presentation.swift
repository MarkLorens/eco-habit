import Foundation

/// Copy for the Earth stage sheet.
///
/// `VitalityStage` on `main` carried a `name`, a `blurb` and a 0–100 `range`.
/// `EarthStage` already has `displayName`; the sentence lives here rather than on
/// the model, which imports Foundation only and knows nothing about being read.
///
/// Six stages here against his five — the sheet lists whatever `allCases`
/// contains, so it gains a row rather than needing a different layout.
/// `VitalityStage` was `Identifiable`; `EarthStage` is not, and the sheet's
/// `ForEach` needs it. Declared here rather than on the model so the model keeps
/// knowing nothing about being displayed.
extension EarthStage: @retroactive Identifiable {
    public var id: Int { rawValue }
}

extension EarthStage {

    var blurb: String {
        switch self {
        case .critical:    return "Bare ground and still air. Everything starts here."
        case .fragile:     return "The first green returns, and it is easily lost."
        case .stabilizing: return "Roots hold. The damage has stopped spreading."
        case .recovering:  return "Growth outpaces loss for the first time."
        case .flourishing: return "Dense, noisy, alive — the habit is doing the work."
        case .restored:    return "Whole again. Keep going and it stays that way."
        }
    }
}
