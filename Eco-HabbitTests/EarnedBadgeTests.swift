import XCTest
@testable import Eco_Habbit

/// Badges are stored as **awards**, not as flags on the catalogue.
///
/// The old shape wrote the whole catalogue back with `isUnlocked` flipped and read
/// it by starting from the catalogue and merging those flags on. That made the
/// catalogue the source of truth for what somebody owned — so editing a data file
/// could take a badge away from a user who had genuinely earned it. These tests
/// pin the properties that fix.
final class EarnedBadgeTests: XCTestCase {

    private let userId = "earned-badge-user"
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func repo() -> MockBadgeRepository {
        MockBadgeRepository(store: InMemoryKeyValueStore())
    }

    private func award(_ id: String, _ name: String, at date: Date? = nil) -> EarnedBadge {
        EarnedBadge(badgeId: id, name: name, earnedAt: date ?? now, source: .threshold(7))
    }

    // MARK: - The award log

    func testAwardIsPersistedAndReadBack() async throws {
        let store = repo()
        try await store.award(award("badge_streak_7", "Seven Days In"), userId: userId)

        let earned = try await store.fetchEarned(userId: userId)
        XCTAssertEqual(earned.map(\.badgeId), ["badge_streak_7"])
        XCTAssertEqual(earned.first?.name, "Seven Days In")
    }

    /// Awarding twice must not move `earnedAt`.
    ///
    /// Anything that re-checks a badge the user already owns would otherwise
    /// quietly rewrite their history — and "when did I earn this" is the only
    /// reason to store a date at all.
    func testAwardingTwiceKeepsTheOriginalDate() async throws {
        let store = repo()
        let later = now.addingTimeInterval(86_400)

        try await store.award(award("badge_streak_7", "Seven Days In", at: now), userId: userId)
        try await store.award(award("badge_streak_7", "Seven Days In", at: later), userId: userId)

        let earned = try await store.fetchEarned(userId: userId)
        XCTAssertEqual(earned.count, 1, "one badge, one record")
        XCTAssertEqual(earned.first?.earnedAt, now, "the second award moved the date")
    }

    func testAwardsAreScopedToTheirUser() async throws {
        let store = repo()
        try await store.award(award("badge_streak_7", "Seven Days In"), userId: "a")
        let others = try await store.fetchEarned(userId: "b")
        XCTAssertTrue(others.isEmpty)
    }

    // MARK: - The reason this exists

    /// An earned badge must survive its catalogue entry being deleted or renamed.
    ///
    /// This is what the old design got wrong: `fetchBadges` returned
    /// `catalogue.map { }`, so a badge dropped from `MockBadgeData` — or a Fight
    /// reward whose id an organiser changed — vanished from the user's profile
    /// while the record sat untouched on disk.
    func testAnAwardSurvivesItsCatalogueEntryDisappearing() {
        let service = BadgeEvaluationService()
        let retired = award("badge_from_a_past_season", "Founding Member")

        let shown = service.display(catalogue: MockBadgeData.all, earned: [retired])

        let found = shown.first { $0.id == "badge_from_a_past_season" }
        XCTAssertNotNil(found, "the award disappeared with its catalogue entry")
        XCTAssertEqual(found?.name, "Founding Member", "rendered from the snapshot")
        XCTAssertTrue(found?.isUnlocked ?? false)
    }

    /// The flip side: while a badge *is* in the catalogue, its live copy wins, so
    /// fixing a typo in a description reaches everyone who already earned it.
    func testCatalogueCopyWinsWhileTheBadgeStillExists() {
        let service = BadgeEvaluationService()
        let stale = award("badge_streak_7", "Old Renamed Title")

        let shown = service.display(catalogue: MockBadgeData.all, earned: [stale])
        let found = shown.first { $0.id == "badge_streak_7" }

        XCTAssertEqual(found?.name, "Seven Days In", "should show the current name, not the snapshot")
        XCTAssertTrue(found?.isUnlocked ?? false)
        XCTAssertEqual(found?.unlockedDate, now)
    }

    // MARK: - Evaluation

    func testAlreadyEarnedBadgesAreNotAwardedAgain() {
        var state = UserState(userId: userId)
        state.currentStreak = 30

        let service = BadgeEvaluationService()
        let first = service.newlyEarned(from: MockBadgeData.all, state: state,
                                        alreadyEarned: [], at: now)
        XCTAssertTrue(first.contains { $0.badgeId == "badge_streak_7" })

        let second = service.newlyEarned(from: MockBadgeData.all, state: state,
                                         alreadyEarned: Set(first.map(\.badgeId)), at: now)
        XCTAssertTrue(second.isEmpty, "a badge already owned must never be re-awarded")
    }

