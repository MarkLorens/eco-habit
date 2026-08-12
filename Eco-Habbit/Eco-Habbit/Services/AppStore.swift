//
//  AppStore.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : semua Service, semua Repository, MockUserStateData
//  Dipakai : Eco_HabbitApp, RootView, DashboardView, CategoryDetailView
//
//  Satu-satunya objek yang disentuh View. View tidak pernah memanggil service
//  atau repository langsung, sehingga saat lapisan data ditukar Firebase,
//  tidak ada satu pun View yang perlu diubah.
//

import Foundation
import Observation

@Observable
final class AppStore {

    // MARK: - Keadaan yang dibaca UI

    private(set) var userState: UserState
    private(set) var badges: [Badge] = []

    /// Id aksi yang sudah tercatat hari ini. Diturunkan dari log, bukan disimpan
    /// terpisah, jadi tidak mungkin melenceng dari riwayat sebenarnya.
    private(set) var completedTodayIDs: Set<String> = []

    /// Badge yang baru terbuka pada aksi terakhir — untuk memunculkan perayaan.
    private(set) var recentlyUnlockedBadges: [Badge] = []

    /// Hasil decay terakhir saat app dibuka, untuk memberi tahu user.
    private(set) var lastDecay: DecayOutcome?

    private(set) var isReady = false

    // MARK: - Ketergantungan

    let userId: String
    let config: PointsConfiguration

    private let logRepository: ActivityLogRepositoryProtocol
    private let userStateRepository: UserStateRepositoryProtocol
    private let badgeRepository: BadgeRepositoryProtocol
    private let loggingService: ActivityLoggingService
    private let claimService: EventClaimService
    private let decayService: DecayService
    private let streakService: StreakService

    /// `seedDemoDataIfEmpty` mengisi user contoh saat belum ada data tersimpan,
    /// supaya Dashboard tidak kosong melompong ketika app pertama dijalankan.
    /// Matikan begitu ada alur onboarding sungguhan.
    init(userId: String = "demo-user",
         config: PointsConfiguration = .default,
         store: KeyValueStoring = LocalJSONFileStore(),
         seedDemoDataIfEmpty: Bool = true) {

        self.userId = userId
        self.config = config
        self.userState = UserState(userId: userId)
        self.seedDemoDataIfEmpty = seedDemoDataIfEmpty

        let activityRepository = MockActivityRepository()
        let eventRepository = MockEventRepository()
        let logRepository = MockActivityLogRepository(store: store)
        let eventLogRepository = MockEventLogRepository(store: store)
        let userStateRepository = MockUserStateRepository(store: store)
        let badgeRepository = MockBadgeRepository(store: store)

        self.logRepository = logRepository
        self.userStateRepository = userStateRepository
        self.badgeRepository = badgeRepository

        self.loggingService = ActivityLoggingService(
            config: config,
            activityRepository: activityRepository,
            logRepository: logRepository,
            userStateRepository: userStateRepository,
            badgeRepository: badgeRepository
        )

        self.claimService = EventClaimService(
            config: config,
            eventRepository: eventRepository,
            eventLogRepository: eventLogRepository,
            userStateRepository: userStateRepository,
            badgeRepository: badgeRepository
        )

        self.decayService = DecayService(config: config)
        self.streakService = StreakService(config: config)
    }

    private let seedDemoDataIfEmpty: Bool

    // MARK: - Siklus hidup

    /// Dipanggil sekali saat app dibuka.
    ///
    /// Di sinilah decay dihitung — bukan di proses latar belakang, sesuai spec.
    func bootstrap(now: Date = Date()) async {
        do {
            var state = try await userStateRepository.fetchUserState(userId: userId)

            // Belum ada jejak apa pun: isi dengan user contoh.
            if seedDemoDataIfEmpty,
               state.currentPoints == 0,
               state.lastActivityDate == nil {
                state = MockUserStateData.demo
                try await userStateRepository.save(state)
            }

            let outcome = decayService.apply(to: &state, asOf: now)
            if outcome.didDecay {
                try await userStateRepository.save(state)
                lastDecay = outcome
            }

            userState = state
            badges = try await badgeRepository.fetchBadges(userId: userId)
            await refreshTodayLogs(now: now)
            isReady = true
        } catch {
            // Penyimpanan lokal nyaris tidak pernah gagal. Kalau tetap gagal,
            // app jalan dengan state kosong daripada tidak jalan sama sekali.
            isReady = true
        }
    }

    private func refreshTodayLogs(now: Date = Date()) async {
        let dayKey = DateKeys.dayKey(for: now)
        let logs = (try? await logRepository.fetchLogs(userId: userId, dayKey: dayKey)) ?? []
        completedTodayIDs = Set(logs.map(\.activityId))
    }

    // MARK: - Aksi

    @discardableResult
    func logActivity(_ activity: Activity,
                     hasEvidence: Bool = false,
                     source: LogSource = .manualChecklist,
                     now: Date = Date()) async -> LogActivityResult {

        recentlyUnlockedBadges = []

        do {
            let result = try await loggingService.log(
                activityId: activity.id,
                userId: userId,
                hasEvidence: hasEvidence,
                source: source,
                now: now
            )

            if case .success(let outcome) = result {
                userState = outcome.userState
                recentlyUnlockedBadges = outcome.unlockedBadges
                if !outcome.unlockedBadges.isEmpty {
                    badges = try await badgeRepository.fetchBadges(userId: userId)
                }
                await refreshTodayLogs(now: now)
            }

            return result
        } catch {
            return .activityNotFound
        }
    }

    @discardableResult
    func claimEvent(_ event: Event,
                    checkInCode: String? = nil,
                    now: Date = Date()) async -> ClaimEventResult {
        do {
            let result = try await claimService.claim(eventId: event.id,
                                                      userId: userId,
                                                      checkInCode: checkInCode,
                                                      now: now)
            if case .success(let outcome) = result {
                userState = outcome.userState
                recentlyUnlockedBadges = outcome.unlockedBadges
                badges = try await badgeRepository.fetchBadges(userId: userId)
            }
            return result
        } catch {
            return .eventNotFound
        }
    }

    // MARK: - Bacaan turunan untuk UI

    func isCompletedToday(_ activityId: String) -> Bool {
        completedTodayIDs.contains(activityId)
    }

    var earthStage: EarthStage {
        userState.earthStage(using: config)
    }

    /// Streak yang pantas ditampilkan — 0 kalau sudah putus tapi belum tercatat.
    func displayStreak(asOf date: Date = Date()) -> Int {
        streakService.displayStreak(for: userState, asOf: date)
    }

    var pointsToNextStage: Int? {
        guard let next = earthStage.next else { return nil }
        return max(0, config.threshold(for: next) - userState.currentPoints)
    }

    /// Sisa jatah poin dasar hari ini, untuk ditampilkan kalau cap tercapai.
    func remainingDailyBasePoints() async -> Int {
        let dayKey = DateKeys.dayKey(for: Date())
        let logs = (try? await logRepository.fetchLogs(userId: userId, dayKey: dayKey)) ?? []
        let used = logs.reduce(0) { $0 + $1.countedBasePoints }
        return max(0, config.dailyBasePointsCap - used)
    }
}
