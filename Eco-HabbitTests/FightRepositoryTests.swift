import XCTest
@testable import Eco_Habbit

/// PRD §4.4 signup rules and §4.5 check-in rules.
final class FightRepositoryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)   // fixed clock

    /// An event running from `startsIn` hours from `now`, for `duration` hours.
    private func fight(_ id: String = "f1", startsIn hours: Double, duration: Double = 3,
                       status: Fight.Status = .published) -> Fight {
        let start = now.addingTimeInterval(hours * 3600)
        return Fight(
            id: id, title: "Cleanup", summary: "", type: .beachCleanup,
            hostName: "Ombak Bersih", hostId: "org-ombak",
            locationName: "Berawa", address: "Canggu",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(duration * 3600),
            status: status
        )
    }

    private func state() -> UserState {
        var state = UserState(userId: "test-user")
        state.currentPoints = 500
        return state
    }

    // MARK: - Signup

    func testSignUpThenCancel() {
        let f = fight(startsIn: 48)
        var s = state()

        XCTAssertEqual(FightRepository.signUp(for: f, in: &s, now: now), .signedUp)
        XCTAssertTrue(FightRepository.isSignedUp(f.id, in: s))

        XCTAssertTrue(FightRepository.cancelSignup(for: f.id, in: &s, now: now))
        XCTAssertFalse(FightRepository.isSignedUp(f.id, in: s))
    }

    func testSignUpIsIdempotent() {
        let f = fight(startsIn: 48)
        var s = state()

        FightRepository.signUp(for: f, in: &s, now: now)
        XCTAssertEqual(FightRepository.signUp(for: f, in: &s, now: now), .alreadySignedUp)
        XCTAssertEqual(s.fightSignups.count, 1)
    }

    func testCannotJoinAFinishedFight() {
        var s = state()
        XCTAssertEqual(FightRepository.signUp(for: fight(startsIn: -48), in: &s, now: now), .eventFinished)
    }

    func testCannotJoinACancelledFight() {
        var s = state()
        let f = fight(startsIn: 48, status: .cancelled)
        XCTAssertEqual(FightRepository.signUp(for: f, in: &s, now: now), .eventCancelled)
    }

    /// Re-joining issues a fresh token, so a screenshot of the old QR is worthless.
    func testRejoiningIssuesANewToken() {
        let f = fight(startsIn: 48)
        var s = state()

        FightRepository.signUp(for: f, in: &s, now: now)
        let first = s.fightSignups[f.id]?.checkInToken
        FightRepository.cancelSignup(for: f.id, in: &s, now: now)
        FightRepository.signUp(for: f, in: &s, now: now)

        XCTAssertNotEqual(first, s.fightSignups[f.id]?.checkInToken)
        XCTAssertTrue(FightRepository.isSignedUp(f.id, in: s))
    }

    // MARK: - Check-in window (§4.5: −1h / +3h)

    func testCheckInWindowBounds() {
        let f = fight(startsIn: 0, duration: 3)
        XCTAssertFalse(f.isCheckInOpen(at: now.addingTimeInterval(-61 * 60)), "61 min before start")
        XCTAssertTrue(f.isCheckInOpen(at: now.addingTimeInterval(-59 * 60)), "59 min before start")
        XCTAssertTrue(f.isCheckInOpen(at: now.addingTimeInterval(3 * 3600)), "at the end")
        XCTAssertTrue(f.isCheckInOpen(at: now.addingTimeInterval(5.9 * 3600)), "within +3h of the end")
        XCTAssertFalse(f.isCheckInOpen(at: now.addingTimeInterval(6.1 * 3600)), "past +3h")
    }

    func testCheckInTooEarlyIsRejected() {
        let f = fight(startsIn: 48)
        var s = state()
        FightRepository.signUp(for: f, in: &s, now: now)

        XCTAssertEqual(FightRepository.checkIn(to: f, in: &s, now: now), .windowClosed)
        XCTAssertTrue(s.attendedEventIDs.isEmpty)
    }

    func testCheckInRequiresSignup() {
        let f = fight(startsIn: 0)
        var s = state()
        XCTAssertEqual(FightRepository.checkIn(to: f, in: &s, now: now), .notSignedUp)
    }

    // MARK: - Attendance

    func testCheckInMarksTheDayForTheEvaluationLoop() {
        let f = fight(startsIn: 0)
        var s = state()
        FightRepository.signUp(for: f, in: &s, now: now)

        // A standard-tier Fight pays 75, the same as a standard Event claim.
        XCTAssertEqual(FightRepository.checkIn(to: f, in: &s, now: now),
                       .checkedIn(pointsAwarded: 75, wasCapped: false))
        XCTAssertTrue(s.attendedEventIDs.contains(f.id))
        XCTAssertNotNil(s.fightAttendance[f.id])
    }

    /// Vitality is *not* moved at check-in — the loop applies it when it scores the day.
    /// Same split as §9.3: the attendance record is the truth, Vitality is derived.

    /// §4.5 — one check-in per attendee per event.
    func testDoubleCheckInIsRejected() {
        let f = fight(startsIn: 0)
        var s = state()
        FightRepository.signUp(for: f, in: &s, now: now)
        FightRepository.checkIn(to: f, in: &s, now: now)

        XCTAssertEqual(FightRepository.checkIn(to: f, in: &s, now: now), .alreadyCheckedIn)
        XCTAssertEqual(s.fightAttendance.count, 1)
    }

    func testCannotCancelAfterAttending() {
        let f = fight(startsIn: 0)
        var s = state()
        FightRepository.signUp(for: f, in: &s, now: now)
        FightRepository.checkIn(to: f, in: &s, now: now)

        XCTAssertFalse(FightRepository.cancelSignup(for: f.id, in: &s, now: now))
    }

    // MARK: - The full loop, end to end

    /// The end-to-end path: join, check in, points land immediately. There is
    /// no evaluation loop any more — `checkIn` credits the account directly,
    /// the same way `EventClaimService` does.
    func testJoinThenCheckInAwardsPoints() {
        let f = fight(startsIn: 0)
        var s = state()

        FightRepository.signUp(for: f, in: &s, now: now)
        FightRepository.checkIn(to: f, in: &s, now: now)

        XCTAssertEqual(s.currentPoints, 575, "500 + 75 for a standard tier")
        XCTAssertTrue(FightRepository.hasAttended(f.id, in: s))
    }

    // MARK: - Lists

    func testUpcomingIsChronologicalAndExcludesFinished() {
        let fights = [fight("c", startsIn: 72), fight("a", startsIn: 4),
                      fight("past", startsIn: -48), fight("b", startsIn: 24)]
        XCTAssertEqual(FightRepository.upcoming(fights, now: now).map(\.id), ["a", "b", "c"])
    }

    func testUpcomingExcludesCancelled() {
        let fights = [fight("live", startsIn: 24), fight("dead", startsIn: 24, status: .cancelled)]
        XCTAssertEqual(FightRepository.upcoming(fights, now: now).map(\.id), ["live"])
    }

    // MARK: - Seed data

    /// §12.1 — a visitor must be able to sign up and be checked in live at the booth, so
    /// at least one seeded event needs an open window whenever the app is launched.
    func testSeedAlwaysHasAnOpenCheckInWindow() throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "fights", withExtension: "json")
                ?? Bundle.main.url(forResource: "fights", withExtension: "json")
        )
        let seeds = try JSONDecoder().decode([FightSeed].self, from: Data(contentsOf: url))
        let fights = seeds.map { $0.materialise(now: now) }

        XCTAssertFalse(fights.isEmpty)
        XCTAssertTrue(fights.contains { $0.isCheckInOpen(at: now) },
                      "no seeded Fight is checkable-in right now — the exhibit demo would dead-end")
        XCTAssertEqual(fights.filter { $0.endsAt > now }.count, fights.count,
                       "every seeded Fight must still be upcoming")
        XCTAssertTrue(fights.allSatisfy(\.isDemo), "seed data must be labelled as demo")
    }
}
