import SwiftUI
import Combine

/// The single shared store. Injected as an `@EnvironmentObject` so every tab reads the
/// same points, streak and completion log — the dedup rule depends on that.
@MainActor
final class AppState: ObservableObject {

    @Published private(set) var data: PersistedState

    /// Transient UI state that shouldn't survive a relaunch.
    @Published var selectedTab: AppTab = .home
    @Published var isCameraPresented = false
    @Published var toast: Toast?
    /// Set when points land, so views can play the reward animation once.
    @Published var lastAward: Award?

    private var saveCancellable: AnyCancellable?
    private let calendar = Calendar.current

    init(data: PersistedState = PersistenceStore.load()) {
        self.data = data
        refreshForToday()
    }

    // MARK: - Derived reads

    var isLoggedIn: Bool { data.isLoggedIn }
    var hasCompletedOnboarding: Bool { data.hasCompletedOnboarding }
    var userName: String { data.userName.isEmpty ? "there" : data.userName }
    var firstName: String { userName.split(separator: " ").first.map(String.init) ?? userName }

    var earthPoints: Int { data.earthPoints }
    var rewardPoints: Int { data.rewardPoints }
    var lifetimeEarthPoints: Int { data.lifetimeEarthPoints }
    var streakDays: Int { data.streakDays }
    var favouriteCategories: Set<ActivityCategory> { data.favouriteCategories }

    var stage: EarthStage { EarthStage.stage(for: data.earthPoints) }
    var globeHealth: Double { PointsEngine.globeHealth(earthPoints: data.earthPoints) }
    var streakMultiplier: Double { PointsEngine.streakMultiplier(streakDays: data.streakDays) }

