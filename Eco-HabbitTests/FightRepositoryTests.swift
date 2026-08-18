import XCTest
@testable import Eco_Habbit

/// Saving a Fight, and checking in with the organiser's code.
final class FightRepositoryTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)   // fixed clock
    private let code = "BERAWA"

    /// A Fight running from `startsIn` hours from `now`, for `duration` hours.
    private func fight(
        _ id: String = "f1",
        startsIn hours: Double,
        duration: Double = 3,
        status: Fight.Status = .published,
        badge: String? = nil
    ) -> Fight {
        let start = now.addingTimeInterval(hours * 3600)
        return Fight(
            id: id, title: "Cleanup", summary: "", type: .beachCleanup,
            hostName: "Ombak Bersih", hostId: "org-ombak",
            locationName: "Berawa", address: "Canggu",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(duration * 3600),
            status: status,
            checkInCode: code,
            rewardBadgeId: badge
        )
    }

    private func state() -> UserState {
        var state = UserState(userId: "test-user")
        state.currentPoints = 500
        return state
    }

    // MARK: - Saved (a bookmark, nothing more)

    func testToggleSavedOnAndOff() {
        let f = fight(startsIn: 48)
        var s = state()

        XCTAssertTrue(FightRepository.toggleSaved(f.id, in: &s))
        XCTAssertTrue(FightRepository.isSaved(f.id, in: s))

        XCTAssertFalse(FightRepository.toggleSaved(f.id, in: &s))
        XCTAssertFalse(FightRepository.isSaved(f.id, in: s))
        XCTAssertTrue(s.savedFightIds.isEmpty, "unsaving must not leave a tombstone")
    }

    func testSavedListDropsFinishedFights() {
        let upcoming = fight("upcoming", startsIn: 48)
        let finished = fight("finished", startsIn: -48)
        var s = state()
        FightRepository.toggleSaved(upcoming.id, in: &s)
        FightRepository.toggleSaved(finished.id, in: &s)

        let saved = FightRepository.saved([upcoming, finished], in: s, now: now)
        XCTAssertEqual(saved.map(\.id), ["upcoming"],
                       "a saved Fight that has already happened is not a shortlist item")
    }

    func testSavedListIsSoonestFirst() {
        let later = fight("later", startsIn: 96)
        let sooner = fight("sooner", startsIn: 24)
        var s = state()
        FightRepository.toggleSaved(later.id, in: &s)
        FightRepository.toggleSaved(sooner.id, in: &s)

        XCTAssertEqual(FightRepository.saved([later, sooner], in: s, now: now).map(\.id),
                       ["sooner", "later"])
    }

    /// The rule that separates a bookmark from an RSVP.
    func testCheckInDoesNotRequireSaving() {
        let f = fight(startsIn: 0)
        var s = state()

        XCTAssertFalse(FightRepository.isSaved(f.id, in: s), "precondition: not saved")
        guard case .checkedIn = FightRepository.checkIn(to: f, code: code, in: &s, now: now) else {
            return XCTFail("someone who walks past a Fight must still be able to join it")
        }
    }

    // MARK: - Check-in by code

    func testCorrectCodeAwardsPoints() {
        let f = fight(startsIn: 0)
        var s = state()

        guard case .checkedIn(let points, let capped, let badge) =
                FightRepository.checkIn(to: f, code: code, in: &s, now: now) else {
            return XCTFail("expected a check-in")
        }
        XCTAssertEqual(points, f.attendancePoints)
        XCTAssertFalse(capped)
        XCTAssertNil(badge)
        XCTAssertEqual(s.currentPoints, 500 + f.attendancePoints)
        XCTAssertTrue(FightRepository.hasAttended(f.id, in: s))
    }

    func testWrongCodeAwardsNothing() {
        let f = fight(startsIn: 0)
        var s = state()

        XCTAssertEqual(FightRepository.checkIn(to: f, code: "NOPE12", in: &s, now: now), .wrongCode)
        XCTAssertEqual(s.currentPoints, 500, "a wrong code must not move the score")
        XCTAssertFalse(FightRepository.hasAttended(f.id, in: s))
    }

    /// The attendee is typing this on a beach. Rejecting their spacing teaches
    /// them nothing and just makes the app feel broken.
    func testCodeIgnoresCaseSpacingAndHyphens() {
        for entered in ["berawa", " BeRaWa ", "BER-AWA", "b e r a w a"] {
            var s = state()
            guard case .checkedIn = FightRepository.checkIn(
                to: fight(startsIn: 0), code: entered, in: &s, now: now
            ) else {
                return XCTFail("\"\(entered)\" should have been accepted")
            }
        }
    }

    func testEmptyCodeIsRejected() {
        var s = state()
        XCTAssertEqual(FightRepository.checkIn(to: fight(startsIn: 0), code: "   ", in: &s, now: now),
                       .wrongCode)
    }

    func testSecondCheckInIsRefused() {
        let f = fight(startsIn: 0)
        var s = state()

        FightRepository.checkIn(to: f, code: code, in: &s, now: now)
        let after = s.currentPoints

        XCTAssertEqual(FightRepository.checkIn(to: f, code: code, in: &s, now: now), .alreadyCheckedIn)
        XCTAssertEqual(s.currentPoints, after, "a repeat scan must not pay twice")
    }

    // MARK: - The window

    func testCheckInOpensAnHourBeforeTheStart() {
        var early = state()
        XCTAssertEqual(
            FightRepository.checkIn(to: fight(startsIn: 1.5), code: code, in: &early, now: now),
            .windowClosed
        )

        var open = state()
        guard case .checkedIn = FightRepository.checkIn(
            to: fight(startsIn: 0.5), code: code, in: &open, now: now
        ) else { return XCTFail("half an hour before the start is inside the window") }
    }

    func testCheckInClosesThreeHoursAfterTheEnd() {
        // Ran 3h, ended 3.5h ago — past the 3h grace.
        var s = state()
        XCTAssertEqual(
            FightRepository.checkIn(to: fight(startsIn: -6.5), code: code, in: &s, now: now),
            .windowClosed
        )
    }

    func testCancelledFightRefusesCheckIn() {
        var s = state()
        XCTAssertEqual(
            FightRepository.checkIn(to: fight(startsIn: 0, status: .cancelled), code: code, in: &s, now: now),
            .eventCancelled
        )
    }

    /// A wrong code should say so even when the window is shut — but a *right*
    /// code outside the window deserves the more useful message.
    func testWrongCodeOutsideTheWindowStillReadsAsWrongCode() {
        var s = state()
        XCTAssertEqual(
            FightRepository.checkIn(to: fight(startsIn: 48), code: "NOPE12", in: &s, now: now),
            .wrongCode
        )
    }

    // MARK: - Monthly cap

    func testAttendanceDrawsOnTheMonthlyEventQuota() {
        var s = state()
        s.monthlyEventPointsEarned = 100
        s.monthlyEventPointsPeriod = DateKeys.monthKey(for: now)

        // 75-point standard tier, but only 50 of the 150 cap is left.
        guard case .checkedIn(let points, let capped, _) =
                FightRepository.checkIn(to: fight(startsIn: 0), code: code, in: &s, now: now) else {
            return XCTFail("expected a check-in")
        }
        XCTAssertEqual(points, 50)
        XCTAssertTrue(capped)
        XCTAssertEqual(s.monthlyEventPointsEarned, 150)
    }

    func testAStaleMonthResetsTheQuota() {
        var s = state()
        s.monthlyEventPointsEarned = 150
        s.monthlyEventPointsPeriod = "1999-01"

        guard case .checkedIn(let points, let capped, _) =
                FightRepository.checkIn(to: fight(startsIn: 0), code: code, in: &s, now: now) else {
            return XCTFail("expected a check-in")
        }
        XCTAssertEqual(points, 75, "last year's quota must not limit this month")
        XCTAssertFalse(capped)
    }

    // MARK: - Badge reward

    func testOrganiserBadgeIsAwardedOnCheckIn() {
        let f = fight(startsIn: 0, badge: "fight_badge_shoreline")
        var s = state()

        guard case .checkedIn(_, _, let badge) =
                FightRepository.checkIn(to: f, code: code, in: &s, now: now) else {
            return XCTFail("expected a check-in")
        }
        XCTAssertEqual(badge?.id, "fight_badge_shoreline")
        // The award record is written by the caller; what belongs to check-in is
        // reporting the badge and stamping it on the attendance record.
        XCTAssertEqual(s.fightAttendance[f.id]?.awardedBadgeId, "fight_badge_shoreline")
    }

    /// Showing up happened. The quota limits the score, not the record.
    func testBadgeIsStillAwardedWhenThePointsAreCapped() {
        var s = state()
        s.monthlyEventPointsEarned = 150
        s.monthlyEventPointsPeriod = DateKeys.monthKey(for: now)

        guard case .checkedIn(let points, _, let badge) = FightRepository.checkIn(
            to: fight(startsIn: 0, badge: "fight_badge_shoreline"), code: code, in: &s, now: now
        ) else { return XCTFail("expected a check-in") }

        XCTAssertEqual(points, 0)
        XCTAssertEqual(badge?.id, "fight_badge_shoreline")
    }

    func testAnUnknownBadgeIdAwardsNothingRatherThanCrashing() {
        var s = state()
        guard case .checkedIn(_, _, let badge) = FightRepository.checkIn(
            to: fight(startsIn: 0, badge: "does_not_exist"), code: code, in: &s, now: now
        ) else { return XCTFail("expected a check-in") }

        XCTAssertNil(badge)
        XCTAssertNil(s.fightAttendance["f1"]?.awardedBadgeId)
    }

    /// A Fight reward must NEVER come out of threshold evaluation.
    ///
    /// It used to, via a threshold of 1 satisfied by a flag on `UserState` — which
    /// made the evaluator responsible for a fact it had no way to know, and split
    /// the record across two places. It is now awarded directly at check-in.
    func testFightRewardsAreNeverProducedByThresholdEvaluation() {
        var s = state()
        FightRepository.checkIn(
            to: fight(startsIn: 0, badge: "fight_badge_shoreline"), code: code, in: &s, now: now
        )

        let earned = BadgeEvaluationService()
            .newlyEarned(from: MockBadgeData.all, state: s, alreadyEarned: [], at: now)

        XCTAssertFalse(earned.contains { $0.badgeId.hasPrefix("fight_badge_") },
                       "Fight rewards are given, not reached — the evaluator must skip them")
    }

    // MARK: - Reads

    func testUpcomingHidesDraftsAndFinishedFights() {
        let live = fight("live", startsIn: 24)
        let draft = fight("draft", startsIn: 24, status: .draft)
        let done = fight("done", startsIn: -48)

        XCTAssertEqual(FightRepository.upcoming([live, draft, done], now: now).map(\.id), ["live"])
    }

    func testAttendedIsNewestFirst() {
        let a = fight("a", startsIn: 0)
        let b = fight("b", startsIn: 0)
        var s = state()

        FightRepository.checkIn(to: a, code: code, in: &s, now: now)
        FightRepository.checkIn(to: b, code: code, in: &s, now: now.addingTimeInterval(60))

        XCTAssertEqual(FightRepository.attended([a, b], in: s).map(\.id), ["b", "a"])
    }
}
