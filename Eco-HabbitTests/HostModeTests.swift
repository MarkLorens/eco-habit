import XCTest
@testable import Eco_Habbit

/// PRD §6.5.1 — the event lifecycle and the scanner.
final class HostModeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fight(
        _ id: String = "host-1",
        startsIn hours: Double = 0,
        duration: Double = 3,
        status: Fight.Status = .draft
    ) -> Fight {
        let start = now.addingTimeInterval(hours * 3600)
        return Fight(
            id: id, title: "Beach Cleanup", summary: "", type: .beachCleanup,
            hostName: "Ombak Bersih", hostId: "local-host",
            locationName: "Berawa", address: "Canggu",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(duration * 3600),
            status: status
        )
    }

    /// Running now, and public — the state a host actually scans in.
    private func liveFight(_ id: String = "host-1") -> Fight {
        fight(id, startsIn: 0, status: .published)
    }

    private func hostState() -> UserState {
        var state = UserState(userId: "test-user")
        state.isOrganization = true
        state.displayName = "Ombak Bersih"
        return state
    }

    // MARK: - Lifecycle

    /// §6.5.1 — "Events save as `draft` and require explicit Publish, so a
    /// half-written event never appears in the public list."
    func testNewEventsAreDraftsAndStayOutOfThePublicList() {
        var s = hostState()
        FightRepository.createDraft(fight(startsIn: 24), in: &s)

        XCTAssertEqual(s.hostedFights.first?.status, .draft)
        XCTAssertTrue(
            FightRepository.upcoming(s.hostedFights, now: now).isEmpty,
            "a draft must not be browsable"
        )
    }

    func testPublishingPutsItInTheList() {
        var s = hostState()
        FightRepository.createDraft(fight(startsIn: 24), in: &s)

        XCTAssertTrue(FightRepository.publish("host-1", in: &s))
        XCTAssertEqual(FightRepository.upcoming(s.hostedFights, now: now).map(\.id), ["host-1"])
    }

    func testPublishingTwiceIsRejected() {
        var s = hostState()
        FightRepository.createDraft(fight(startsIn: 24), in: &s)
        FightRepository.publish("host-1", in: &s)

        XCTAssertFalse(FightRepository.publish("host-1", in: &s))
    }

    /// §6.5.1 — "cancelling is not deletion... it stays visible to anyone signed up."
    func testCancellingKeepsTheEventButPullsItFromBrowse() {
        var s = hostState()
        FightRepository.createDraft(fight(startsIn: 24), in: &s)
        FightRepository.publish("host-1", in: &s)

        XCTAssertTrue(FightRepository.cancel("host-1", in: &s))
        XCTAssertEqual(s.hostedFights.count, 1, "cancelling must not delete")
        XCTAssertEqual(s.hostedFights.first?.status, .cancelled)
        XCTAssertTrue(FightRepository.upcoming(s.hostedFights, now: now).isEmpty)
    }

    /// Editing a published event is permitted, but an edit must not quietly
    /// change its status — publish and cancel are their own deliberate acts.
    func testEditingDoesNotChangeStatus() {
        var s = hostState()
        FightRepository.createDraft(fight(startsIn: 24), in: &s)
        FightRepository.publish("host-1", in: &s)

        var edited = s.hostedFights[0]
        edited.title = "Renamed"
        edited.status = .draft            // an edit form trying to reset it
        FightRepository.update(edited, in: &s)

        XCTAssertEqual(s.hostedFights[0].title, "Renamed")
        XCTAssertEqual(s.hostedFights[0].status, .published, "status is not editable")
    }

    func testIsHostOnlyForOwnEventsAndOnlyForOrganisations() {
        var s = hostState()
        let mine = fight()
        FightRepository.createDraft(mine, in: &s)

        XCTAssertTrue(FightRepository.isHost(of: mine, in: s))
        XCTAssertFalse(FightRepository.isHost(of: fight("someone-else"), in: s))

        s.isOrganization = false
        XCTAssertFalse(FightRepository.isHost(of: mine, in: s),
                       "losing verification loses hosting")
    }

    // MARK: - Token round trip

    func testTokenParsesBackToItsFightAndAttendee() {
        var attendee = UserState(userId: "test-user")
        attendee.displayName = "Made Wirawan"
        let event = fight(startsIn: 24)

        FightRepository.signUp(for: event, in: &attendee, now: now)
        let token = try! XCTUnwrap(attendee.fightSignups[event.id]?.checkInToken)

        let parsed = FightRepository.parseToken(token)
        XCTAssertEqual(parsed?.fightId, event.id)
        XCTAssertEqual(parsed?.attendeeLabel, "Made Wirawan")
    }

    func testGarbageCodesAreRejected() {
        for junk in ["", "hello", "EHF|only|three", "OTHER|f1|Someone|abcd1234"] {
            XCTAssertNil(FightRepository.parseToken(junk), "accepted \(junk)")
        }
    }

    // MARK: - Scanning

    private func token(for fightId: String, attendee: String) -> String {
        "\(FightRepository.tokenPrefix)|\(fightId)|\(attendee)|abcd1234"
    }

    func testScanningAddsToTheRoster() {
        var s = hostState()
        let event = liveFight()
        FightRepository.createDraft(event, in: &s)

        let result = FightRepository.recordScan(
            token(for: event.id, attendee: "Made"), for: event, in: &s, now: now
        )

        XCTAssertEqual(result, .accepted(attendee: "Made"))
        XCTAssertEqual(FightRepository.scans(for: event.id, in: s).count, 1)
    }

    /// §4.5 — one check-in per attendee per event. In Phase 10 the composite
    /// document ID enforces this; locally the repository has to.
    func testRescanningTheSameCodeIsADuplicate() {
        var s = hostState()
        let event = liveFight()
        let code = token(for: event.id, attendee: "Made")

        FightRepository.recordScan(code, for: event, in: &s, now: now)
        let second = FightRepository.recordScan(code, for: event, in: &s, now: now)

        XCTAssertEqual(second, .duplicate(attendee: "Made"))
        XCTAssertEqual(FightRepository.scans(for: event.id, in: s).count, 1)
    }

    func testTwoAttendeesBothCount() {
        var s = hostState()
        let event = liveFight()

        FightRepository.recordScan(token(for: event.id, attendee: "Made"), for: event, in: &s, now: now)
        FightRepository.recordScan(token(for: event.id, attendee: "Ayu"), for: event, in: &s, now: now)

        XCTAssertEqual(FightRepository.scans(for: event.id, in: s).count, 2)
    }

    func testAnotherEventsCodeIsRejected() {
        var s = hostState()
        let event = liveFight()

        let result = FightRepository.recordScan(
            token(for: "some-other-fight", attendee: "Made"), for: event, in: &s, now: now
        )

        XCTAssertEqual(result, .wrongEvent)
        XCTAssertTrue(FightRepository.scans(for: event.id, in: s).isEmpty)
    }

    func testScanningOutsideTheWindowIsRejected() {
        var s = hostState()
        let event = fight(startsIn: 48, status: .published)   // check-in opens 1h before

        let result = FightRepository.recordScan(
            token(for: event.id, attendee: "Made"), for: event, in: &s, now: now
        )

        XCTAssertEqual(result, .windowClosed)
    }

    /// Surfaced by these tests failing first time round: an unpublished event
    /// is not scannable, because `isCheckInOpen` requires `.published`. Nobody
    /// can have signed up to a draft, so nobody can have a code for one.
    func testADraftCannotBeScannedInto() {
        var s = hostState()
        let draft = fight(startsIn: 0, status: .draft)

        XCTAssertEqual(
            FightRepository.recordScan(token(for: draft.id, attendee: "Made"),
                                       for: draft, in: &s, now: now),
            .windowClosed
        )
    }

    func testACancelledEventCannotBeScannedInto() {
        var s = hostState()
        let cancelled = fight(startsIn: 0, status: .cancelled)

        XCTAssertEqual(
            FightRepository.recordScan(token(for: cancelled.id, attendee: "Made"),
                                       for: cancelled, in: &s, now: now),
            .eventCancelled
        )
    }

    func testUnreadableCodeIsRejected() {
        var s = hostState()
        let event = liveFight()
        XCTAssertEqual(
            FightRepository.recordScan("just some text", for: event, in: &s, now: now),
            .unreadable
        )
    }

    /// The host roster and the attendee's own points are separate records until
    /// Firebase lands — awarding another user points is a cross-user write with
    /// no server to authorise it (§9.3). Scanning fills the roster; the
    /// attendee's own device credits itself.
    func testScanningDoesNotAwardTheAttendeePoints() {
        var s = hostState()
        s.currentPoints = 500
        let event = liveFight()

        FightRepository.recordScan(token(for: event.id, attendee: "Someone Else"),
                                   for: event, in: &s, now: now)

        XCTAssertEqual(s.currentPoints, 500)
        XCTAssertTrue(s.attendedEventIDs.isEmpty)
    }
}
