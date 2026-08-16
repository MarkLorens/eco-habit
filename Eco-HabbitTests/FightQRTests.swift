import XCTest
@testable import Eco_Habbit

/// The QR path into Fight check-in.
///
/// The camera that reads these is also the habit scanner, so it spends its life
/// pointed at arbitrary scenes. The scheme on the payload is what stops every
/// other QR in the world — a wifi code, a menu, a payment code — from being
/// tried against the fight list. `testAnythingWithoutTheSchemeIsRejected` is the
/// test the whole design rests on.
final class FightQRTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fight(
        _ id: String = "f1",
        code: String = "BERAWA",
        startsIn hours: Double = 0,
        status: Fight.Status = .published
    ) -> Fight {
        let start = now.addingTimeInterval(hours * 3600)
        return Fight(
            id: id, title: "Cleanup", summary: "", type: .beachCleanup,
            hostName: "Ombak Bersih", hostId: "org-ombak",
            locationName: "Berawa", address: "Canggu",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(3 * 3600),
            status: status,
            checkInCode: code
        )
    }

    // MARK: - Payload

    func testPayloadRoundTrips() {
        let f = fight()
        XCTAssertEqual(f.checkInPayload, "ecohabit://fight/BERAWA")
        XCTAssertEqual(Fight.code(fromPayload: f.checkInPayload), "BERAWA")
    }

    /// The gate. Anything the app did not produce must resolve to nothing at all
    /// — not to a wrong Fight, and not to an error the user has to dismiss.
    func testAnythingWithoutTheSchemeIsRejected() {
        let strangers = [
            "BERAWA",                                  // the bare code, as it used to be
            "https://example.com/fight/BERAWA",
            "WIFI:S:CafeGuest;T:WPA;P:hunter2;;",
            "ecohabit://badge/BERAWA",                 // right app, wrong noun
            "ecohabit://fight/",                       // scheme, no code
            "",
            "   ",
        ]
        for raw in strangers {
            XCTAssertNil(Fight.code(fromPayload: raw), "\(raw.debugDescription) should be ignored")
        }
    }

    /// A scanner or a copy-paste can change case; the code itself is normalised
    /// again downstream, so the parser only has to survive the journey.
    func testPayloadToleratesCaseAndSurroundingWhitespace() {
        for raw in ["ECOHABIT://FIGHT/BERAWA", "  ecohabit://fight/berawa\n"] {
            guard let code = Fight.code(fromPayload: raw) else {
                return XCTFail("\(raw.debugDescription) should have parsed")
            }
            XCTAssertTrue(fight().matchesCheckInCode(code), "\(code) should match the Fight")
        }
    }

    // MARK: - Lookup and check-in

    @MainActor
    func testScanningTheOrganisersCodeChecksIn() async {
        let app = AppState(userId: "qr-user", store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()

        guard let live = app.upcomingFights.first(where: { $0.isCheckInOpen() }) else {
            return XCTFail("no seeded Fight with an open check-in window")
        }
        guard let code = Fight.code(fromPayload: live.checkInPayload) else {
            return XCTFail("payload did not parse")
        }

        XCTAssertEqual(app.fight(matchingCode: code)?.id, live.id)

        guard case .checkedIn = await app.checkIn(to: live, code: code) else {
            return XCTFail("expected a check-in")
        }
        XCTAssertTrue(app.hasAttended(live))
    }

    /// "Scannable once" — the second scan must not pay again.
    @MainActor
    func testScanningTwiceCreditsOnce() async {
        let app = AppState(userId: "qr-user", store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()

        guard let live = app.upcomingFights.first(where: { $0.isCheckInOpen() }) else {
            return XCTFail("no seeded Fight with an open check-in window")
        }
        await app.checkIn(to: live, code: live.checkInCode)
        let after = app.currentPoints

        let second = await app.checkIn(to: live, code: live.checkInCode)
        XCTAssertEqual(second, .alreadyCheckedIn)
        XCTAssertEqual(app.currentPoints, after, "a second scan must not pay twice")
    }

    /// A draft inside its time window must not report "the window is shut".
    ///
    /// This is what made a Fight created for *right now* look broken: the start
    /// time was a minute ago, so the organiser reasonably concluded the clock was
    /// wrong. The window was fine — `isCheckInOpen` also requires `.published`,
    /// and the two failures had one message between them.
    func testADraftIsReportedAsADraftNotAClosedWindow() {
        var state = UserState(userId: "draft-test")
        // Started a minute ago: unambiguously inside [start-1h, end+3h].
        let draft = fight(startsIn: -0.02, status: .draft)

        XCTAssertTrue(draft.checkInWindow.contains(now), "precondition: the window is open")
        XCTAssertEqual(
            FightRepository.checkIn(to: draft, code: "BERAWA", in: &state, now: now),
            .notPublished
        )
    }

    func testPublishingTheSameDraftThenAllowsCheckIn() {
        var state = UserState(userId: "draft-test")
        var live = fight(startsIn: -0.02, status: .draft)
        live.status = .published

        guard case .checkedIn = FightRepository.checkIn(to: live, code: "BERAWA", in: &state, now: now) else {
            return XCTFail("a published Fight inside its window must accept the code")
        }
    }

    @MainActor
    func testACodeNoFightOwnsResolvesToNothing() async {
        let app = AppState(userId: "qr-user", store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()

        // Well-formed payload, code belongs to nobody.
        let code = Fight.code(fromPayload: "ecohabit://fight/ZZZZZZ")
        XCTAssertEqual(code, "ZZZZZZ")
        XCTAssertNil(app.fight(matchingCode: "ZZZZZZ"))
    }

    /// Every seeded Fight must have a code that resolves back to itself —
    /// otherwise a poster at the booth scans into the wrong event.
    @MainActor
    func testSeededFightCodesAreUniqueAndResolveToThemselves() async {
        let app = AppState(userId: "qr-user", store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()

        let codes = app.allFights.map(\.checkInCode)
        XCTAssertEqual(Set(codes).count, codes.count, "two Fights share a check-in code")

        for f in app.allFights {
            guard let parsed = Fight.code(fromPayload: f.checkInPayload) else {
                return XCTFail("\(f.id) payload did not parse")
            }
            XCTAssertEqual(app.fight(matchingCode: parsed)?.id, f.id)
        }
    }
}
