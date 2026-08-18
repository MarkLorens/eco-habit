import SwiftUI
import Combine

/// The shared store. Holds `PersistedState` and exposes it to views, but **owns no
/// business rules** — logging goes to `HabitRepository`, Shields to `UserRepository`,
/// scoring to `EvaluationLoop`. Keeping it a coordinator is what lets three people work
/// in three feature folders without meeting in this file every day (PRD §9.13.2).
@MainActor
final class AppState: ObservableObject {

    @Published private(set) var data: PersistedState

    @Published var selectedTab: AppTab = .home
    // Added for the action tab ya
    @Published var actionsPath = NavigationPath()
    @Published var isCameraPresented = false
    @Published var toast: Toast?
    @Published var lastAward: Award?

    init(data: PersistedState = PersistenceStore.load()) {
        self.data = data
        evaluateIfNeeded()
    }

    /// Run at launch and on foreground. Idempotent, so calling it freely is safe.
    func evaluateIfNeeded() {
        mutate { EvaluationLoop.evaluate(state: &$0, habits: MockData.habits, today: today) }
    }

    var today: String { Day.today() }

    // MARK: - Account

    var isLoggedIn: Bool { data.isLoggedIn }
    var userName: String { data.userName.isEmpty ? "there" : data.userName }
    var firstName: String { userName.split(separator: " ").first.map(String.init) ?? userName }
    var notificationsEnabled: Bool { data.notificationsEnabled }
    var favouriteCategories: Set<HabitCategory> { data.favouriteCategories }

    // MARK: - Earth

    /// Cumulative Earth points — the real total, unbounded.
    var currentPoints: Int { data.currentPoints }

    var stage: EarthStage { config.stage(forPoints: data.currentPoints) }

    /// Kept as a 0–100 reading because that is what the globe and the profile
    /// tile draw. It is now **derived** from points rather than stored: it
    /// reaches 100 exactly when the Earth is Restored, so the two can never
    /// disagree the way a separately-stored level could.
    var vitality: Int {
        let restored = config.threshold(for: .restored)
        guard restored > 0 else { return 0 }
        return min(100, data.currentPoints * 100 / restored)
    }

    var globeHealth: Double { Double(vitality) }
    var level: Int { stage.rawValue + 1 }

    var levelTitle: String {
        switch stage {
        case .critical: return "Seedling"
        case .fragile: return "Sprout"
        case .stabilizing: return "Grower"
        case .recovering: return "Caretaker"
        case .flourishing: return "Eco Guardian"
        case .restored: return "Planet Keeper"
        }
    }

