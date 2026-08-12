import Foundation

/// PRD §4 — a real-world, scheduled, location-based sustainability event.
///
/// Fights are the collective layer: habits are what you do alone, Fights are what you do
/// together, and the reward reflects that — **+10 Vitality**, more than three consecutive
/// perfect days of habits, delivered in a single afternoon.
struct Fight: Identifiable, Codable, Hashable {
    let id: String
    /// `var` from here down because a host edits a published event in place
    /// (PRD §6.5.1) — editing is permitted, deletion is not.
    var title: String
    var summary: String
    var type: FightType
    let hostName: String
    let hostId: String
    var locationName: String
    var address: String
    /// Captured from day one purely to enable the v2 map view (PRD §9.12); nothing reads
    /// them in v1.
    var latitude: Double?
    var longitude: Double?
    var startsAt: Date
    var endsAt: Date
    var preparationNotes: [String] = []
    var status: Status = .published
    /// Exhibit seed data is labelled so it can never be mistaken for a real event (§8).
    var isDemo: Bool = false

    /// Attending pays out on the same scale as claiming an `Event`, and against
    /// the same monthly cap. A Fight is hosted and scanned where an Event is
    /// merely claimed, but there is no reason for the two to use different
    /// economies — the numbers all live in `PointsConfiguration`.
    var tier: EventTier = .standard

    var attendancePoints: Int { tier.points }

    enum Status: String, Codable {
        case draft, published, cancelled
    }

    /// The local day the event falls on — what attendance credits Vitality against.
    var localDate: String { Day.today(startsAt) }

    var isUpcoming: Bool { endsAt > Date() }

    /// PRD §4.5 — opens 1 hour before start, closes 3 hours after end.
    static let checkInOpensBefore: TimeInterval = 60 * 60
    static let checkInClosesAfter: TimeInterval = 3 * 60 * 60

    var checkInWindow: ClosedRange<Date> {
        let opens = startsAt.addingTimeInterval(-Self.checkInOpensBefore)
        let closes = endsAt.addingTimeInterval(Self.checkInClosesAfter)
        return opens...closes
    }

    func isCheckInOpen(at moment: Date = Date()) -> Bool {
        status == .published && checkInWindow.contains(moment)
    }
}

/// PRD §4.2 — Fights have their own taxonomy, deliberately not mapped onto habit
/// categories. A mangrove planting isn't "Water" or "Food", and forcing the mapping
/// would distort both lists.
enum FightType: String, Codable, CaseIterable, Identifiable, Hashable {
    case beachCleanup
    case riverCleanup
    case mangrovePlanting
    case treePlanting
    case reefRestoration
    case wasteDrive
    case workshop
    case wildlifeProtection

    var id: String { rawValue }

    var name: String {
        switch self {
        case .beachCleanup: return "Beach Cleanup"
        case .riverCleanup: return "River Cleanup"
        case .mangrovePlanting: return "Mangrove Planting"
        case .treePlanting: return "Tree Planting"
        case .reefRestoration: return "Reef Restoration"
        case .wasteDrive: return "Waste Drive"
        case .workshop: return "Workshop"
        case .wildlifeProtection: return "Wildlife Protection"
        }
    }

    var shortName: String {
        switch self {
        case .beachCleanup: return "Beach"
        case .riverCleanup: return "River"
        case .mangrovePlanting: return "Mangrove"
        case .treePlanting: return "Trees"
        case .reefRestoration: return "Reef"
        case .wasteDrive: return "Waste"
        case .workshop: return "Workshop"
        case .wildlifeProtection: return "Wildlife"
        }
    }

    var symbol: String {
        switch self {
        case .beachCleanup: return "beach.umbrella"
        case .riverCleanup: return "water.waves"
        case .mangrovePlanting: return "tree"
        case .treePlanting: return "leaf"
        case .reefRestoration: return "fish"
        case .wasteDrive: return "arrow.3.trianglepath"
        case .workshop: return "hammer"
        case .wildlifeProtection: return "pawprint"
        }
    }
}

/// A user's signup for one Fight. PRD §4.5: the check-in token is generated at signup
/// and lives on the attendee's phone.
struct FightSignup: Codable, Hashable, Identifiable {
    var id: String { fightId }
    let fightId: String
    let signedUpAt: Date
    /// Rendered as the QR the host scans. Scoped to `(user, event)`.
    let checkInToken: String
    var cancelledAt: Date?

    var isActive: Bool { cancelledAt == nil }
}

/// Proof of attendance. In Phase 10 this becomes `/attendance/{eventId}_{userId}` and the
/// composite ID gives uniqueness for free (PRD §9.3); locally the same guarantee comes
/// from `FightRepository` refusing a second write.
struct FightAttendance: Codable, Hashable, Identifiable {
    var id: String { fightId }
    let fightId: String
    let checkedInAt: Date
    /// The day Vitality is credited against — written at check-in, never re-derived.
    let localDate: String
}

/// One scan on the **host's** device (PRD §6.5.1).
///
/// Distinct from `FightAttendance`, which is the attendee's own record. Until
/// Phase 10 these cannot be the same thing: awarding Vitality to another user is
/// a cross-user write, and there is no server to authorise it. The host records
/// who they scanned; the attendee's device credits itself.
struct HostScan: Codable, Hashable, Identifiable {
    var id: String { token }
    let fightId: String
    let token: String
    /// What the host sees in the roster. Parsed out of the token.
    let attendeeLabel: String
    let scannedAt: Date
}