    /// Progress toward the next Earth stage, 0...1.
    var stageProgress: Double {
        guard let next = stage.next else { return 1 }
        let floorPoints = stage.threshold
        let span = next.threshold - floorPoints
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(data.earthPoints - floorPoints) / Double(span)))
    }

    var level: Int { stage.rawValue + 1 }

    var levelTitle: String {
        switch stage {
        case .critical: return "Seedling"
        case .earlyRecovery: return "Sprout"
        case .recovering: return "Grower"
        case .healthy: return "Eco Guardian"
        case .thriving: return "Planet Keeper"
        }
    }

    // MARK: - Completions

    private var today: Date { calendar.startOfDay(for: Date()) }

    var todaysCompletions: [Completion] {
        data.completions.filter { calendar.isDate($0.day, inSameDayAs: today) }
    }

    func completion(for activityId: String) -> Completion? {
        todaysCompletions.first { $0.activityId == activityId }
    }

    func isCompletedToday(_ activityId: String) -> Bool {
        completion(for: activityId) != nil
    }

    func rows(in category: ActivityCategory) -> [ActivityRow] {
        MockData.activities(in: category).map {
            ActivityRow(activity: $0, completion: completion(for: $0.id))
        }
    }

    func doneCount(in category: ActivityCategory) -> Int {
        rows(in: category).filter(\.isCompletedToday).count
    }

    var totalActionsLogged: Int { data.history.count }

    /// Up to three things worth doing today: not yet done, favourites first.
    var suggestedMissions: [Activity] {
        let pending = MockData.activities.filter { !isCompletedToday($0.id) }
        let favourites = pending.filter { data.favouriteCategories.contains($0.category) }
        let rest = pending.filter { !data.favouriteCategories.contains($0.category) }
        return Array((favourites + rest).prefix(3))
    }

    var activeRegionalMission: RegionalMission? {
        MockData.regionalMissions.first { $0.kind == .event }
    }

    func hasJoined(_ mission: RegionalMission) -> Bool {
        data.joinedMissionIds.contains(mission.id)
    }

    // MARK: - Weekly progress

    static let weeklyGoal = 700

    var pointsThisWeek: Int {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        return data.history.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.points }
    }

    var weeklyProgress: Double {
        min(1, Double(pointsThisWeek) / Double(Self.weeklyGoal))
    }

    // MARK: - Evidence

    var evidencePhotos: [EvidencePhoto] {
        data.evidence.sorted { $0.capturedAt > $1.capturedAt }
    }

    /// Wall of Fame shows the current calendar month only.
    var evidenceThisMonth: [EvidencePhoto] {
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else {
            return evidencePhotos
        }
        return evidencePhotos.filter { $0.capturedAt >= monthStart }
    }

    var history: [HistoryEntry] {
        data.history.sorted { $0.date > $1.date }
    }

    // MARK: - Badges

    func isUnlocked(_ badge: Badge) -> Bool {
        switch badge.requirement {
        case .totalActions(let n):
            return totalActionsLogged >= n
        case .streak(let n):
            return max(data.streakDays, data.longestStreak) >= n
        case .earthPoints(let n):
            return data.lifetimeEarthPoints >= n
        case .categoryActions(let category, let n):
            return data.history.filter { $0.categoryRaw == category.rawValue }.count >= n
        case .evidenceCount(let n):
            return data.evidence.count >= n
        case .seasonal:
            return false
        }
    }

    var unlockedBadgeCount: Int { MockData.badges.filter(isUnlocked).count }

    // MARK: - Vouchers

    var redeemedVouchers: [RedeemedVoucher] {
        data.redeemed.sorted { $0.redeemedAt > $1.redeemedAt }
    }

    func canAfford(_ voucher: Voucher) -> Bool { data.rewardPoints >= voucher.points }

    func hasRedeemed(_ voucher: Voucher) -> Bool {
        data.redeemed.contains { $0.voucherId == voucher.id }
    }

    // MARK: - Inactivity

    var daysSinceLastAction: Int {
        guard let last = data.lastActiveDay else { return 0 }
        return calendar.dateComponents([.day], from: last, to: today).day ?? 0
    }

    var showsInactivityWarning: Bool {
        data.lastActiveDay != nil && daysSinceLastAction >= PointsEngine.inactivityWarningDays
    }

    // MARK: - Mutations

    /// Local-only "auth". Any well-formed email plus a 6+ character password gets in.
    @discardableResult
    func logIn(email: String, password: String) -> Bool {
        guard Self.isValidEmail(email), password.count >= 6 else { return false }
        mutate {
            $0.isLoggedIn = true
            $0.email = email
            if $0.userName.isEmpty {
                $0.userName = email == MockData.demoEmail
                    ? MockData.demoName
                    : Self.nameFromEmail(email)
            }
        }
        return true
    }

    func logOut() {
        mutate { $0.isLoggedIn = false }
        selectedTab = .home
    }

    func completeOnboarding(
        motivations: Set<Motivation>,
        categories: Set<ActivityCategory>,
        locationEnabled: Bool,
        cameraEnabled: Bool
    ) {
        mutate {
            $0.motivations = motivations
            $0.favouriteCategories = categories
            $0.locationEnabled = locationEnabled
            $0.cameraEnabled = cameraEnabled
            $0.hasCompletedOnboarding = true
        }
    }

    func updateFavourites(_ categories: Set<ActivityCategory>) {
        mutate { $0.favouriteCategories = categories }
    }

    func setNotifications(_ on: Bool) { mutate { $0.notificationsEnabled = on } }
    func setLocationEnabled(_ on: Bool) { mutate { $0.locationEnabled = on } }
    func setCameraEnabled(_ on: Bool) { mutate { $0.cameraEnabled = on } }

    var notificationsEnabled: Bool { data.notificationsEnabled }
    var locationEnabled: Bool { data.locationEnabled }
    var cameraEnabled: Bool { data.cameraEnabled }
    var motivations: Set<Motivation> { data.motivations }

    func join(_ mission: RegionalMission) {
        mutate { $0.joinedMissionIds.insert(mission.id) }
        toast = Toast(kind: .info, message: "You're in — see you at \(mission.locationName).")
    }

    // MARK: Logging an action

    enum LogOutcome {
        case awarded(Award)
        case alreadyDoneToday(Activity)
    }

    /// The one path every completion goes through — checklist, camera, or a suggestion
    /// card. Enforces max one credit per activity per day regardless of the source.
    @discardableResult
    func logActivity(
        _ activity: Activity,
        source: Completion.Source,
        evidenceImage: UIImage? = nil
    ) -> LogOutcome {
        guard !isCompletedToday(activity.id) else {
            return .alreadyDoneToday(activity)
        }

        let previousStreak = data.streakDays
        advanceStreak()

        var photoId: UUID?
        if let image = evidenceImage {
            let id = UUID()
            if PhotoStore.save(image, id: id) {
                photoId = id
            }
        }

        let points = PointsEngine.award(
            basePoints: activity.basePoints,
            streakDays: data.streakDays,
            hasEvidence: photoId != nil
        )

        let completion = Completion(
            activityId: activity.id,
            day: today,
            source: source,
            evidencePhotoId: photoId,
            pointsAwarded: points
        )

        mutate {
            $0.completions.append(completion)
            if let photoId {
                $0.evidence.append(EvidencePhoto(
                    id: photoId,
                    activityId: activity.id,
                    categoryRaw: activity.category.rawValue,
                    capturedAt: Date()
                ))
            }
            $0.history.append(HistoryEntry(
                id: UUID(),
                title: activity.name,
                categoryRaw: activity.category.rawValue,
                points: points,
                date: Date(),
                sourceRaw: source.rawValue,
                completionId: completion.id
            ))
            $0.earthPoints += points
            $0.rewardPoints += points
            $0.lifetimeEarthPoints += points
        }

        let award = Award(
            activity: activity,
            points: points,
            hasEvidence: photoId != nil,
            streakIncreased: data.streakDays > previousStreak
        )
        lastAward = award
        return .awarded(award)
    }

    /// Attaching evidence after the fact tops up the completion with the bonus delta.
    @discardableResult
    func attachEvidence(_ image: UIImage, to activity: Activity) -> Int {
        guard let index = data.completions.firstIndex(where: {
            $0.activityId == activity.id && calendar.isDate($0.day, inSameDayAs: today)
        }) else { return 0 }

        guard data.completions[index].evidencePhotoId == nil else { return 0 }

        let photoId = UUID()
        guard PhotoStore.save(image, id: photoId) else { return 0 }

        let updated = PointsEngine.award(
            basePoints: activity.basePoints,
            streakDays: data.streakDays,
            hasEvidence: true
        )
        let delta = max(0, updated - data.completions[index].pointsAwarded)

        mutate {
            $0.completions[index].evidencePhotoId = photoId
            $0.completions[index].pointsAwarded = updated
            $0.evidence.append(EvidencePhoto(
                id: photoId,
                activityId: activity.id,
                categoryRaw: activity.category.rawValue,
                capturedAt: Date()
            ))
            $0.history.append(HistoryEntry(
                id: UUID(),
                title: "\(activity.name) — evidence bonus",
                categoryRaw: activity.category.rawValue,
                points: delta,
                date: Date(),
                sourceRaw: Completion.Source.checklist.rawValue
            ))
            $0.earthPoints += delta
            $0.rewardPoints += delta
            $0.lifetimeEarthPoints += delta
        }

        toast = Toast(kind: .success, message: "Evidence added — +\(delta) bonus pts")
        return delta
    }

    /// Undoes today's log for an activity: points, history line and photo all go back.
    /// Used when the user corrects the camera's guess to a different category.
    func revertTodaysCompletion(activityId: String) {
        guard let completion = completion(for: activityId) else { return }

        if let photoId = completion.evidencePhotoId,
           let photo = data.evidence.first(where: { $0.id == photoId }) {
            PhotoStore.delete(photo)
        }

        mutate {
            $0.completions.removeAll { $0.id == completion.id }
            $0.history.removeAll { $0.completionId == completion.id }
            if let photoId = completion.evidencePhotoId {
                $0.evidence.removeAll { $0.id == photoId }
            }
            $0.earthPoints = max(0, $0.earthPoints - completion.pointsAwarded)
            $0.rewardPoints = max(0, $0.rewardPoints - completion.pointsAwarded)
            $0.lifetimeEarthPoints = max(0, $0.lifetimeEarthPoints - completion.pointsAwarded)
        }
    }

    func deleteEvidence(_ photo: EvidencePhoto) {
        PhotoStore.delete(photo)
        mutate {
            $0.evidence.removeAll { $0.id == photo.id }
            if let index = $0.completions.firstIndex(where: { $0.evidencePhotoId == photo.id }) {
                $0.completions[index].evidencePhotoId = nil
            }
        }
        toast = Toast(kind: .info, message: "Photo removed. Points stay yours.")
    }

    // MARK: Redeeming

    enum RedeemOutcome {
        case success(RedeemedVoucher)
        case insufficientPoints(short: Int)
    }

    /// Only Reward Points move. Earth Points are never spendable.
    @discardableResult
    func redeem(_ voucher: Voucher) -> RedeemOutcome {
        guard data.rewardPoints >= voucher.points else {
            return .insufficientPoints(short: voucher.points - data.rewardPoints)
        }
        let record = RedeemedVoucher(
            id: UUID(),
            voucherId: voucher.id,
            redeemedAt: Date(),
            code: Self.voucherCode()
        )
        mutate {
            $0.rewardPoints -= voucher.points
            $0.redeemed.append(record)
        }
        return .success(record)
    }

    // MARK: - Daily housekeeping

    /// Run at launch and whenever the app comes back to the foreground: breaks a stale
    /// streak and applies Earth Point decay for each full inactive week.
    func refreshForToday() {
        guard let last = data.lastActiveDay else { return }
        let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        guard days > 0 else { return }

        var changed = false
        var next = data

        if days >= 2, next.streakDays != 0 {
            next.longestStreak = max(next.longestStreak, next.streakDays)
            next.streakDays = 0
            changed = true
        }

        let weeks = PointsEngine.decayWeeks(daysInactive: days)
        if weeks > next.decayWeeksApplied {
            let pending = weeks - next.decayWeeksApplied
            next.earthPoints = PointsEngine.decayed(earthPoints: next.earthPoints, weeks: pending)
            next.decayWeeksApplied = weeks
            changed = true
        }

        if changed {
            data = next
            PersistenceStore.save(next)
        }
    }

    private func advanceStreak() {
        var next = data
        if let last = next.lastActiveDay {
            let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            switch days {
            case 0: break                     // already logged something today
            case 1: next.streakDays += 1      // consecutive day
            default: next.streakDays = 1      // streak broken, start over
            }
        } else {
            next.streakDays = 1
        }
        next.longestStreak = max(next.longestStreak, next.streakDays)
        next.lastActiveDay = today
        next.decayWeeksApplied = 0
        data = next
    }

    /// Sends the user back through the first-run flow without clearing their points.
    func reopenOnboarding() {
        mutate { $0.hasCompletedOnboarding = false }
    }

    // MARK: - Debug

    /// Wipes local state — surfaced in Settings so the onboarding flow can be re-run.
    func resetEverything() {
        PersistenceStore.wipe()
        data = PersistedState()
        selectedTab = .home
        toast = Toast(kind: .info, message: "Local data cleared.")
    }

    // MARK: - Plumbing

    private func mutate(_ change: (inout PersistedState) -> Void) {
        var next = data
        change(&next)
        data = next
        PersistenceStore.save(next)
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 5, !trimmed.hasPrefix("@"), !trimmed.hasSuffix("@") else { return false }
        let parts = trimmed.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".") && !parts[1].hasSuffix(".")
    }

    private static func nameFromEmail(_ email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "Friend"
        return local
            .split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    private static func voucherCode() -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return "EH-" + String((0..<6).map { _ in alphabet.randomElement()! })
    }
}

// MARK: - Supporting types

enum AppTab: Hashable {
    case home, activity, redeem, profile
}

struct Award: Identifiable, Equatable {
    let id = UUID()
    let activity: Activity
    let points: Int
    let hasEvidence: Bool
    let streakIncreased: Bool
}

struct Toast: Identifiable, Equatable {
    enum Kind {
        case success, info, warning

        var tint: Color {
            switch self {
            case .success: return Theme.C.accent2_600
            case .info: return Theme.C.neutral800
            case .warning: return Theme.C.accent600
            }
        }

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}
