import Foundation

/// The scale of an event and what attending it pays.
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

/// PRD §4 — a real-world, scheduled, location-based sustainability event.
///
/// Fights are the collective layer: habits are what you do alone, Fights are what you
/// do together, and the reward reflects that — a single afternoon is worth more than a
/// week of daily actions, capped monthly so it cannot replace them.
///
/// **Check-in direction:** the organiser publishes one `checkInCode` for the whole
/// Fight and the attendee scans or types it. The reverse — the host scanning each
/// attendee's personal QR — needs a cross-user write with no server to authorise it.
/// One shared code means the attendee's own device credits the attendee, which is a
/// write it is already allowed to make.
nonisolated struct Fight: Identifiable, Codable, Hashable {
    let id: String
    /// `var` from here down because a host edits a published event in place
    /// (PRD §6.5.1) — editing is permitted, deletion is not.
    var title: String
    var summary: String
    /// One taxonomy with the habits, per the hi-fi: the pill on a card, the spine
    /// colour and the form picker are all this. The old `FightType` (beach cleanup,
    /// mangrove planting…) was a second vocabulary nothing on screen ever showed.
    var category: HabitCategory
    /// Display only, and **not** a snapshot — unlike `EarnedBadge.name`, which freezes
    /// because the catalogue entry behind it can vanish. `hostId` is what actually owns
    /// this Fight; the name is what people read, so an organiser renaming itself should
    /// see the change on events it already published rather than a name it no longer
    /// goes by. `AppState.setOrganisationName` rewrites and re-pushes them.
    var hostName: String
    let hostId: String
    var locationName: String
    var address: String
    /// Captured from day one purely to enable the v2 map view (PRD §9.12); nothing reads
    /// them in v1.
    var latitude: Double?
    var longitude: Double?
    var startsAt: Date
    var endsAt: Date
    /// Where to find out more — Instagram, WhatsApp, a signup form, anything.
    ///
    /// Free text rather than a `URL`: an organiser types this on a phone and will leave
    /// off the scheme. `infoURL` below repairs that at the point of use, so a bad value
    /// costs a hidden button rather than a crash.
    var link: String?

    /// The organiser's photo, base64 JPEG, carried **inside this document**.
    ///
    /// Images normally belong in Cloud Storage, and at any scale they still do. At this
    /// one they do not: a thumbnail is ~30 KB, a Firestore document may be 1 MiB, and
    /// putting it here means the photo syncs by the same mechanism as the title — no
    /// second service, no billing plan, no upload that can half-succeed, and it works
    /// offline through Firestore's own cache.
    ///
    /// `FightImage.encode` enforces the size; nothing should ever set this directly.
    /// A `String` rather than `Data` so `Fight` stays Foundation-only — `tools/` compiles
    /// this file without UIKit.
    var imageData: String?

    var preparationNotes: [String] = []
    var status: Status = .published
    /// Exhibit seed data is labelled so it can never be mistaken for a real event (§8).
    var isDemo: Bool = false

    /// How big the event is, and therefore what attending pays.
    var tier: EventTier = .standard
    var attendancePoints: Int { tier.points }

    /// The one code for this Fight, shown by the organiser at the venue and
    /// entered — scanned or typed — by every attendee.
    ///
    /// Short and unambiguous on purpose: it has to survive being read off a
    /// screen across a table and typed by somebody standing on a beach. The
    /// alphabet excludes `0/O` and `1/I`.
    var checkInCode: String = Fight.makeCheckInCode()

    /// A badge the organiser attaches as a reward. `nil` = points only.
    var rewardBadgeId: String?

    enum Status: String, Codable {
        case draft, published, cancelled
    }

    // MARK: - Check-in code

    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// Six characters from a 32-symbol alphabet — 32⁶, about 1.07 billion.
    ///
    /// Pass a `seed` to derive the code deterministically from it. That matters
    /// for a Fight saved before codes existed: without a seed it would be handed
    /// a fresh random code on **every launch**, so the organiser's QR would
    /// change every time they opened the app.
    static func makeCheckInCode(seed: String? = nil) -> String {
        guard let seed else {
            return String((0..<6).map { _ in codeAlphabet.randomElement()! })
        }
        var h: UInt64 = 5381
        for byte in seed.utf8 { h = h &* 33 &+ UInt64(byte) }
        return String((0..<6).map { _ -> Character in
            defer { h = h &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407 }
            return codeAlphabet[Int(h % UInt64(codeAlphabet.count))]
        })
    }

    static let payloadPrefix = "ecohabit://fight/"

    /// What the organiser's QR encodes: `ecohabit://fight/BERAWA`.
    ///
    /// **The scheme is the safety mechanism, not decoration.** The camera that
    /// reads this is also the habit scanner, so it is pointed at arbitrary scenes
    /// all day — posters, menus, wifi codes. Encoding the bare code would force
    /// it to try every QR in the world against the fight list, and a
    /// six-character collision would silently check somebody into an event they
    /// are nowhere near.
    var checkInPayload: String { "\(Fight.payloadPrefix)\(checkInCode)" }

    /// The code inside a scanned payload, or `nil` for anything else.
    ///
    /// Permissive about *case* and nothing else: a QR this app generates is
    /// exact, but a scanner or a copy-paste can change case.
    static func code(fromPayload raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix(payloadPrefix) else { return nil }
        let code = String(trimmed.dropFirst(payloadPrefix.count))
        return code.isEmpty ? nil : code
    }

    /// Compared case- and whitespace-insensitively — the attendee is typing this
    /// by hand, and rejecting "k7m 2qa" teaches them nothing.
    func matchesCheckInCode(_ entered: String) -> Bool {
        let normalise = { (s: String) in s.uppercased().filter { !$0.isWhitespace && $0 != "-" } }
        let candidate = normalise(entered)
        return !candidate.isEmpty && candidate == normalise(checkInCode)
    }

    /// The local day the event falls on — what attendance credits Vitality against.
    var localDate: String { Day.today(startsAt) }

    /// The link as something openable, or `nil`.
    ///
    /// Adds `https://` when the organiser omitted it — which they will — and refuses
    /// anything without a host, so a stray word never becomes a button that opens
    /// nothing.
    var infoURL: URL? {
        let trimmed = (link ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate), url.host?.isEmpty == false else { return nil }
        return url
    }

    var isUpcoming: Bool { endsAt > Date() }

    /// PRD §4.5 — opens 1 hour before start, closes 3 hours after end.
    static let checkInOpensBefore: TimeInterval = 60 * 60
    static let checkInClosesAfter: TimeInterval = 3 * 60 * 60

    var checkInWindow: ClosedRange<Date> {
        let opens = startsAt.addingTimeInterval(-Self.checkInOpensBefore)
        let closes = endsAt.addingTimeInterval(Self.checkInClosesAfter)
        return opens...closes
    }

    /// Explicit because writing `init(from:)` below suppresses the synthesized
    /// memberwise one, and `FightSeed.materialise()` builds Fights in code.
    init(id: String,
         title: String,
         summary: String = "",
         category: HabitCategory,
         hostName: String = "",
         hostId: String = "",
         locationName: String = "",
         address: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         startsAt: Date,
         endsAt: Date,
         preparationNotes: [String] = [],
         link: String? = nil,
         imageData: String? = nil,
         status: Status = .published,
         isDemo: Bool = false,
         tier: EventTier = .standard,
         checkInCode: String? = nil,
         rewardBadgeId: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.category = category
        self.hostName = hostName
        self.hostId = hostId
        self.locationName = locationName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.preparationNotes = preparationNotes
        self.link = link
        self.imageData = imageData
        self.status = status
        self.isDemo = isDemo
        self.tier = tier
        // Seeded from the id when not supplied, so the demo Fights get a stable
        // code rather than a new one on every launch.
        self.checkInCode = checkInCode ?? Fight.makeCheckInCode(seed: id)
        self.rewardBadgeId = rewardBadgeId
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case id, title, summary, category, hostName, hostId, locationName, address
        case latitude, longitude, startsAt, endsAt, preparationNotes, status, isDemo
        case tier, checkInCode, rewardBadgeId, link, imageData
    }

    /// Hand-written for the same reason `PersistedState`'s is: synthesized
    /// `Decodable` ignores property defaults and throws on a missing key, so a
    /// Fight saved before `tier` and `checkInCode` existed would fail to decode —
    /// and take the whole `hostedFights` array, and therefore the whole saved
    /// state, down with it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        // Defaulted, not required: a document written before the swap has no
        // `category`, and a throw here takes the whole Fights list down.
        category = try c.decodeIfPresent(HabitCategory.self, forKey: .category) ?? .actions
        hostName = try c.decodeIfPresent(String.self, forKey: .hostName) ?? ""
        hostId = try c.decodeIfPresent(String.self, forKey: .hostId) ?? ""
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        startsAt = try c.decode(Date.self, forKey: .startsAt)
        endsAt = try c.decode(Date.self, forKey: .endsAt)
        preparationNotes = try c.decodeIfPresent([String].self, forKey: .preparationNotes) ?? []
        link = try c.decodeIfPresent(String.self, forKey: .link)
        imageData = try c.decodeIfPresent(String.self, forKey: .imageData)
        status = try c.decodeIfPresent(Status.self, forKey: .status) ?? .published
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
        tier = try c.decodeIfPresent(EventTier.self, forKey: .tier) ?? .standard
        rewardBadgeId = try c.decodeIfPresent(String.self, forKey: .rewardBadgeId)
        // Derived from the id when absent, so a legacy Fight keeps the SAME code
        // across launches rather than being handed a new QR every time.
        checkInCode = try c.decodeIfPresent(String.self, forKey: .checkInCode)
            ?? Fight.makeCheckInCode(seed: id)
    }

    func isCheckInOpen(at moment: Date = Date()) -> Bool {
        status == .published && checkInWindow.contains(moment)
    }
}


