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

    // MARK: - The check-in code

    /// A generated code has to survive being read off a screen and typed by
    /// somebody standing on a beach, so the alphabet drops the characters that
    /// get misread.
    func testGeneratedCodesAvoidAmbiguousCharacters() {
        let forbidden = Set("O0I1")
        for _ in 0..<200 {
            let code = Fight.makeCheckInCode()
            XCTAssertEqual(code.count, 6)
            XCTAssertTrue(code.allSatisfy { !forbidden.contains($0) },
                          "\(code) contains a character that gets misread")
        }
    }

    func testGeneratedCodesAreNotAllTheSame() {
        let codes = Set((0..<50).map { _ in Fight.makeCheckInCode() })
        XCTAssertGreaterThan(codes.count, 40, "codes are barely varying — check the generator")
    }

    /// Each hosted Fight gets its own code. Two drafts sharing one would let an
    /// attendee check into an event they never went to.
    func testEachDraftGetsItsOwnCode() {
        var s = hostState()
        FightRepository.createDraft(fight("a"), in: &s)
        FightRepository.createDraft(fight("b"), in: &s)

        let codes = Set(s.hostedFights.map(\.checkInCode))
        XCTAssertEqual(codes.count, 2)
        XCTAssertFalse(codes.contains(""), "a Fight without a code cannot be checked into")
    }

    /// Locally a host only ever sees their own check-in — there is no server to
    /// tell them about anyone else's. The screen says so; this pins the number.
    func testKnownCheckInCountIsThisDeviceOnly() {
        var s = hostState()
        let live = liveFight()
        FightRepository.createDraft(live, in: &s)
        FightRepository.publish(live.id, in: &s)

        XCTAssertEqual(FightRepository.knownCheckInCount(for: live.id, in: s), 0)

        FightRepository.checkIn(to: live, code: live.checkInCode, in: &s, now: now)
        XCTAssertEqual(FightRepository.knownCheckInCount(for: live.id, in: s), 1)
    }
}
