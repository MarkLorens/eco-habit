import SwiftUI
import Combine

/// The single object a View touches.
///
/// Same role as Tio's `AppStore` on the MockData branch, but an
/// `ObservableObject` rather than `@Observable` — the rest of this app's views
/// already bind that way, and converting them all was not worth the churn.
///
/// Views never call a service or a repository directly. That is what makes the
/// Firebase swap a change to `AppState.init` and nothing else: the six
/// repositories are protocol-typed and constructor-injected all the way down.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published private(set) var userState: UserState
    @Published private(set) var badges: [Badge] = []
    /// Derived from today's logs, never stored separately.
    @Published private(set) var completedTodayIDs: Set<String> = []
    /// Today's logs in full. Kept, not just their ids, so a row that is already
    /// ticked can show what it *actually* earned — re-projecting it would use a
    /// daily cap that this very log has already spent.
    @Published private(set) var todayLogs: [ActivityLog] = []
    /// Base points spent against the daily cap so far today. Published rather
    /// than queried, because every row on the actions list needs it to price
    /// itself on every redraw.
    @Published private(set) var basePointsUsedToday = 0
    /// Every log, newest first. Derived from the log repository, never stored
    /// separately — the logs are the record.
    @Published private(set) var history: [ActivityLog] = []
    /// Set when a badge unlocks, so a view can play the celebration once.
    @Published private(set) var recentlyUnlockedBadges: [Badge] = []
    @Published private(set) var lastDecay: DecayOutcome?
    @Published private(set) var isReady = false

    // Transient UI state that shouldn't survive a relaunch.
    @Published var selectedTab: AppTab = .home
    // Added for the action tab ya
    @Published var actionsPath = NavigationPath()
    @Published var isCameraPresented = false
    @Published var toast: Toast?
    @Published var lastAward: Award?

    // MARK: - Dependencies

    let userId: String
    let config: PointsConfiguration

    private let activityRepository: any ActivityRepositoryProtocol
    private let logRepository: any ActivityLogRepositoryProtocol
    private let userStateRepository: any UserStateRepositoryProtocol
    private let badgeRepository: any BadgeRepositoryProtocol

    private let loggingService: ActivityLoggingService
    private let decayService: DecayService
    private let streakService = StreakService()
    private let pointsService: PointsCalculationService
    /// The same provider `ActivityLoggingService` uses. Sharing it means the
    /// region bonus appears on the rows the day location is switched on, with
    /// nothing here to remember to update.
    private let provincePriority: any ProvincePriorityProviding = MockProvincePriorityProvider()

    private let seedDemoDataIfEmpty: Bool

    // MARK: - Init

    /// The one place the concrete data layer is chosen. Swapping the six `Mock*`
    /// types for `Firebase*` ones is the whole Firebase migration on the app side.
    init(
        userId: String = "demo-user",
        config: PointsConfiguration = .default,
        store: any KeyValueStoring = LocalJSONFileStore(),
        seedDemoDataIfEmpty: Bool = true
    ) {
        self.userId = userId
        self.config = config
        self.seedDemoDataIfEmpty = seedDemoDataIfEmpty

        activityRepository = MockActivityRepository()
        logRepository = MockActivityLogRepository(store: store)
        userStateRepository = MockUserStateRepository(store: store)
        badgeRepository = MockBadgeRepository(store: store)

        loggingService = ActivityLoggingService(
            config: config,
            activityRepository: activityRepository,
            logRepository: logRepository,
            userStateRepository: userStateRepository,
            badgeRepository: badgeRepository
        )
        decayService = DecayService(config: config)
        pointsService = PointsCalculationService(config: config)

        userState = UserState(userId: userId)
    }

    // MARK: - Bootstrap

    /// App open. Applies decay, loads badges, refreshes today's logs.
    /// Idempotent — safe to call on every foreground.
    func bootstrap(now: Date = Date()) async {
        do {
            var state = try await userStateRepository.fetchUserState(userId: userId)

            if seedDemoDataIfEmpty, state.currentPoints == 0, state.lastActivityDate == nil {
                state = MockUserStateData.demo
                try await userStateRepository.save(state)
            }

            // Decay is computed here, on app open — there is no background job.
            let outcome = decayService.apply(to: &state, asOf: now)
            if outcome.didDecay {
                try await userStateRepository.save(state)
            }

            userState = state
            lastDecay = outcome
            badges = try await badgeRepository.fetchBadges(userId: userId)
            await refreshTodayLogs(now: now)
            await refreshHistory()
        } catch {
            // Degrade to an empty account rather than blocking the UI.
            userState = UserState(userId: userId)
        }
        isReady = true
    }

    private func refreshHistory() async {
        let all = (try? await logRepository.fetchAllLogs(userId: userId)) ?? []
        history = all.sorted { $0.loggedAt > $1.loggedAt }
    }

    private func refreshTodayLogs(now: Date = Date()) async {
        let dayKey = DateKeys.dayKey(for: now)
        let logs = (try? await logRepository.fetchLogs(userId: userId, dayKey: dayKey)) ?? []
        todayLogs = logs
        completedTodayIDs = Set(logs.map(\.activityId))
        basePointsUsedToday = pointsService.basePointsUsed(in: logs)
    }

    // MARK: - Catalogue

    var activities: [Activity] { MockActivityData.all }

    func activities(in category: Category) -> [Activity] {
        MockActivityData.activities(in: category)
    }

    func activity(id: String) -> Activity? {
        MockActivityData.activity(withID: id)
    }

    func isCompletedToday(_ activityId: String) -> Bool {
        completedTodayIDs.contains(activityId)
    }

    func doneCount(in category: Category) -> Int {
        activities(in: category).filter { isCompletedToday($0.id) }.count
    }

    // MARK: - Progress reads

    var currentPoints: Int { userState.currentPoints }
    var earthStage: EarthStage { userState.earthStage(using: config) }

    /// Cosmetic — reads 0 once a streak is broken but not yet recorded.
    func displayStreak(asOf now: Date = Date()) -> Int {
        streakService.displayStreak(for: userState, asOf: now)
    }

    var pointsToNextStage: Int? {
        guard let next = earthStage.next else { return nil }
        return max(0, config.threshold(for: next) - userState.currentPoints)
    }

    var unlockedBadgeCount: Int { badges.filter(\.isUnlocked).count }
    var totalActionsLogged: Int { history.count }

    var remainingDailyBasePoints: Int {
        max(0, config.dailyBasePointsCap - basePointsUsedToday)
    }

    var isDailyCapReached: Bool { remainingDailyBasePoints == 0 }

    // MARK: - What an action is worth right now
    //
    // The actions list prices every row from here. The rule these three exist to
    // enforce: **the number on the row comes out of the same function that awards
    // the points.** A view that re-derives the maths drifts from the award, and a
    // row that promises more than it pays is worse than a row that says nothing.

    /// The streak an action logged *now* would produce — not the streak on
    /// record.
    ///
    /// The distinction is the whole reason this exists. `ActivityLoggingService`
    /// scores an action with the streak it just became, so a user sitting on day
    /// 6 who last logged yesterday earns ×1.1 on their next tap. Pricing the row
    /// from `currentStreak` would quietly show them ×1.0.
    func prospectiveStreak(now: Date = Date()) -> Int {
        streakService.outcome(for: userState, loggingOn: now).newStreak
    }

    /// The multiplier those rows should advertise.
    func streakMultiplier(now: Date = Date()) -> Double {
        config.streakMultiplier(forStreak: prospectiveStreak(now: now))
    }

    /// What logging `activity` right now would award, cap and streak included.
    func projectedPoints(for activity: Activity, now: Date = Date()) -> PointsBreakdown {
        pointsService.breakdown(
            activity: activity,
            hasEvidence: false,          // tapping a row is a checklist log
            currentStreak: prospectiveStreak(now: now),
            isPrioritized: provincePriority.isPrioritized(
                category: activity.category,
                provinceCode: userState.currentProvinceCode
            ),
            basePointsUsedToday: basePointsUsedToday
        )
    }

    /// What an already-logged action actually earned today.
    func loggedPoints(for activityId: String) -> Int? {
        todayLogs.first { $0.activityId == activityId }?.finalPoints
    }

    // MARK: - Logging

    @discardableResult
    func logActivity(
        _ activity: Activity,
        hasEvidence: Bool = false,
        source: LogSource = .manualChecklist,
        now: Date = Date()
    ) async -> LogActivityResult {
        recentlyUnlockedBadges = []

        let result: LogActivityResult
        do {
            result = try await loggingService.log(
                activityId: activity.id,
                userId: userId,
                hasEvidence: hasEvidence,
                source: source,
                now: now
            )
        } catch {
            toast = Toast(kind: .warning, message: "Couldn't save that. Try again.")
            return .activityNotFound
        }

        switch result {
        case .success(let outcome):
            userState = outcome.userState
            recentlyUnlockedBadges = outcome.unlockedBadges
            if !outcome.unlockedBadges.isEmpty {
                badges = (try? await badgeRepository.fetchBadges(userId: userId)) ?? badges
            }
            await refreshTodayLogs(now: now)
            await refreshHistory()
            lastAward = Award(activity: activity, points: outcome.breakdown.finalPoints)
            toast = Toast(kind: .success,
                          message: "\(activity.name) · +\(outcome.breakdown.finalPoints) pts")

        case .alreadyLoggedToday:
            toast = Toast(kind: .info, message: "Already logged today — back tomorrow.")

        case .onCooldown(let days):
            toast = Toast(kind: .info,
                          message: "Available again in \(days) day\(days == 1 ? "" : "s").")

        case .activityNotFound:
            toast = Toast(kind: .warning, message: "Couldn't log that one.")
        }
        return result
    }

    // MARK: - Fights

    var allFights: [Fight] { MockFightData.seeded + userState.hostedFights }
    func fight(id: String) -> Fight? { allFights.first { $0.id == id } }

    var upcomingFights: [Fight] { FightRepository.upcoming(allFights) }
    var savedFights: [Fight] { FightRepository.saved(allFights, in: userState) }
    var pastFights: [Fight] { FightRepository.attended(allFights, in: userState) }
    /// The dashboard's "what's next" — a saved Fight if there is one, otherwise
    /// the soonest public Fight, so the card is never empty for a new user.
    var nextFight: Fight? { savedFights.first ?? upcomingFights.first }
    var hostedFights: [Fight] { FightRepository.hostedFights(in: userState) }

    var isOrganization: Bool { userState.isOrganization }
    var orgName: String { userState.orgName.isEmpty ? displayName : userState.orgName }
    var displayName: String {
        userState.displayName.isEmpty ? MockUserStateData.demoDisplayName : userState.displayName
    }
    var firstName: String { displayName.split(separator: " ").first.map(String.init) ?? displayName }

    func isSaved(_ fight: Fight) -> Bool { FightRepository.isSaved(fight.id, in: userState) }
    func hasAttended(_ fight: Fight) -> Bool { FightRepository.hasAttended(fight.id, in: userState) }
    func isHost(of fight: Fight) -> Bool { FightRepository.isHost(of: fight, in: userState) }
    func checkInCount(for fight: Fight) -> Int {
        FightRepository.knownCheckInCount(for: fight.id, in: userState)
    }

    /// Badge this Fight awards, if the organiser attached one.
    func rewardBadge(for fight: Fight) -> Badge? {
        fight.rewardBadgeId.flatMap { MockBadgeData.fightReward(withID: $0) }
    }

    func toggleSaved(_ fight: Fight) async {
        let nowSaved = await mutateUser { FightRepository.toggleSaved(fight.id, in: &$0) }
        toast = Toast(kind: .info, message: nowSaved ? "Saved." : "Removed from saved.")
    }

    /// Check in with the code the organiser published.
    @discardableResult
    func checkIn(to fight: Fight, code: String) async -> FightRepository.CheckInResult {
        recentlyUnlockedBadges = []

        let result = await mutateUser {
            FightRepository.checkIn(to: fight, code: code, in: &$0)
        }

        switch result {
        case .checkedIn(let points, let capped, let badge):
            // The Fight badge is granted by attending, so the badge store has to
            // be re-read for the unlock to show up on the profile.
            if let badge {
                let all = (try? await badgeRepository.fetchBadges(userId: userId)) ?? badges
                let unlocked = BadgeEvaluationService()
                    .newlyUnlocked(from: all, state: userState)
                if !unlocked.isEmpty {
                    let merged = BadgeEvaluationService().merged(all, with: unlocked)
                    try? await badgeRepository.save(merged, userId: userId)
                    badges = merged
                    recentlyUnlockedBadges = unlocked
                }
                toast = Toast(kind: .success,
                              message: "Checked in · +\(points) pts · \(badge.name) unlocked")
            } else {
                toast = Toast(kind: .success, message: capped
                    ? "Checked in — monthly event cap reached."
                    : "Checked in · +\(points) pts")
            }
        case .wrongCode:
            toast = Toast(kind: .warning, message: "That code doesn't match this Fight.")
        case .alreadyCheckedIn:
            toast = Toast(kind: .info, message: "Already checked in.")
        case .windowClosed:
            toast = Toast(kind: .warning, message: "Check-in opens an hour before the start.")
        case .eventCancelled:
            toast = Toast(kind: .warning, message: "The organiser cancelled this Fight.")
        }
        return result
    }

    func newDraft(category: Category = .actions) -> Fight {
        let start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return Fight(
            id: "host-\(UUID().uuidString.prefix(8))",
            title: "", summary: "", category: category,
            hostName: orgName, hostId: userId,
            locationName: "", address: "",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(3 * 3600),
            preparationNotes: [], status: .draft, isDemo: false
        )
    }

    func saveDraft(_ fight: Fight) async {
        await mutateUser { state in
            if state.hostedFights.contains(where: { $0.id == fight.id }) {
                FightRepository.update(fight, in: &state)
            } else {
                FightRepository.createDraft(fight, in: &state)
            }
        }
        toast = Toast(kind: .success, message: "Saved as a draft.")
    }

    func publishFight(_ fight: Fight) async {
        let ok = await mutateUser { FightRepository.publish(fight.id, in: &$0) }
        toast = ok
            ? Toast(kind: .success, message: "Published — it's in the public list now.")
            : Toast(kind: .info, message: "Already published.")
    }

    func cancelHostedFight(_ fight: Fight) async {
        let ok = await mutateUser { FightRepository.cancel(fight.id, in: &$0) }
        if ok { toast = Toast(kind: .info, message: "Cancelled. Anyone who saved it still sees it.") }
    }

    // MARK: - Settings

    var notificationsEnabled: Bool { userState.notificationsEnabled }

    func setNotifications(_ on: Bool) async {
        await mutateUser { $0.notificationsEnabled = on }
    }

    func setOrganization(_ on: Bool, name: String = "Ombak Bersih") async {
        await mutateUser {
            $0.isOrganization = on
            $0.orgName = on ? name : ""
        }
    }

    /// Wipes the account: points, streak, badges **and every log**.
    ///
    /// Clearing only `UserState` is not a reset — the logs survive, so the next
    /// `refreshTodayLogs` puts today's activities straight back, and their
    /// dedup keys go on blocking re-logging with nothing on screen to explain
    /// why. All four stores have to go.
    func resetEverything() async {
        try? await logRepository.deleteAll(userId: userId)
        try? await badgeRepository.deleteAll(userId: userId)

        let fresh = UserState(userId: userId)
        try? await userStateRepository.save(fresh)

        userState = fresh
        completedTodayIDs = []
        todayLogs = []
        basePointsUsedToday = 0
        history = []
        recentlyUnlockedBadges = []
        lastAward = nil
        lastDecay = nil
        badges = (try? await badgeRepository.fetchBadges(userId: userId)) ?? []

        selectedTab = .home
        toast = Toast(kind: .info, message: "Local data cleared.")
    }

    // MARK: - Plumbing

    /// Mutate the user record and persist it. The Fight repository is a set of
    /// pure functions over `UserState`, so this is the only place they touch
    /// storage — the same shape the rest of the app uses.
    @discardableResult
    private func mutateUser<T>(_ change: (inout UserState) -> T) async -> T {
        var next = userState
        let result = change(&next)
        userState = next
        try? await userStateRepository.save(next)
        return result
    }
}
