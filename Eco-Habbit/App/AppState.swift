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

    /// The signed-in account, or `nil`. **This is what "logged in" means now** — there
    /// is no separate flag to disagree with it.
    ///
    /// Storage is keyed on it, and every Firestore path will be built from it, so it is
    /// deliberately the one thing that decides which data the app is looking at.
    @Published private(set) var userId: String?

    /// The id storage is currently keyed on. Signed out still persists — to a reserved
    /// id — so there is only one read/write path rather than two.
    private var storageId: String { userId ?? PersistenceStore.signedOutUserId }

    /// Remote copy of `/users/{uid}`, or `nil` on a device that is local-only.
    ///
    /// Optional rather than a boolean flag so the offline build has nothing to inject —
    /// which is what lets the economy checks and every `#Preview` run without Firebase.
    private let sync: UserStateSyncing?

    /// Whether this session has reconciled with the server yet.
    ///
    /// **Nothing is written to Firestore while this is false**, and that is the whole
    /// point. Deleting and reinstalling the app removes the local file but *not* the
    /// sign-in — Firebase keeps its token in the keychain, which survives deletion — so
    /// the app comes back already signed in with a blank `data`. `evaluateIfNeeded` and
    /// `backfillGlobeStageAnnouncement` both mutate, `mutate` echoes to Firestore, and
    /// the blank state therefore overwrote the real one *before* the pull that was
    /// meant to restore it had even read it. Streak, points and Earth came back as
    /// zero, on the server as well as on the phone.
    ///
    /// `merge: true` is no defence: `UserDocument` carries every scalar, so a blank
    /// document merges `currentPoints: 0` straight over the real total.
    private var remoteResolved = false

    /// Whether this device already had a file for this account when it signed in.
    ///
    /// Decides which side wins for the scalars. See `pullRemoteState`.
    private var hasLocalCopy = false

    /// What the remote layer is actually doing.
    ///
    /// Every call into Firestore is `try?` or an empty catch, deliberately — a sync
    /// problem must never interrupt someone logging an action. The cost is that when
    /// sync stops working there is nothing on screen, in the logs, or anywhere else to
    /// say so, and "signed in but nothing saves" looks identical to "working". This is
    /// where that goes. Shown in the debug menu.
    enum SyncStatus: Equatable {
        /// No sync injected — previews, the checks, the offline demo build.
        case localOnly
        /// Signed in, not yet reconciled with the server.
        case pending
        case synced
        case failed(String)

        var label: String {
            switch self {
            case .localOnly: "Local only (no Firebase)"
            case .pending:   "Not reconciled yet"
            case .synced:    "Synced"
            case .failed:    "FAILED"
            }
        }

        var detail: String? {
            if case .failed(let message) = self { return message }
            return nil
        }
    }

    @Published private(set) var syncStatus: SyncStatus = .pending

    init(userId: String? = nil,
         data: PersistedState? = nil,
         sync: UserStateSyncing? = nil) {
        self.userId = userId
        self.sync = sync
        let stored = PersistenceStore.load(userId: userId ?? PersistenceStore.signedOutUserId)
        self.hasLocalCopy = stored != nil
        self.data = data ?? stored ?? PersistedState()
        evaluateIfNeeded()
        backfillGlobeStageAnnouncement()
    }

    /// Switch to a signed-in account and load its state.
    ///
    /// Called by the auth listener, which is the only writer — setting this from the
    /// sign-in button *as well* gives two sources of truth that drift apart.
    func signedIn(uid: String, displayName: String? = nil) {
        guard userId != uid else { return }

        // Closed until `pullRemoteState` has run. Everything below this line mutates,
        // and on a reinstall `data` is blank — see `remoteResolved`.
        remoteResolved = false
        syncStatus = .pending

        userId = uid
        let stored = PersistenceStore.load(userId: uid)
        hasLocalCopy = stored != nil
        data = stored ?? PersistedState()

        // Apple hands over the name on the FIRST EVER sign-in for an Apple ID and never
        // again, not even after a reinstall. If it is not captured here it is gone.
        if let displayName, !displayName.isEmpty, data.userName.isEmpty {
            mutate { $0.userName = displayName }
        }

        evaluateIfNeeded()
        backfillGlobeStageAnnouncement()
        selectedTab = .home

        Task { await pullRemoteState(uid: uid) }
    }

    /// Reconcile with the account's server-side state, then open the gate on writes.
    ///
    /// **The scalars — points, streak, Earth — are restored from the server only when
    /// this device has no file of its own.** That one condition is what separates the
    /// two cases, and they want opposite answers:
    ///
    /// - *Reinstalled, or a second device.* No local file. The server holds the only
    ///   copy and must win, or the account starts from zero.
    /// - *Used offline, now back on wifi.* A local file exists and is **ahead** of the
    ///   server. Applying the server here would roll the user backwards and then push
    ///   the rolled-back numbers up, making the loss permanent.
    ///
    /// Taking "remote always wins" got the first case right and the second one exactly
    /// wrong. The local file is the working copy; Firestore is its backup, restored when
    /// there is nothing to restore *to*.
    ///
    /// History is the exception and is always **merged both ways** — logs and badges are
    /// immutable facts, so a union loses nothing regardless of which side is ahead.
    ///
    /// Silent on failure by design. No network means no sync, not a broken app; the
    /// local file is the working copy either way. `remoteResolved` stays false, so the
    /// session simply stays local and reconciles on the next launch instead of writing
    /// something it could not verify.
    private func pullRemoteState(uid: String) async {
        guard let sync else { syncStatus = .localOnly; return }
        do {
            var next = data
            if let remote = try await sync.fetch(userId: uid) {
                if !hasLocalCopy { remote.apply(to: &next) }

                // `isOrganization` is the one field the SERVER owns, so it is copied
                // down unconditionally — outside the `hasLocalCopy` gate, because a
                // device that already has a file is exactly the one being promoted.
                //
                // It is not a nicety. The push sends every scalar, and the rules require
                // `isOrganization` to arrive equal to what is stored. Leave the local
                // copy at `false` after an admin sets it `true` and the two disagree
                // forever: EVERY user-document write is refused from then on, silently,
                // taking points, streak and name with it. Reading it down is what keeps
                // the client agreeing with the server about a value it may not author.
                next.isOrganization = remote.isOrganization
            } else {
                // Brand-new account: the local state becomes the server's first copy.
                try await sync.push(UserDocument(next), userId: uid)
            }

            // History is **merged, not replaced**. A log or badge that exists only on
            // this device — earned offline, or before the account had a server copy —
            // must survive coming back. Keyed by remote id and badgeId, so the same
            // entry arriving from both sides collapses to one.
            let remoteLogs = try await sync.fetchLogs(userId: uid)
            let remoteLogIds = Set(remoteLogs.map(\.remoteId))
            var logsById = Dictionary(next.logs.map { ($0.remoteId, $0) },
                                      uniquingKeysWith: { first, _ in first })
            let localOnlyLogs = logsById.values.filter { !remoteLogIds.contains($0.remoteId) }
            for log in remoteLogs where logsById[log.remoteId] == nil {
                logsById[log.remoteId] = log
            }
            next.logs = logsById.values.sorted { $0.loggedAt > $1.loggedAt }

            let remoteBadges = try await sync.fetchBadges(userId: uid)
            let remoteBadgeIds = Set(remoteBadges.map(\.badgeId))
            var badgesById = Dictionary(next.earnedBadges.map { ($0.badgeId, $0) },
                                        uniquingKeysWith: { first, _ in first })
            let localOnlyBadges = badgesById.values.filter { !remoteBadgeIds.contains($0.badgeId) }
            for badge in remoteBadges where badgesById[badge.badgeId] == nil {
                badgesById[badge.badgeId] = badge
            }
            next.earnedBadges = badgesById.values.sorted { $0.earnedAt < $1.earnedAt }

            data = next
            PersistenceStore.save(next, userId: uid)

            // The two sides are now reconciled, so writes are safe. Opened BEFORE the
            // evaluation below, deliberately: whatever that scores is based on the
            // restored state and belongs on the server. Anything that mutated earlier
            // in the launch was based on a state that had not been reconciled yet, and
            // was correctly withheld.
            remoteResolved = true
            hasLocalCopy = true
            syncStatus = .synced

            evaluateIfNeeded()
            backfillGlobeStageAnnouncement()

            // What the evaluation just decided is not covered by the filtered pushes
            // below — those only carry history. Send the scalars too.
            pushRemoteState(data)

            // Push **only what the server does not already have**, so the two sides
            // agree after the first sign-in rather than diverging quietly.
            //
            // Filtering matters more than it looks. Both subcollections are
            // `allow update: if false` — a log is immutable once written — so
            // re-sending a document that already exists is rejected, and a Firestore
            // batch is all-or-nothing: one rejected write takes every genuinely new
            // one in the same batch down with it. Sending the merged list would mean
            // that on any account with server history, nothing local ever uploads.
            try await sync.pushLogs(localOnlyLogs, userId: uid)
            try await sync.pushBadges(localOnlyBadges, userId: uid)
        } catch {
            syncStatus = .failed(String(describing: error))

            // **A failed pull must not lock the session out of syncing.** It did: the
            // gate opened only at the end of the `do`, so one refused read — old rules
            // deployed, Firestore not reachable, anything — left `remoteResolved` false
            // and every write suppressed for the whole session. Silently, and sign-in
            // still worked, because Auth does not touch Firestore. The app looked fine
            // and saved nothing.
            //
            // The gate exists to stop a BLANK local state being pushed over good server
            // data on a reinstall, and that danger only exists when this device has no
            // file. With a real local file the data is genuine and is safe to send, so
            // open the gate; without one, stay shut and retry.
            remoteResolved = hasLocalCopy

            // No toast. Surfacing this on every launch without wifi would train people
            // to ignore it — `syncStatus` in the debug menu is where it belongs.
        }
    }

    /// Re-attempt a pull that failed. Called when the app returns to the foreground, so
    /// a launch with no signal reconciles as soon as there is one rather than waiting
    /// for the next cold start.
    func retrySyncIfNeeded() {
        guard sync != nil, let userId, syncStatus != .synced else { return }
        Task { await pullRemoteState(uid: userId) }
    }

    /// Drop back to the signed-out local account.
    func signedOut() {
        guard userId != nil else { return }
        userId = nil
        // Belt and braces — `pushRemoteState` already refuses without a `userId` — but
        // leaving it open would mean the next sign-in could write before its own pull.
        remoteResolved = false
        let stored = PersistenceStore.load(userId: PersistenceStore.signedOutUserId)
        hasLocalCopy = stored != nil
        data = stored ?? PersistedState()
        selectedTab = .home
    }

    /// An account from before stage-up animations existed has already "seen" the globe it
    /// has, so start it level instead of replaying every transition it earned offline.
    private func backfillGlobeStageAnnouncement() {
        guard data.announcedGlobeStage == nil else { return }
        let current = globeStage
        mutate { $0.announcedGlobeStage = current }
    }

    /// Run at launch and on foreground. Idempotent, so calling it freely is safe.
    func evaluateIfNeeded() {
        mutate { EvaluationLoop.evaluate(state: &$0, habits: MockData.habits, today: today) }
    }

    var today: String { Day.today() }

    // MARK: - Account

    /// Derived from `userId`, not from a stored flag.
    ///
    /// `PersistedState.isLoggedIn` still exists so old save files decode, but nothing
    /// reads it any more: a persisted boolean and a live Firebase session are two
    /// sources of truth, and they drift the moment a token expires.
    var isLoggedIn: Bool { userId != nil }
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

    // MARK: - Globe (Mark's stage art and transitions)

    /// Which globe illustration to show, 0…5.
    ///
    /// **Was a prototype** — `totalActionsLogged / 2`, marked "awaiting globe
    /// points". These are those points. `EarthStage` has exactly the six stages
    /// the artwork was drawn for, so the stage the economy computes *is* the
    /// stage the globe renders, and the two can no longer disagree.
    var globeStage: Int { min(stage.rawValue, GlobeView.lastStage) }

    /// The next unlock animation owed to the user, one stage at a time: crossing
    /// two thresholds at once plays 0→1 first, then 1→2 once that is dismissed.
    var pendingGlobeStageUp: GlobeStageUp? {
        let announced = min(max(data.announcedGlobeStage ?? 0, 0), GlobeView.lastStage)
        guard globeStage > announced else { return nil }
        return GlobeStageUp(from: announced, to: announced + 1)
    }

    func acknowledgeGlobeStageUp(_ stageUp: GlobeStageUp) {
        mutate { $0.announcedGlobeStage = max($0.announcedGlobeStage ?? 0, stageUp.to) }
    }
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

    /// What logging this habit would pay **right now** — the streak multiplier
    /// and whatever is left of today's cap already applied.
    ///
    /// Priced through the same service that does the real awarding, so the
    /// number on a chip cannot drift from the number the user then receives.
    func projectedPoints(for habit: Habit, hasEvidence: Bool = false) -> PointsBreakdown {
        PointsCalculationService().breakdown(
            habit: habit,
            hasEvidence: hasEvidence,
            currentStreak: displayStreak,
            isPrioritized: false,
            basePointsUsedToday: HabitRepository.basePointsUsed(on: today, in: data)
        )
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
        case .logged(let points, _):
            lastAward = Award(habit: habit, points: points)
            // Awarded here, after the log has landed, so the counters the
            // criteria read are already up to date. Deliberately runs at the cap too:
            // the action happened, so it counts towards every badge that counts
            // actions, even on a day that has stopped paying points.
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
        // At the cap the log still lands — it is a real action and still counts for the
        // streak, badges and history — but saying "+0 pts" reads as a broken app. Say
        // what actually happened instead.
        case .logged(_, atDailyCap: true):
            toast = Toast(kind: .info, message: "\(habit.name) · logged — daily points cap reached")
        case .logged(let points, _):
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
        // Read the log BEFORE unlogging — afterwards there is nothing to derive the
        // photo's name from, and it would sit on disk belonging to nothing.
        let evidenceId = log(for: habitId)?.remoteId
        var ok = false
        mutate {
            ok = HabitRepository.unlog(habitId, on: today, today: today, habits: MockData.habits, in: &$0)
        }
        if ok, let evidenceId {
            EvidenceStore.delete(forLogId: evidenceId, userId: storageId)
        }
        return ok
    }

    // MARK: - Evidence photos (local only)

    /// Keep the photo that produced a log.
    ///
    /// Called after the log lands, because the filename is the log's own `remoteId` —
    /// there is nothing to name the file after until it exists. Silent on failure by
    /// design: a photo that cannot be written must never cost somebody their points.
    func saveEvidence(_ image: UIImage, for habitId: String) {
        guard let log = log(for: habitId) else { return }
        EvidenceStore.save(image, forLogId: log.remoteId, userId: storageId)
    }

    func evidence(for log: HabitLog) -> UIImage? {
        EvidenceStore.image(forLogId: log.remoteId, userId: storageId)
    }

    var savedEvidence: [EvidenceStore.Saved] { EvidenceStore.all(userId: storageId) }
    var savedEvidenceBytes: Int { EvidenceStore.totalBytes(userId: storageId) }

    func deleteEvidence(id: String) { EvidenceStore.delete(forLogId: id, userId: storageId) }
    func purgeEvidence() { EvidenceStore.purge(userId: storageId) }

    // MARK: - Fights (PRD §4)

    /// Seeded events plus anything this account hosts. Everything that browses
    /// or looks a Fight up goes through here, so a hosted event behaves exactly
    /// like a bundled one.
    /// Published Fights from the server. Empty until `refreshFights` returns, and empty
    /// forever on a local-only build — which is why it is additive rather than a
    /// replacement for the bundled seeds.
    @Published private(set) var remoteFights: [Fight] = []

    /// Bundled seeds, this device's own hosted events, and everybody else's published
    /// ones.
    ///
    /// **Local wins on a tie.** A host's own Fight exists in both `hostedFights` and,
    /// once published, in `remoteFights`; taking the local copy means an edit shows
    /// immediately instead of after the next fetch. The seeds stay because they are what
    /// the app has to show with no network and no organiser.
    var allFights: [Fight] {
        let local = MockData.fights + data.hostedFights
        let known = Set(local.map(\.id))
        return local + remoteFights.filter { !known.contains($0.id) }
    }

    /// Pull the shared list. Silent on failure — no network means the bundled seeds and
    /// your own events, not an error screen.
    func refreshFights() async {
        guard let sync else { return }
        if let fights = try? await sync.fetchPublishedFights() { remoteFights = fights }
    }

    func fight(id: String) -> Fight? { allFights.first { $0.id == id } }

    var upcomingFights: [Fight] { FightRepository.upcoming(allFights) }
    var myUpcomingFights: [Fight] { FightRepository.signedUp(allFights, in: data) }
    var pastFights: [Fight] { FightRepository.attended(allFights, in: data) }

    /// The dashboard's "Next Fight" card (§6.1).
    var nextFight: Fight? { myUpcomingFights.first }

    // MARK: - Saved Fights
    //
    // Replaces signup. A save is a private bookmark: the host is never told, so there
    // is no promise to break and no cross-user write to authorise. Attending is decided
    // on the day, by presenting the organiser's code.

    func isFavourite(_ fight: Fight) -> Bool { data.favouriteFightIds.contains(fight.id) }

    func toggleFavourite(_ fight: Fight) {
        let saving = !isFavourite(fight)
        mutate {
            if saving { $0.favouriteFightIds.insert(fight.id) }
            else { $0.favouriteFightIds.remove(fight.id) }
        }
        toast = Toast(kind: .info, message: saving ? "Saved to your Fights." : "Removed from your Fights.")
    }

    /// Every Fight worth showing, soonest first, with anything already over dropped.
    var browsableFights: [Fight] {
        allFights
            .filter { $0.status == .published }
            .sorted { $0.startsAt < $1.startsAt }
    }

    var favouriteFights: [Fight] { browsableFights.filter(isFavourite) }

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
    /// The Fight owning a scanned code, if any.
    func fight(matchingCode code: String) -> Fight? {
        FightRepository.fight(matchingCode: code, in: allFights)
    }

    /// Check in from a scanned QR. The code identifies the Fight, so the scanner
    /// never has to know which event it is pointed at.
    ///
    /// Returns `nil` when no Fight owns the code — a well-formed
    /// `ecohabit://fight/` payload for an event this device has never heard of.
    /// Silent on purpose at the call site; the camera decides what to say.
    @discardableResult
    func checkIn(withCode code: String) -> FightRepository.CheckInResult? {
        guard let fight = fight(matchingCode: code) else { return nil }
        return checkIn(to: fight, code: code)
    }

    func checkIn(to fight: Fight, code: String? = nil) -> FightRepository.CheckInResult {
        var result = FightRepository.CheckInResult.notSignedUp
        mutate {
            result = FightRepository.checkIn(to: fight, code: code, userId: userId ?? "",
                                             in: &$0, now: Date())
        }

        switch result {
        case .checkedIn(let points):
            awardNewBadges()
            toast = Toast(kind: .success, message: "Checked in — +\(points) pts.")
            // Fire and forget, unlike publishing. The points are already credited
            // locally and the local record is what the app reads; the server copy is
            // what lets the host see a roster. A failed write costs the attendee
            // nothing, so it must not block the reward.
            if let sync, let attendance = data.fightAttendance[fight.id] {
                Task { try? await sync.checkIn(attendance) }
            }
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

    /// Whether the host surfaces are available.
    ///
    /// `data.isOrganization` is the **server's** answer and the only one the security
    /// rules respect. The debug override sits beside it rather than inside it, which
    /// fixes two things at once: the toggle used to write `data.isOrganization`, so
    /// `pullRemoteState` — which copies that field down unconditionally — reset it to
    /// `false` on the very next launch, and the local/server disagreement in between got
    /// every user-document write refused.
    var isOrganization: Bool {
        #if DEBUG
        if debugOrgOverride { return true }
        #endif
        return data.isOrganization
    }

    #if DEBUG
    /// Local-only, survives relaunch, never pushed and never overwritten by a fetch.
    @Published private var debugOrgOverride = UserDefaults.standard.bool(forKey: debugOrgKey)
    fileprivate static let debugOrgKey = "EHDebugForceOrganisation"
    #endif
    var orgName: String { data.orgName.isEmpty ? userName : data.orgName }
    var hostedFights: [Fight] { FightRepository.hostedFights(in: data) }

    /// Who actually turned up, from the server.
    ///
    /// **Not from `hostScans`.** That was the old model, where the host scanned each
    /// attendee's personal QR — a cross-user write that needed a server to authorise.
    /// What shipped is the inverse: one code per Fight, and each attendee's own device
    /// writes its own `/attendance` record. The host reads that list rather than
    /// building one.
    ///
    /// No names. The rules deliberately keep `/users` private, so a host can see that
    /// somebody checked in and when, but not who they are.
    func attendees(for fight: Fight) async -> [FightAttendance] {
        guard let sync else { return [] }
        let records = (try? await sync.fetchAttendance(fightId: fight.id)) ?? []
        return records.sorted { $0.checkedInAt < $1.checkedInAt }
    }

    /// Reads `isOrganization` here rather than `FightRepository.isHost`, which sees only
    /// `PersistedState` and so cannot know about the debug override — without this, a
    /// forced organisation's own Fight offered "Scan or check in" instead of the code.
    func isHost(of fight: Fight) -> Bool {
        isOrganization && data.hostedFights.contains { $0.id == fight.id }
    }
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
            // The real uid, not a placeholder: the rules require
            // `hostId == request.auth.uid`, so "local-host" would be refused on publish.
            hostName: orgName, hostId: userId ?? "local-host",
            locationName: "", address: "",
            latitude: nil, longitude: nil,
            startsAt: start, endsAt: start.addingTimeInterval(3 * 3600),
            preparationNotes: [], status: .draft, isDemo: false
        )
    }

    /// Save an edit. **Pushes when the Fight is already live.**
    ///
    /// `ManageEventView` offers "Edit details" after publishing, and without this the
    /// server copy silently kept the old title, time and place while the host looked at
    /// the corrected version on their own screen — and was told it had been "saved as a
    /// draft", which it had not.
    ///
    /// Fire-and-forget, unlike the initial publish. The event is already visible, so a
    /// failed edit degrades to one stale field rather than an event nobody can see.
    func saveDraft(_ fight: Fight) {
        mutate {
            if $0.hostedFights.contains(where: { $0.id == fight.id }) {
                FightRepository.update(fight, in: &$0)
            } else {
                FightRepository.createDraft(fight, in: &$0)
            }
        }

        guard let stored = hostedFights.first(where: { $0.id == fight.id }),
              stored.status == .published, let sync
        else {
            toast = Toast(kind: .success, message: "Saved as a draft.")
            return
        }

        Task { try? await sync.putFight(stored); await refreshFights() }
        toast = Toast(kind: .success, message: "Saved — everyone sees the change.")
    }

    /// Publish, then push. **Awaited, unlike every other sync in the app.**
    ///
    /// Publishing is the one action whose whole purpose is that somebody else sees it,
    /// so "it saved locally and the upload may or may not have happened" is not an
    /// outcome worth reporting as success. If the write is refused the local state is
    /// rolled back to draft, because a Fight the host believes is live but which nobody
    /// can see is the worst of the three possible states.
    ///
    /// The likely refusal is `isOrganization` — the rules only let a verified
    /// organisation create a Fight, and that flag is admin-set on the server. The
    /// message says so rather than reporting a permissions error nobody can act on.
    func publishFight(_ fight: Fight) async {
        var ok = false
        mutate { ok = FightRepository.publish(fight.id, in: &$0) }
        guard ok else {
            toast = Toast(kind: .info, message: "Already published.")
            return
        }

        guard let sync, let published = hostedFights.first(where: { $0.id == fight.id }) else {
            toast = Toast(kind: .success, message: "Published — it's in the public list now.")
            return
        }

        do {
            try await sync.putFight(published)
            await refreshFights()
            toast = Toast(kind: .success, message: "Published — everyone can see it now.")
        } catch {
            mutate { _ = FightRepository.unpublish(fight.id, in: &$0) }
            toast = Toast(kind: .warning,
                          message: "Couldn't publish. This account isn't verified as an organisation yet.")
        }
    }

    func cancelHostedFight(_ fight: Fight) {
        var ok = false
        mutate { ok = FightRepository.cancel(fight.id, in: &$0) }
        guard ok else { return }
        toast = Toast(kind: .info, message: "Cancelled. Anyone who saved it still sees it.")

        // Cancelling is a status change, not a delete — the rules refuse deletes, and
        // people who saved it need to be told rather than have it vanish.
        if let sync, let cancelled = hostedFights.first(where: { $0.id == fight.id }) {
            Task { try? await sync.putFight(cancelled); await refreshFights() }
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

    /// Rename the account.
    ///
    /// Worth having beyond vanity: Apple hands over a name only on the **first ever**
    /// sign-in for an Apple ID and never again, so anyone who signed in before the app
    /// captured it — or who chose to hide it — is stuck being greeted as "there" with no
    /// way to fix it.
    ///
    /// Empty is refused rather than stored: `userName` falls back to "there" when blank,
    /// and letting someone save nothing would look like the rename silently failed.
    func setUserName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != data.userName else { return }
        mutate { $0.userName = trimmed }
        toast = Toast(kind: .success, message: "Name updated.")
    }

    /// Sign out of Firebase. The auth listener notices and calls `signedOut()`, which is
    /// what actually clears the session — one writer, not two.
    func logOut() {
        AppleSignInService.signOut()
        // Belt and braces for the DEBUG launch-argument path, which never had a
        // Firebase session for the listener to react to.
        if userId != nil { signedOut() }
        selectedTab = .home
    }

    func resetEverything() {
        PersistenceStore.wipe(userId: storageId)
        // Photos are keyed on {habitId}_{localDate}, so leaving them would attach an old
        // picture to the first log of that habit after the reset.
        EvidenceStore.purge(userId: storageId)
        data = PersistedState()
        selectedTab = .home
        evaluateIfNeeded()
        // The remote copy is rewritten from the now-empty state rather than left
        // behind, or the next launch would pull the old numbers straight back.
        //
        // The subcollections need the same treatment, and for a sharper reason: a
        // reset that leaves the logs on the server is not a reset at all, because
        // `pullRemoteState` MERGES history rather than replacing it — every log and
        // badge would come back on the next sign-in.
        //
        // Purged wholesale rather than diffed. `syncSubcollections` only ever
        // deletes logs, since nothing in normal use un-earns a badge, and a reset
        // that clears the history but leaves the trophies is not what the button
        // says it does.
        //
        // Both flags are asserted rather than read: a reset is an explicit statement
        // that the local (now empty) state is the truth, so writes are open and no
        // later pull may restore over it. Residual race: a reset fired while the
        // launch pull is still in flight can be overwritten by it, and the fix is to
        // press it again. Not worth a generation token for a debug-menu action.
        remoteResolved = true
        hasLocalCopy = true
        pushRemoteState(data)
        if let sync, let userId {
            Task { try? await sync.purgeSubcollections(userId: userId) }
        }
        toast = Toast(kind: .info, message: "Local data cleared.")
    }

    /// Delete the account: server data, then the sign-in itself.
    ///
    /// **App Review requires this** for any app with sign-in — "reset my data" is not a
    /// substitute for "delete my account". Distinct from `resetEverything`, which starts
    /// the Earth over but keeps you signed in.
    ///
    /// Firestore documents go first. Deleting the auth user revokes the token, and
    /// without it the security rules would refuse every subsequent delete — leaving the
    /// data behind forever with nobody able to reach it.
    func deleteAccount() async {
        guard let userId else { return }
        do {
            try await sync?.deleteAccount(userId: userId)
            try await AppleSignInService.deleteCurrentUser()
            PersistenceStore.wipe(userId: userId)
            EvidenceStore.purge(userId: userId)
            signedOut()
            toast = Toast(kind: .info, message: "Account deleted.")
        } catch {
            // `requiresRecentLogin` is the common one: Apple wants a fresh sign-in
            // before it will let an account be destroyed.
            toast = Toast(kind: .warning,
                          message: "Couldn't delete the account. Sign out, sign in again, then retry.")
        }
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
    ///
    /// **This unlocks the host UI locally; it does not make publishing work.** The
    /// rules read `isOrganization` from the server, so a Fight published on the
    /// strength of this flag alone is refused and rolled back. It also disagrees with
    /// the stored value until the next launch, which means user-document writes are
    /// refused in the meantime. The real switch is the field on `/users/{uid}` in the
    /// Firebase console; this is for demoing host mode with no network.
    func debugSetOrganization(_ on: Bool, name: String = "Ombak Bersih") {
        // Deliberately does NOT touch `data.isOrganization`. That field belongs to the
        // server: writing it locally made the toggle vanish on the next launch, and made
        // every user-document push disagree with what the rules had stored.
        debugOrgOverride = on
        UserDefaults.standard.set(on, forKey: Self.debugOrgKey)
        mutate { $0.orgName = on ? name : "" }
    }
    #endif

    private func mutate(_ change: (inout PersistedState) -> Void) {
        let before = data
        var next = data
        change(&next)
        data = next
        // Disk first, synchronously, exactly as before. The app must not get slower or
        // stop working offline because a remote copy exists.
        PersistenceStore.save(next, userId: storageId)
        pushRemoteState(next)
        syncSubcollections(before: before, after: next)
    }

    /// Mirror added and removed logs and badges to their subcollections.
    ///
    /// Diffed here rather than pushed from the call sites because logging happens in
    /// `HabitRepository`, which is a namespace of pure functions over `PersistedState`
    /// and has no business knowing a network exists. Every path that mutates state
    /// funnels through `mutate`, so diffing here catches all of them — including the
    /// same-day undo and the reset — with nothing to remember to wire up later.
    private func syncSubcollections(before: PersistedState, after: PersistedState) {
        // `remoteResolved` guards deletes as much as writes: before the pull, `before`
        // is a blank state, so a merge would read every restored log as "added" and —
        // worse — a wipe would read the server's history as "removed" and delete it.
        guard let sync, let userId, remoteResolved else { return }

        let hadLogs = Set(before.logs.map(\.remoteId))
        let hasLogs = Set(after.logs.map(\.remoteId))
        let addedLogs = after.logs.filter { !hadLogs.contains($0.remoteId) }
        let removedLogIds = Array(hadLogs.subtracting(hasLogs))

        let hadBadges = Set(before.earnedBadges.map(\.badgeId))
        let addedBadges = after.earnedBadges.filter { !hadBadges.contains($0.badgeId) }

        guard !addedLogs.isEmpty || !removedLogIds.isEmpty || !addedBadges.isEmpty else { return }

        Task {
            try? await sync.pushLogs(addedLogs, userId: userId)
            try? await sync.deleteLogs(ids: removedLogIds, userId: userId)
            try? await sync.pushBadges(addedBadges, userId: userId)
        }
    }

    /// Echo the new state to `/users/{uid}`. Fire and forget.
    ///
    /// Not awaited anywhere: logging an action must feel instant and must work on a
    /// plane. Firestore's own cache queues the write and replays it when the network
    /// returns, so a missed push is deferred rather than lost.
    private func pushRemoteState(_ state: PersistedState) {
        guard let sync, let userId, remoteResolved else { return }
        let document = UserDocument(state)
        Task { try? await sync.push(document, userId: userId) }
    }
}
