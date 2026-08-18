import XCTest
@testable import Eco_Habbit

/// "Reset local data" has to clear four stores, not one.
///
/// The bug this pins: resetting only `UserState` looked right — points and
/// streak went to zero — while every `ActivityLog` survived. The next refresh
/// put today's activities straight back, and their dedup keys went on blocking
/// re-logging with nothing on screen to explain why.
final class ResetTests: XCTestCase {

    private let userId = "reset-test-user"

    private func makeStore() -> InMemoryKeyValueStore { InMemoryKeyValueStore() }

    @MainActor
    private func seededApp() async -> AppState {
        let app = AppState(userId: userId, store: makeStore(), seedDemoDataIfEmpty: false)
        await app.bootstrap()
        // Log a couple of things so there is something to survive.
        let activities = MockActivityData.all.prefix(2)
        for activity in activities {
            await app.logActivity(activity)
        }
        return app
    }

    @MainActor
    func testResetClearsPointsStreakAndLogs() async {
        let app = await seededApp()

        XCTAssertGreaterThan(app.currentPoints, 0, "precondition: something was logged")
        XCTAssertFalse(app.completedTodayIDs.isEmpty)
        XCTAssertFalse(app.history.isEmpty)

        await app.resetEverything()

        XCTAssertEqual(app.currentPoints, 0)
        XCTAssertEqual(app.userState.currentStreak, 0)
        XCTAssertTrue(app.completedTodayIDs.isEmpty, "today's activities must clear")
        XCTAssertTrue(app.history.isEmpty, "the log history must clear")
    }

    /// The real regression. A reset that leaves logs behind repopulates the
    /// completed set the moment anything re-reads them.
    @MainActor
    func testLogsStayGoneAfterAReread() async {
        let app = await seededApp()
        await app.resetEverything()

        // bootstrap() re-reads every store — the old bug surfaced exactly here.
        await app.bootstrap()

        XCTAssertTrue(app.completedTodayIDs.isEmpty,
                      "logs came back after re-reading — deleteAll did not run")
        XCTAssertEqual(app.currentPoints, 0)
    }

    /// And the activity must be loggable again, which is what the surviving
    /// dedup keys used to prevent.
    @MainActor
    func testAnActivityCanBeLoggedAgainAfterReset() async {
        let app = await seededApp()
        let activity = MockActivityData.all[0]

        await app.resetEverything()
        let result = await app.logActivity(activity)

        guard case .success = result else {
            return XCTFail("re-logging after reset returned \(result), not .success")
        }
        XCTAssertTrue(app.isCompletedToday(activity.id))
    }

    @MainActor
    func testBadgeUnlocksClear() async {
        let app = AppState(userId: userId, store: makeStore(), seedDemoDataIfEmpty: false)
        await app.bootstrap()

        await app.resetEverything()

        XCTAssertEqual(app.unlockedBadgeCount, 0)
        XCTAssertFalse(app.badges.isEmpty, "the catalogue itself must survive, only unlocks reset")
    }
}