    /// A points badge is its own permanent record. Someone who once touched 1,000
    /// points keeps it after decay takes those points away, and no separate
    /// high-water mark is needed to remember that.
    func testAPointsBadgeStaysEarnedAfterDecayTakesThePoints() {
        var state = UserState(userId: userId)
        state.currentPoints = 1_000

        let service = BadgeEvaluationService()
        let earned = service.newlyEarned(from: MockBadgeData.all, state: state,
                                         alreadyEarned: [], at: now)
        XCTAssertTrue(earned.contains { $0.badgeId == "badge_points_1000" })

        // Decay wipes the points that earned it.
        state.currentPoints = 150
        let shown = service.display(catalogue: MockBadgeData.all, earned: earned)
        XCTAssertTrue(shown.first { $0.id == "badge_points_1000" }?.isUnlocked ?? false)
    }

    func testThresholdAwardsRecordWhatTheyRequired() {
        var state = UserState(userId: userId)
        state.currentStreak = 7

        let earned = BadgeEvaluationService()
            .newlyEarned(from: MockBadgeData.all, state: state, alreadyEarned: [], at: now)

        guard let streak = earned.first(where: { $0.badgeId == "badge_streak_7" }) else {
            return XCTFail("expected the 7-day streak badge")
        }
        XCTAssertEqual(streak.source, .threshold(7))
    }

    // MARK: - End to end through AppState

    @MainActor
    func testCheckingIntoAFightWritesTheAwardWithItsFightId() async {
        let app = AppState(userId: userId,
                           store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()
        await app.setOrganization(true)

        // A live Fight from the bundled seeds that carries a reward badge.
        guard let fight = app.upcomingFights.first(where: {
            $0.rewardBadgeId != nil && $0.isCheckInOpen()
        }) else {
            return XCTFail("no seeded Fight with an open window and a reward badge")
        }

        await app.checkIn(to: fight, code: fight.checkInCode)

        guard let award = app.earnedBadges.first(where: { $0.badgeId == fight.rewardBadgeId }) else {
            return XCTFail("check-in did not write an award record")
        }
        XCTAssertEqual(award.source, .fight(fightId: fight.id))
        XCTAssertTrue(app.hasEarned(award.badgeId))
        XCTAssertEqual(app.unlockedBadgeCount, 1)
    }

    @MainActor
    func testResetClearsAwards() async {
        let app = AppState(userId: userId,
                           store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()
        await app.debugSetStreak(30)
        await app.logActivity(MockActivityData.all[0])

        XCTAssertFalse(app.earnedBadges.isEmpty, "precondition: a streak badge was earned")

        await app.resetEverything()

        XCTAssertTrue(app.earnedBadges.isEmpty)
        XCTAssertEqual(app.unlockedBadgeCount, 0)
        XCTAssertFalse(app.badges.isEmpty, "the catalogue itself must survive")
    }
}

/// The `AppState.badges` cache.
///
/// It is keyed on a revision counter rather than on anything derived from the
/// awards themselves. An earlier version keyed on `earnedBadges.count`, which
/// looks sound because awards are append-only — until a reset drops the count
/// back and a *different* badge brings it to the same number again.
final class BadgeCacheTests: XCTestCase {

    @MainActor
    private func freshApp() async -> AppState {
        let app = AppState(userId: "badge-cache-user",
                           store: InMemoryKeyValueStore(),
                           seedDemoDataIfEmpty: false)
        await app.bootstrap()
        return app
    }

    @MainActor
    func testEarningResettingAndEarningAgainDoesNotServeAStaleBadge() async {
        let app = await freshApp()

        // Earn a streak badge, and read `badges` so the cache is populated.
        await app.debugSetStreak(7)
        await app.logActivity(MockActivityData.all[0])
        XCTAssertTrue(app.badges.contains { $0.id == "badge_streak_7" && $0.isUnlocked })

        // Reset takes the count to 0 — deliberately without reading `badges`,
        // which is what made the count-based key look correct.
        await app.resetEverything()

        // Earn a *different* badge. The count is 1 again, as it was before.
        await app.debugSetStreak(30)
        await app.logActivity(MockActivityData.all[0])

        let unlocked = Set(app.badges.filter(\.isUnlocked).map(\.id))
        XCTAssertTrue(unlocked.contains("badge_streak_30"))
        XCTAssertEqual(app.unlockedBadgeCount, app.badges.filter(\.isUnlocked).count,
                       "the cached view and the award count disagree")
    }

    @MainActor
    func testRepeatedReadsAreConsistent() async {
        let app = await freshApp()
        await app.debugSetStreak(7)
        await app.logActivity(MockActivityData.all[0])

        XCTAssertEqual(app.badges.map(\.id), app.badges.map(\.id))
        XCTAssertEqual(app.badges.filter(\.isUnlocked).count, app.unlockedBadgeCount)
    }
}
