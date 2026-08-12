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
    /// Every log, newest first. Derived from the log repository, never stored
    /// separately — the logs are the record.
    @Published private(set) var history: [ActivityLog] = []
    /// Set when a badge unlocks, so a view can play the celebration once.
    @Published private(set) var recentlyUnlockedBadges: [Badge] = []
    @Published private(set) var lastDecay: DecayOutcome?
    @Published private(set) var isReady = false

    // Transient UI state that shouldn't survive a relaunch.
    @Published var selectedTab: AppTab = .home
    @Published var isCameraPresented = false
    @Published var toast: Toast?
    @Published var lastAward: Award?

    // MARK: - Dependencies

    let userId: String
    let config: PointsConfiguration

    private let activityRepository: any ActivityRepositoryProtocol
    private let eventRepository: any EventRepositoryProtocol
    private let logRepository: any ActivityLogRepositoryProtocol
    private let eventLogRepository: any EventLogRepositoryProtocol
    private let userStateRepository: any UserStateRepositoryProtocol
    private let badgeRepository: any BadgeRepositoryProtocol

    private let loggingService: ActivityLoggingService
    private let eventClaimService: EventClaimService
    private let decayService: DecayService
    private let streakService = StreakService()

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
        eventRepository = MockEventRepository()
        logRepository = MockActivityLogRepository(store: store)
        eventLogRepository = MockEventLogRepository(store: store)
        userStateRepository = MockUserStateRepository(store: store)
        badgeRepository = MockBadgeRepository(store: store)

        loggingService = ActivityLoggingService(
            config: config,
            activityRepository: activityRepository,
            logRepository: logRepository,
            userStateRepository: userStateRepository,
            badgeRepository: badgeRepository
        )
        eventClaimService = EventClaimService(
            config: config,
            eventRepository: eventRepository,
            eventLogRepository: eventLogRepository,
            userStateRepository: userStateRepository,
            badgeRepository: badgeRepository
        )
        decayService = DecayService(config: config)

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
        completedTodayIDs = Set(logs.map(\.activityId))
    }

    // MARK: - Catalogue

    var activities: [Activity] { MockActivityData.all }
    var events: [Event] { MockEventData.all }

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

    func remainingDailyBasePoints(now: Date = Date()) async -> Int {
        let dayKey = DateKeys.dayKey(for: now)
        let logs = (try? await logRepository.fetchLogs(userId: userId, dayKey: dayKey)) ?? []
        let used = logs.reduce(0) { $0 + $1.countedBasePoints }
        return max(0, config.dailyBasePointsCap - used)
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

    // MARK: - Events (claimed, per Tio's model)

    @discardableResult
    func claimEvent(_ event: Event, checkInCode: String? = nil, now: Date = Date()) async -> ClaimEventResult {
        recentlyUnlockedBadges = []

        let result: ClaimEventResult
        do {
            result = try await eventClaimService.claim(
                eventId: event.id, userId: userId, checkInCode: checkInCode, now: now
            )
        } catch {
            toast = Toast(kind: .warning, message: "Couldn't claim that. Try again.")
            return .eventNotFound
        }

        switch result {
        case .success(let outcome):
            userState = outcome.userState
            recentlyUnlockedBadges = outcome.unlockedBadges
            if !outcome.unlockedBadges.isEmpty {
                badges = (try? await badgeRepository.fetchBadges(userId: userId)) ?? badges
            }
            toast = Toast(kind: .success, message: outcome.wasCapped
                ? "Claimed — monthly event cap reached."
                : "Claimed · +\(outcome.log.awardedPoints) pts")
        case .alreadyClaimed:
            toast = Toast(kind: .info, message: "Already claimed.")
        case .eventNotFound:
            toast = Toast(kind: .warning, message: "That event no longer exists.")
        case .checkInCodeRequired:
            toast = Toast(kind: .warning, message: "This event needs a check-in code.")
        }
        return result
    }

    // MARK: - Fights (hosted events with QR check-in, PRD §4 / §6.5.1)

    var allFights: [Fight] { MockFightData.seeded + userState.hostedFights }
    func fight(id: String) -> Fight? { allFights.first { $0.id == id } }

    var upcomingFights: [Fight] { FightRepository.upcoming(allFights) }
    var myUpcomingFights: [Fight] { FightRepository.signedUp(allFights, in: userState) }
    var pastFights: [Fight] { FightRepository.attended(allFights, in: userState) }
    var nextFight: Fight? { myUpcomingFights.first }
    var hostedFights: [Fight] { FightRepository.hostedFights(in: userState) }

    var isOrganization: Bool { userState.isOrganization }
    var orgName: String { userState.orgName.isEmpty ? displayName : userState.orgName }
    var displayName: String {
        userState.displayName.isEmpty ? MockUserStateData.demoDisplayName : userState.displayName
    }
    var firstName: String { displayName.split(separator: " ").first.map(String.init) ?? displayName }

    func isSignedUp(_ fight: Fight) -> Bool { FightRepository.isSignedUp(fight.id, in: userState) }
    func hasAttended(_ fight: Fight) -> Bool { FightRepository.hasAttended(fight.id, in: userState) }
    func signup(for fight: Fight) -> FightSignup? { FightRepository.signup(for: fight.id, in: userState) }
    func isHost(of fight: Fight) -> Bool { FightRepository.isHost(of: fight, in: userState) }
    func scans(for fight: Fight) -> [HostScan] { FightRepository.scans(for: fight.id, in: userState) }
    func signupCount(for fight: Fight) -> Int { isSignedUp(fight) ? 1 : 0 }

    func joinFight(_ fight: Fight) async {
        let result = await mutateUser { FightRepository.signUp(for: fight, in: &$0) }
        switch result {
        case .signedUp: toast = Toast(kind: .success, message: "You're in — see you at \(fight.locationName).")
        case .alreadySignedUp: toast = Toast(kind: .info, message: "You're already signed up.")
        case .eventFinished: toast = Toast(kind: .warning, message: "That Fight has already finished.")
        case .eventCancelled: toast = Toast(kind: .warning, message: "The host cancelled this Fight.")
        }
    }

    func cancelFight(_ fight: Fight) async {
        let ok = await mutateUser { FightRepository.cancelSignup(for: fight.id, in: &$0) }
        if ok { toast = Toast(kind: .info, message: "Signup cancelled. No penalty.") }
    }

    @discardableResult
    func checkIn(to fight: Fight) async -> FightRepository.CheckInResult {
        let result = await mutateUser { FightRepository.checkIn(to: fight, in: &$0) }
        switch result {
        case .checkedIn(let points, let capped):
            toast = Toast(kind: .success, message: capped
                ? "Checked in — monthly event cap reached."
                : "Checked in · +\(points) pts")
        case .notSignedUp: toast = Toast(kind: .warning, message: "Sign up before checking in.")
        case .alreadyCheckedIn: toast = Toast(kind: .info, message: "Already checked in.")
        case .windowClosed: toast = Toast(kind: .warning, message: "Check-in opens an hour before the start.")
        case .eventCancelled: toast = Toast(kind: .warning, message: "The host cancelled this Fight.")
        }
        return result
    }

    func newDraft(type: FightType = .beachCleanup) -> Fight {
        let start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return Fight(
            id: "host-\(UUID().uuidString.prefix(8))",
            title: "", summary: "", type: type,
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
        if ok { toast = Toast(kind: .info, message: "Cancelled. Anyone signed up still sees it.") }
    }

    @discardableResult
    func recordScan(_ raw: String, for fight: Fight) async -> FightRepository.ScanResult {
        let ownCode = FightRepository.signup(for: fight.id, in: userState)?.checkInToken == raw
        let result = await mutateUser { FightRepository.recordScan(raw, for: fight, in: &$0) }
        // Single-device demo path (§12.1): scanning your own code also credits you.
        if case .accepted = result, ownCode { await checkIn(to: fight) }
        return result
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

    func resetEverything() async {
        let fresh = UserState(userId: userId)
        try? await userStateRepository.save(fresh)
        userState = fresh
        completedTodayIDs = []
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