    /// How far through the current stage, for the ring. Measured in points now,
    /// against the next stage's threshold.
    var stageProgress: Double {
        guard let next = stage.next else { return 1 }
        let floor = config.threshold(for: stage)
        let span = config.threshold(for: next) - floor
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(data.currentPoints - floor) / Double(span)))
    }

    private var config: PointsConfiguration { .default }

    /// PRD §9.5 — `streakDays` is a *settled* value that stops at yesterday, so today's
    /// target has to be added back in for display. Without this a user who just hit their
    /// target sees the number stall until midnight and concludes it's broken.
    /// The stored streak is only true as of the last day something was logged.
    /// After two missed days with no Shield it is stale, and showing it would be
    /// a lie — so the number on screen is recomputed against today.
    var displayStreak: Int {
        HabitRepository.displayStreak(on: today, in: data)
    }

    var streakDays: Int { displayStreak }

    // MARK: - Today

    var todaysLogs: [HabitLog] { HabitRepository.logs(on: today, in: data) }

    var dailyPoints: Int { HabitRepository.dailyTotal(on: today, in: data) }

    var dailyProgress: Double {
        min(1, Double(dailyPoints) / Double(PointsEngine.dailyTarget))
    }

    /// Where today sits against the 60 ceiling, for the second ring in §6.1.
    var dailyCapProgress: Double {
        min(1, Double(dailyPoints) / Double(PointsEngine.dailyCap))
    }

    func log(for habitId: String) -> HabitLog? {
        todaysLogs.first { $0.habitId == habitId }
    }

    func isCompletedToday(_ habitId: String) -> Bool { log(for: habitId) != nil }

    func isAvailable(_ habit: Habit) -> Bool {
        HabitRepository.isAvailable(habit, on: today, in: data)
    }

    func rows(in category: HabitCategory) -> [HabitRow] {
        MockData.habits(in: category).map { HabitRow(habit: $0, log: log(for: $0.id)) }
    }

    func doneCount(in category: HabitCategory) -> Int {
        rows(in: category).filter(\.isCompletedToday).count
    }

    /// Up to three things worth doing today: still available, favourites first.
    var suggestedHabits: [Habit] {
        let pending = MockData.habits.filter { isAvailable($0) }
        let favourites = pending.filter { data.favouriteCategories.contains($0.category) }
        let rest = pending.filter { !data.favouriteCategories.contains($0.category) }
        return Array((favourites + rest).prefix(3))
    }

    // MARK: - History and badges (all derived — nothing summable is stored)

    var history: [HistoryEntry] {
        data.logs
            .compactMap { log in
                MockData.habitsById[log.habitId].map { HistoryEntry(log: log, habit: $0) }
            }
            .sorted { $0.date > $1.date }
    }

    var totalActionsLogged: Int { data.logs.count }

    func actionCount(in category: HabitCategory) -> Int {
        data.logs.filter { MockData.habitsById[$0.habitId]?.category == category }.count
    }

    /// The catalogue joined with this account's awards.
    var badges: [Badge] { badgeService.display(catalogue: MockData.badges, earned: data.earnedBadges) }

    /// **Reads the award record, not live criteria.** Earned is permanent: decay
    /// can take the points back without taking the badge, which is what the spec
    /// says and what anybody who earned it would expect.
    func isUnlocked(_ badge: Badge) -> Bool {
        data.earnedBadges.contains { $0.badgeId == badge.id }
    }

    /// How close an unearned badge is, 0–1.
    func progress(towards badge: Badge) -> Double {
        badgeService.progress(for: badge, state: data, today: today)
    }

    /// Awards anything newly reached. Called after every log and check-in.
    private func awardNewBadges() {
        mutate { state in
            let already = Set(state.earnedBadges.map(\.badgeId))
            let fresh = badgeService.newlyEarned(from: MockData.badges,
                                                 state: state,
                                                 alreadyEarned: already,
                                                 today: Day.today())
            state.earnedBadges.append(contentsOf: fresh)
        }
    }

    private let badgeService = BadgeEvaluationService()
    
    var pendingBadge: Badge? {
        MockData.badges.first{ isUnlocked($0) && !data.announcedBadgeIds.contains($0.id) }
    }
    
    func acknowledgeBadge(_ badge: Badge){
        mutate { $0.announcedBadgeIds.insert(badge.id) }
    }

    var unlockedBadgeCount: Int { MockData.badges.filter(isUnlocked).count }

    // MARK: - Shields

    var shieldsAvailable: Int { data.shieldsAvailable }
    var isTodayShielded: Bool { UserRepository.isShielded(today, in: data) }

    @discardableResult
    func activateShield() -> Bool {
        var ok = false
        mutate { ok = UserRepository.activateShield(in: &$0, on: today, today: today) }
        toast = ok
            ? Toast(kind: .success, message: "Shielded — today won't cost you.")
            : Toast(kind: .warning, message: "No Shield available for today.")
        return ok
    }

    // MARK: - Logging

    @discardableResult
    func logHabit(_ habit: Habit, source: HabitLog.Source) -> HabitRepository.LogResult {
        var result = HabitRepository.LogResult.retroactive
        mutate {
            result = HabitRepository.log(habit, on: today, today: today, source: source, in: &$0)
        }

        switch result {
        case .logged(let points):
            lastAward = Award(habit: habit, points: points)
            // Awarded here, after the log has landed, so the counters the
            // criteria read are already up to date.
            awardNewBadges()
        case .alreadyLogged, .onCooldown, .retroactive:
            break
        }
        return result
    }

    /// Log and report the outcome. Every logging surface uses this so a weekly cap or a
    /// duplicate reads the same way from the checklist, the dashboard and the camera.
    @discardableResult
    func logAndToast(_ habit: Habit, source: HabitLog.Source) -> HabitRepository.LogResult {
        let result = logHabit(habit, source: source)
        switch result {
        case .logged(let points):
            toast = Toast(kind: .success, message: "\(habit.name) · +\(points) pts")
        case .alreadyLogged:
            toast = Toast(kind: .info, message: "Already logged today — back tomorrow.")
        case .onCooldown(let days):
            toast = Toast(kind: .info, message: days == 1
                ? "Back again tomorrow."
                : "Back again in \(days) days.")
        case .retroactive:
            toast = Toast(kind: .warning, message: "Only today can be logged.")
        }
        return result
    }

    /// Same-day undo (PRD §3.4).
    @discardableResult
    func revertTodaysLog(habitId: String) -> Bool {
        var ok = false
        mutate {
            ok = HabitRepository.unlog(habitId, on: today, today: today, habits: MockData.habits, in: &$0)
        }
        return ok
    }

    // MARK: - Fights (PRD §4)

    /// Seeded events plus anything this account hosts. Everything that browses
    /// or looks a Fight up goes through here, so a hosted event behaves exactly
    /// like a bundled one.
    var allFights: [Fight] { MockData.fights + data.hostedFights }

    func fight(id: String) -> Fight? { allFights.first { $0.id == id } }

    var upcomingFights: [Fight] { FightRepository.upcoming(allFights) }
    var myUpcomingFights: [Fight] { FightRepository.signedUp(allFights, in: data) }
    var pastFights: [Fight] { FightRepository.attended(allFights, in: data) }

    /// The dashboard's "Next Fight" card (§6.1).
    var nextFight: Fight? { myUpcomingFights.first }

    func isSignedUp(_ fight: Fight) -> Bool { FightRepository.isSignedUp(fight.id, in: data) }
    func hasAttended(_ fight: Fight) -> Bool { FightRepository.hasAttended(fight.id, in: data) }
    func signup(for fight: Fight) -> FightSignup? { FightRepository.signup(for: fight.id, in: data) }

    @discardableResult
    func joinFight(_ fight: Fight) -> FightRepository.SignupResult {
        var result = FightRepository.SignupResult.eventFinished
        mutate { result = FightRepository.signUp(for: fight, in: &$0, now: Date()) }

        switch result {
        case .signedUp:
            toast = Toast(kind: .success, message: "You're in — see you at \(fight.locationName).")
        case .alreadySignedUp:
            toast = Toast(kind: .info, message: "You're already signed up.")
        case .eventFinished:
            toast = Toast(kind: .warning, message: "That Fight has already finished.")
        case .eventCancelled:
            toast = Toast(kind: .warning, message: "The host cancelled this Fight.")
        }
        return result
    }

    @discardableResult
    func cancelFight(_ fight: Fight) -> Bool {
        var ok = false
        mutate { ok = FightRepository.cancelSignup(for: fight.id, in: &$0, now: Date()) }
        if ok { toast = Toast(kind: .info, message: "Signup cancelled. No penalty.") }
        return ok
    }

    /// Stands in for the host scanning the attendee's QR. Real cross-device check-in
    /// arrives with Firebase in Phase 10 (§9.3).
    @discardableResult
    func checkIn(to fight: Fight) -> FightRepository.CheckInResult {
        var result = FightRepository.CheckInResult.notSignedUp
        mutate { result = FightRepository.checkIn(to: fight, in: &$0, now: Date()) }

        switch result {
        case .checkedIn(let points):
            awardNewBadges()
            toast = Toast(kind: .success, message: "Checked in — +\(points) pts.")
        case .notSignedUp:
            toast = Toast(kind: .warning, message: "Sign up before checking in.")
        case .alreadyCheckedIn:
            toast = Toast(kind: .info, message: "Already checked in to this Fight.")
        case .windowClosed:
            toast = Toast(kind: .warning, message: "Check-in opens an hour before the start.")
        case .eventCancelled:
            toast = Toast(kind: .warning, message: "The host cancelled this Fight.")
        case .wrongCode:
            toast = Toast(kind: .warning, message: "That code isn't for this Fight.")
        case .notPublished:
            // Distinct from windowClosed on purpose: a draft's window is often
            // wide open, and saying "the window is shut" sends the organiser
            // hunting a clock bug instead of pressing Publish.
            toast = Toast(kind: .info, message: "This Fight isn't published yet.")
        }
        return result
    }

    // MARK: - Host mode (PRD §6.5.1)

    var isOrganization: Bool { data.isOrganization }
    var orgName: String { data.orgName.isEmpty ? userName : data.orgName }
    var hostedFights: [Fight] { FightRepository.hostedFights(in: data) }

    func isHost(of fight: Fight) -> Bool { FightRepository.isHost(of: fight, in: data) }
    func scans(for fight: Fight) -> [HostScan] { FightRepository.scans(for: fight.id, in: data) }

    /// How many local signups exist for a hosted event. Until Phase 10 the only
    /// account on the device is this one, so this is 0 or 1 — the number is
    /// honest, the scale is not.
    func signupCount(for fight: Fight) -> Int {
        FightRepository.isSignedUp(fight.id, in: data) ? 1 : 0
    }

    func newDraft(type: FightType = .beachCleanup) -> Fight {
        let start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return Fight(
            id: "host-\(UUID().uuidString.prefix(8))",
            title: "", summary: "", type: type,
            hostName: orgName, hostId: "local-host",
            locationName: "", address: "",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(3 * 3600),
            preparationNotes: [], status: .draft, isDemo: false
        )
    }

    func saveDraft(_ fight: Fight) {
        mutate {
            if $0.hostedFights.contains(where: { $0.id == fight.id }) {
                FightRepository.update(fight, in: &$0)
            } else {
                FightRepository.createDraft(fight, in: &$0)
            }
        }
        toast = Toast(kind: .success, message: "Saved as a draft.")
    }

    func publishFight(_ fight: Fight) {
        var ok = false
        mutate { ok = FightRepository.publish(fight.id, in: &$0) }
        toast = ok
            ? Toast(kind: .success, message: "Published — it's in the public list now.")
            : Toast(kind: .info, message: "Already published.")
    }

    func cancelHostedFight(_ fight: Fight) {
        var ok = false
        mutate { ok = FightRepository.cancel(fight.id, in: &$0) }
        if ok {
            toast = Toast(kind: .info, message: "Cancelled. Anyone signed up still sees it.")
        }
    }

    /// One scanned QR. Records it on the host roster, and — when the code turns
    /// out to be this device's own signup — also credits the attendee side, so
    /// the whole loop is demonstrable on a single phone (§12.1).
    @discardableResult
    func recordScan(_ raw: String, for fight: Fight) -> FightRepository.ScanResult {
        var result = FightRepository.ScanResult.unreadable
        mutate { result = FightRepository.recordScan(raw, for: fight, in: &$0) }

        if case .accepted = result,
           FightRepository.signup(for: fight.id, in: data)?.checkInToken == raw {
            checkIn(to: fight)
        }
        return result
    }

    // MARK: - Mutations

    func updateFavourites(_ categories: Set<HabitCategory>) {
        mutate { $0.favouriteCategories = categories }
    }

    func setNotifications(_ on: Bool) { mutate { $0.notificationsEnabled = on } }

    func logIn() { mutate { $0.isLoggedIn = true } }

    func logOut() {
        mutate { $0.isLoggedIn = false }
        selectedTab = .home
    }

    func resetEverything() {
        PersistenceStore.wipe()
        data = PersistedState()
        selectedTab = .home
        evaluateIfNeeded()
        toast = Toast(kind: .info, message: "Local data cleared.")
    }

    // MARK: - Debug

    #if DEBUG
    /// Time travel (PRD §13 Phase 2). Runs the real loop against a chosen day.
    func debugEvaluate(asOf day: String) {
        mutate { EvaluationLoop.evaluate(state: &$0, habits: MockData.habits, today: day) }
    }

    /// PRD §4.3 — verification is a human flipping a flag, and there is no admin
    /// surface until Phase 10. DEBUG-only on purpose: `isOrganization` must never
    /// be user-writable, and §9.6 makes that a Security Rules requirement.
    func debugSetOrganization(_ on: Bool, name: String = "Ombak Bersih") {
        mutate {
            $0.isOrganization = on
            $0.orgName = on ? name : ""
        }
    }
    #endif

    private func mutate(_ change: (inout PersistedState) -> Void) {
        var next = data
        change(&next)
        data = next
        PersistenceStore.save(next)
    }
}
