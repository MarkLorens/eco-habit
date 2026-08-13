import XCTest
@testable import Eco_Habbit

/// The actions list prices every row from `AppState.projectedPoints`.
///
/// One rule holds the feature up: **the number on the row must be the number the
/// tap awards.** A row that promises 10 and pays 14 is merely confusing; a row
/// that promises 14 and pays 0 because the daily cap is spent reads as theft.
/// `testProjectionEqualsWhatLoggingActuallyAwards` is the test that matters —
/// the rest pin the three inputs that are easy to get wrong.
final class ProjectedPointsTests: XCTestCase {

    private let userId = "projection-test-user"
    private let calendar = Calendar.current

    @MainActor
    private func freshApp() async -> AppState {
        let app = AppState(userId: userId,
                           store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()
        return app
    }

    /// Logs whatever it takes to spend exactly `target` base points today.
    /// Fails loudly rather than quietly approximating — a cap test on the wrong
    /// number proves nothing.
    @MainActor
    private func spendBasePoints(_ target: Int, in app: AppState) async {
        for activity in MockActivityData.all where app.basePointsUsedToday < target {
            guard app.basePointsUsedToday + activity.basePoints <= target else { continue }
            await app.logActivity(activity)
        }
        XCTAssertEqual(app.basePointsUsedToday, target,
                       "could not spend exactly \(target) base points from the catalogue")
    }

    /// Logs on each of the `days` calendar days ending yesterday, leaving the
    /// account on a streak of `days` with nothing logged today.
    @MainActor
    private func buildStreak(_ days: Int, in app: AppState) async {
        let activity = MockActivityData.all[0]
        for daysAgo in stride(from: days, through: 1, by: -1) {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
            await app.logActivity(activity, now: day)
        }
        // Those logs left the published counters pointing at the last backdated
        // day. Re-read for today.
        await app.bootstrap()
    }

    // MARK: - The invariant

    /// Project, then log, then compare. Run in the nastiest state available:
    /// a live streak multiplier *and* a partly-spent daily cap.
    @MainActor
    func testProjectionEqualsWhatLoggingActuallyAwards() async {
        let app = await freshApp()
        await buildStreak(6, in: app)      // next log is day 7 → ×1.1
        await spendBasePoints(50, in: app)

        let activity = try! XCTUnwrap(
            MockActivityData.all.first { !app.isCompletedToday($0.id) }
        )
        let projected = app.projectedPoints(for: activity).finalPoints

        guard case .success(let outcome) = await app.logActivity(activity) else {
            return XCTFail("logging \(activity.id) did not succeed")
        }

        XCTAssertEqual(projected, outcome.breakdown.finalPoints,
                       "the row promised \(projected) and the tap paid \(outcome.breakdown.finalPoints)")
    }

    // MARK: - Input 1: the streak is the one you're about to have

    /// The trap. Six days on record, last log yesterday — the next tap makes it
    /// day 7, and the service scores that tap at ×1.1. Pricing the row from
    /// `currentStreak` would advertise ×1.0 and underpromise by a tier.
    @MainActor
    func testProjectionUsesTheStreakTheNextLogWillReach() async {
        let app = await freshApp()
        await buildStreak(6, in: app)

        XCTAssertEqual(app.userState.currentStreak, 6, "precondition")
        XCTAssertEqual(app.prospectiveStreak(), 7,
                       "the next log is day 7, not day 6")
        XCTAssertEqual(app.streakMultiplier(), 1.1, accuracy: 0.0001,
                       "day 7 crosses into the first bonus tier")
    }

    @MainActor
    func testFreshAccountProjectsPlainBasePoints() async {
        let app = await freshApp()

        XCTAssertEqual(app.streakMultiplier(), 1.0, accuracy: 0.0001)
        for activity in MockActivityData.all {
            XCTAssertEqual(app.projectedPoints(for: activity).finalPoints,
                           activity.basePoints,
                           "\(activity.id) should read its plain base value")
        }
    }

    // MARK: - Input 2: the daily cap

    @MainActor
    func testProjectionRespectsAPartlySpentCap() async {
        let app = await freshApp()
        await spendBasePoints(95, in: app)

        let f3 = try! XCTUnwrap(
            MockActivityData.all.first {
                $0.frictionLevel == .f3 && !app.isCompletedToday($0.id)
            }
        )
        // 15 base, but only 5 of the cap left, and a day-1 streak is ×1.0.
        XCTAssertEqual(app.projectedPoints(for: f3).finalPoints, 5)
        XCTAssertEqual(app.remainingDailyBasePoints, 5)
        XCTAssertFalse(app.isDailyCapReached)
    }

    @MainActor
    func testProjectionIsZeroOnceTheCapIsSpent() async {
        let app = await freshApp()
        await spendBasePoints(100, in: app)

        XCTAssertTrue(app.isDailyCapReached)
        XCTAssertEqual(app.remainingDailyBasePoints, 0)

        for activity in MockActivityData.all where !app.isCompletedToday(activity.id) {
            XCTAssertEqual(app.projectedPoints(for: activity).finalPoints, 0,
                           "\(activity.id) still promises points after the cap")
        }
    }

    // MARK: - Completed rows report history, not a fresh projection

    /// A ticked row must show what it earned. Re-projecting it would subtract a
    /// cap that this very log already spent, so an action that paid 20 would
    /// read "+0" the moment the day filled up — as if the effort were revoked.
    @MainActor
    func testCompletedRowShowsWhatItActuallyEarned() async {
        let app = await freshApp()
        let activity = MockActivityData.all[0]

        guard case .success(let outcome) = await app.logActivity(activity) else {
            return XCTFail("precondition: logging failed")
        }
        let earned = outcome.breakdown.finalPoints

        // Fill the rest of the day so a re-projection would now return 0.
        await spendBasePoints(100, in: app)

        XCTAssertEqual(app.loggedPoints(for: activity.id), earned)
        XCTAssertEqual(app.projectedPoints(for: activity).finalPoints, 0,
                       "precondition: a projection here would indeed read 0")
    }

    @MainActor
    func testLoggedPointsIsNilForSomethingNotDoneToday() async {
        let app = await freshApp()
        XCTAssertNil(app.loggedPoints(for: MockActivityData.all[0].id))
    }

    // MARK: - The economy

    /// The photo multiplier was removed. The field survives so stored logs keep
    /// decoding — this asserts it stays neutral, making a revival deliberate.
    func testPhotoEvidenceNoLongerMultipliesPoints() {
        let config = PointsConfiguration.default
        XCTAssertEqual(config.evidenceBonus(hasEvidence: true), 1.0, accuracy: 0.0001)
        XCTAssertEqual(config.evidenceBonus(hasEvidence: false), 1.0, accuracy: 0.0001)
    }
}