/// A user's signup for one Fight. PRD §4.5: the check-in token is generated at signup
/// and lives on the attendee's phone.
nonisolated struct FightSignup: Codable, Hashable, Identifiable {
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
nonisolated struct FightAttendance: Codable, Hashable, Identifiable {
    var id: String { fightId }
    let fightId: String
    let checkedInAt: Date
    /// The day Vitality is credited against — written at check-in, never re-derived.
    let localDate: String

    /// Who checked in. Duplicates the document id `{fightId}_{userId}` on purpose: the
    /// security rules compare the two, and a host's roster can list attendees without
    /// parsing ids.
    let userId: String

    /// The code that was actually presented. The rules check it against the Fight's own
    /// `checkInCode`, which is what stops a check-in forged by someone who never had it.
    let code: String

    init(fightId: String, checkedInAt: Date, localDate: String, userId: String, code: String) {
        self.fightId = fightId
        self.checkedInAt = checkedInAt
        self.localDate = localDate
        self.userId = userId
        self.code = code
    }

    /// Hand-written for the same reason `PersistedState`'s is.
    ///
    /// Synthesized `Decodable` throws on a missing key rather than using a default, and
    /// these records sit inside `PersistedState.fightAttendance`. A throw there does not
    /// degrade to an empty dictionary — it propagates and takes the **entire account**
    /// down to a blank state. `userId` and `code` were added after people already had
    /// attendance saved, so without this, shipping this change would have wiped them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fightId = try c.decode(String.self, forKey: .fightId)
        checkedInAt = try c.decode(Date.self, forKey: .checkedInAt)
        localDate = try c.decode(String.self, forKey: .localDate)
        userId = try c.decodeIfPresent(String.self, forKey: .userId) ?? ""
        code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
    }
}

/// One scan on the **host's** device (PRD §6.5.1).
///
/// Distinct from `FightAttendance`, which is the attendee's own record. Until
/// Phase 10 these cannot be the same thing: awarding Vitality to another user is
/// a cross-user write, and there is no server to authorise it. The host records
/// who they scanned; the attendee's device credits itself.
nonisolated struct HostScan: Codable, Hashable, Identifiable {
    var id: String { token }
    let fightId: String
    let token: String
    /// What the host sees in the roster. Parsed out of the token.
    let attendeeLabel: String
    let scannedAt: Date
}
