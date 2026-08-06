import Foundation

/// A catalog entry. The catalog itself never mutates — per-day completion lives in
/// `AppState.completions`, so the same activity can be looked up from the checklist,
/// the camera and the suggestion cards without three copies of the truth.
nonisolated struct Activity: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: ActivityCategory
    let basePoints: Int
    /// Whether the (mocked) on-device detector is able to recognise this action.
    let isCameraDetectable: Bool
    let effort: Effort

    enum Effort: String, Codable {
        case light   // 5–10 pts
        case medium  // 10–20 pts
    }
}

/// How an activity was completed on a given day.
nonisolated struct Completion: Codable, Hashable, Identifiable {
    enum Source: String, Codable {
        case checklist
        case camera
    }

    var id = UUID()
    let activityId: String
    /// Start-of-day, so "once per day" is a plain date comparison.
    let day: Date
    let source: Source
    var evidencePhotoId: UUID?
    /// Points actually credited, after evidence bonus and streak multiplier.
    var pointsAwarded: Int

    var hasEvidence: Bool { evidencePhotoId != nil }
}

/// The row model the activity list renders — catalog entry joined with today's state.
nonisolated struct ActivityRow: Identifiable, Hashable {
    let activity: Activity
    let completion: Completion?

    var id: String { activity.id }
    var isCompletedToday: Bool { completion != nil }
    var hasEvidence: Bool { completion?.hasEvidence ?? false }
}

/// A photo the user attached as evidence. Bytes live on disk; this is the index entry.
nonisolated struct EvidencePhoto: Identifiable, Codable, Hashable {
    let id: UUID
    let activityId: String
    let categoryRaw: String
    let capturedAt: Date

    var category: ActivityCategory? { ActivityCategory(rawValue: categoryRaw) }
    var fileName: String { "\(id.uuidString).jpg" }
}

/// A time-boxed mission attached to a place. Mock data for now.
nonisolated struct RegionalMission: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case daily   // 15–25 pts
        case event   // 50–100 pts
    }

    let id: String
    let title: String
    let region: String
    let locationName: String
    let date: Date
    let points: Int
    let kind: Kind
    let category: ActivityCategory
}

nonisolated struct Voucher: Identifiable, Codable, Hashable {
    let id: String
    let partner: String
    let title: String
    let points: Int
    let terms: [String]
    let howToUse: [String]
}

nonisolated struct RedeemedVoucher: Identifiable, Codable, Hashable {
    let id: UUID
    let voucherId: String
    let redeemedAt: Date
    let code: String
}

nonisolated struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tier: String
    let detail: String
    /// Evaluated against `AppState` to decide locked / unlocked.
    let requirement: Requirement

    enum Requirement: Codable, Hashable {
        case totalActions(Int)
        case streak(Int)
        case earthPoints(Int)
        case categoryActions(ActivityCategory, Int)
        case evidenceCount(Int)
        /// Never unlocks from local mock data — the "rare" tier.
        case seasonal
    }
}

/// A single line in the activity history.
nonisolated struct HistoryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let categoryRaw: String
    let points: Int
    let date: Date
    let sourceRaw: String
    /// Links back to the `Completion` so a reverted log takes its history line with it.
    var completionId: UUID?

    var category: ActivityCategory? { ActivityCategory(rawValue: categoryRaw) }
    var source: Completion.Source? { Completion.Source(rawValue: sourceRaw) }
}
