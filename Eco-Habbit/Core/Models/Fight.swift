import Foundation

/// The scale of an event and what attending it pays.
///
/// Lives here because a Fight is the only kind of event in the app. It used to
/// be shared with a separate `Event` type that you claimed with a code; that
/// system was deleted and its one good idea — a tier table as the single source
/// of event points — moved here.
nonisolated enum EventTier: String, Codable, CaseIterable {
    case micro       // under an hour
    case standard    // half a day, organised
    case major       // full-day event

    var points: Int {
        switch self {
        case .micro:    return 40
        case .standard: return 75
        case .major:    return 120
        }
    }

    var displayName: String {
        switch self {
        case .micro:    return "Micro"
        case .standard: return "Standard"
        case .major:    return "Major"
        }
    }
}

/// A real-world, scheduled, location-based sustainability event.
///
/// Fights are the collective layer: habits are what you do alone, Fights are what
/// you do together, and the reward reflects that — a single afternoon is worth
/// more than a week of daily actions, capped monthly so it cannot replace them.
///
/// **Check-in direction:** the organiser publishes one `checkInCode` for the whole
/// Fight and the attendee scans or types it. The reverse — the host scanning each
/// attendee's personal QR — was how this worked before, and it needed a
/// cross-user write with no server to authorise it. One shared code means the
/// attendee's own device credits the attendee, which is a write it is already
/// allowed to make.
struct Fight: Identifiable, Codable, Hashable {
    let id: String
    /// `var` from here down because a host edits a published event in place
    /// (PRD §6.5.1) — editing is permitted, deletion is not.
    var title: String
    var summary: String
    /// Chosen by the partner in the admin app. Replaces the old `FightType`:
    /// the form asks for a Category, and using the same six the rest of the app
    /// uses means attendance can later count toward category badges.
    var category: Category
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

    /// Asset name for the partner's photo, `nil` while none is supplied.
    ///
    /// Deliberately optional rather than a name that might not resolve:
    /// `Image("missing")` draws nothing and reports no error, so a typo would
    /// look like a layout bug instead of a missing picture.
    var imageName: String?

    var status: Status = .published
    /// Exhibit seed data is labelled so it can never be mistaken for a real event (§8).
    var isDemo: Bool = false

    var tier: EventTier = .standard

    var attendancePoints: Int { tier.points }

    /// The one code for this Fight, shown by the organiser at the venue and
    /// entered — scanned or typed — by every attendee.
    ///
    /// Short and unambiguous on purpose: it has to survive being read off a
    /// screen across a table and typed by someone standing on a beach. The
    /// alphabet excludes `0/O` and `1/I`.
    var checkInCode: String = Fight.makeCheckInCode()

    /// A badge the organiser attaches as a reward, chosen from
    /// `MockBadgeData.fightRewards`. `nil` = points only.
    var rewardBadgeId: String?

    static func makeCheckInCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    /// Codes are compared case- and whitespace-insensitively — the attendee is
    /// typing this by hand, and rejecting "k7m 2qa" teaches them nothing.
    func matchesCheckInCode(_ entered: String) -> Bool {
        let normalise = { (s: String) in
            s.uppercased().filter { !$0.isWhitespace && $0 != "-" }
        }
        let candidate = normalise(entered)
        return !candidate.isEmpty && candidate == normalise(checkInCode)
    }

    enum Status: String, Codable {
        case draft, published, cancelled
    }

    /// The local day the event falls on — what attendance credits Vitality against.
    var localDate: String { Day.today(startsAt) }

    /// A Fight leaves the public list the moment it starts — the list is for
    /// things you can still decide to join. Check-in during the event happens
    /// from Saved or the scanner, not from browsing.
    var isUpcoming: Bool { startsAt > Date() }

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

/// Proof of attendance, written on the attendee's **own** device when they enter
/// the organiser's code.
///
/// In Firestore this becomes `/attendance/{fightId}_{uid}`, where the composite
/// ID gives one-check-in-per-attendee for free with no race. Locally the same
/// guarantee comes from `FightRepository` refusing a second write.
struct FightAttendance: Codable, Hashable, Identifiable {
    var id: String { fightId }
    let fightId: String
    let checkedInAt: Date
    /// The day the points were credited against — written at check-in, never re-derived.
    let localDate: String
    /// The badge awarded alongside the points, if the organiser set one.
    var awardedBadgeId: String?
}
