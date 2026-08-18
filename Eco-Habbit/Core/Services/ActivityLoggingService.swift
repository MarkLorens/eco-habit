//
//  ActivityLoggingService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : semua RepositoryProtocols, PointsCalculationService,
//            StreakService, BadgeEvaluationService, DateKeys
//  Dipakai : AppStore
//
//  Satu-satunya jalan masuk untuk mencatat aksi harian. Checklist manual dan
//  hasil kamera memanggil fungsi yang sama, jadi dedup lintas flow terjadi
//  dengan sendirinya — bukan karena kedua layar sepakat, tapi karena keduanya
//  tidak punya jalan lain.
//

import Foundation

nonisolated struct LoggedActivityOutcome {
    let log: ActivityLog
    let breakdown: PointsBreakdown
    let streak: StreakOutcome
    let unlockedBadges: [EarnedBadge]
    let userState: UserState
}

nonisolated enum LogActivityResult {
    case success(LoggedActivityOutcome)

    /// Sudah tercatat hari ini. Sesuai spec, entry point lain menampilkan status
    /// ini dan tidak menambah poin.
    case alreadyLoggedToday(ActivityLog)

    case onCooldown(remainingDays: Int)
    case activityNotFound
}

nonisolated struct ActivityLoggingService {

    let config: PointsConfiguration
    let activityRepository: ActivityRepositoryProtocol
    let logRepository: ActivityLogRepositoryProtocol
    let userStateRepository: UserStateRepositoryProtocol
    let badgeRepository: BadgeRepositoryProtocol
    let provincePriority: ProvincePriorityProviding

    private var points: PointsCalculationService { PointsCalculationService(config: config) }
    private var streakService: StreakService { StreakService(config: config) }
    private var badgeService: BadgeEvaluationService { BadgeEvaluationService() }

    init(
        config: PointsConfiguration = .default,
        activityRepository: ActivityRepositoryProtocol,
        logRepository: ActivityLogRepositoryProtocol,
        userStateRepository: UserStateRepositoryProtocol,
        badgeRepository: BadgeRepositoryProtocol,
        provincePriority: ProvincePriorityProviding = MockProvincePriorityProvider()
    ) {
        self.config = config
        self.activityRepository = activityRepository
        self.logRepository = logRepository
        self.userStateRepository = userStateRepository
        self.badgeRepository = badgeRepository
        self.provincePriority = provincePriority
    }

    /// Mencatat satu aksi.
    ///
    /// URUTAN LANGKAHNYA PENTING dan tidak boleh diacak:
    /// 1. dedup — supaya tap kedua tidak pernah sampai ke perhitungan
    /// 2. cooldown — penolakan lebih murah daripada perhitungan
    /// 3. streak dihitung SEBELUM poin, karena poin memakai streak yang baru
    /// 4. cap harian dibaca dari log hari ini
    /// 5. log ditulis lebih dulu, baru UserState — kalau app mati di antaranya,
    ///    yang tersisa adalah log tanpa poin, bukan poin tanpa bukti
    /// 6. badge dicek paling akhir, saat UserState sudah final
    func log(activityId: String,
             userId: String,
             hasEvidence: Bool = false,
             source: LogSource = .manualChecklist,
             now: Date = Date(),
             calendar: Calendar = .current) async throws -> LogActivityResult {

        guard let activity = try await activityRepository.fetchActivity(id: activityId) else {
            return .activityNotFound
        }

        let dayKey = DateKeys.dayKey(for: now)
        let dedupKey = ActivityLog.dedupKey(userId: userId, activityId: activityId, dayKey: dayKey)

        if let existing = try await logRepository.fetchLog(dedupKey: dedupKey) {
            return .alreadyLoggedToday(existing)
        }

        if let remaining = try await cooldownRemaining(for: activity,
                                                       userId: userId,
                                                       now: now,
                                                       calendar: calendar),
           remaining > 0 {
            return .onCooldown(remainingDays: remaining)
        }

        var state = try await userStateRepository.fetchUserState(userId: userId)

        let streakOutcome = streakService.outcome(for: state, loggingOn: now, calendar: calendar)

        let todayLogs = try await logRepository.fetchLogs(userId: userId, dayKey: dayKey)
        let basePointsUsedToday = points.basePointsUsed(in: todayLogs)

        let isPrioritized = provincePriority.isPrioritized(
            category: activity.category,
            provinceCode: state.currentProvinceCode
        )

        // Streak yang BARU yang dipakai: mencatat aksi di hari ke-7 memberi
        // 1,1× pada aksi itu juga, bukan mulai besok.
        let breakdown = points.breakdown(
            activity: activity,
            hasEvidence: hasEvidence,
            currentStreak: streakOutcome.newStreak,
            isPrioritized: isPrioritized,
            basePointsUsedToday: basePointsUsedToday
        )

        let log = ActivityLog(
            userId: userId,
            activityId: activity.id,
            category: activity.category,
            loggedAt: now,
            dayKey: dayKey,
            basePoints: breakdown.basePoints,
            countedBasePoints: breakdown.countedBasePoints,
            evidenceBonus: breakdown.evidenceBonus,
            streakMultiplier: breakdown.streakMultiplier,
            priorityMultiplier: breakdown.priorityMultiplier,
            finalPoints: breakdown.finalPoints,
            hasEvidence: hasEvidence,
            source: source,
            provinceCode: state.currentProvinceCode
        )

        try await logRepository.save(log)

        apply(breakdown: breakdown,
              streak: streakOutcome,
              category: activity.category,
              hasEvidence: hasEvidence,
              now: now,
              to: &state)

        // Only the awards are written — one small record each, rather than the
        // whole catalogue with two flags flipped.
        let earned = try await badgeRepository.fetchEarned(userId: userId)
        let unlocked = badgeService.newlyEarned(
            from: MockBadgeData.all,
            state: state,
            alreadyEarned: Set(earned.map(\.badgeId)),
            at: now
        )
        for award in unlocked {
            try await badgeRepository.award(award, userId: userId)
        }

        try await userStateRepository.save(state)

        return .success(
            LoggedActivityOutcome(log: log,
                                  breakdown: breakdown,
                                  streak: streakOutcome,
                                  unlockedBadges: unlocked,
                                  userState: state)
        )
    }

    // MARK: - Bagian dalam

    /// Sisa hari cooldown, atau `nil` kalau aksi ini memang tidak punya cooldown.
    ///
    /// Dihitung dari LOG terakhir, bukan dari `activity.lastCompletedDate` —
    /// katalog aktivitas bersifat bersama dan tidak menyimpan progres siapa pun.
    private func cooldownRemaining(for activity: Activity,
                                   userId: String,
                                   now: Date,
                                   calendar: Calendar) async throws -> Int? {
        guard let cooldownDays = activity.cooldownDays else { return nil }

        guard let lastLog = try await logRepository.fetchMostRecentLog(userId: userId,
                                                                       activityId: activity.id)
        else { return nil }

        let daysPassed = DateKeys.dayDifference(from: lastLog.loggedAt,
                                                to: now,
                                                calendar: calendar)
        return max(0, cooldownDays - daysPassed)
    }

    /// Menerapkan hasil perhitungan ke UserState.
    private func apply(breakdown: PointsBreakdown,
                       streak: StreakOutcome,
                       category: Category,
                       hasEvidence: Bool,
                       now: Date,
                       to state: inout UserState) {

        state.currentPoints += breakdown.finalPoints
        state.currentStreak = streak.newStreak
        state.lastActivityDate = now

        if streak.usedFreeze {
            state.streakFreezeUsedPeriod = DateKeys.monthKey(for: now)
        }

        state.incrementActionCount(for: category)

        if hasEvidence {
            state.totalEvidencePhotoCount += 1
        }

        // Ada aktivitas lagi, jadi periode absen berakhir. Tanpa ini, baseline
        // lama akan dipakai lagi pada absen berikutnya dan batas "turun 1 stage"
        // dihitung dari angka yang sudah tidak relevan.
        state.decayBaselinePoints = nil
        state.lastDecayAppliedDate = nil
    }
}
