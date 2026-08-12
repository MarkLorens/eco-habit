//
//  EventClaimService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : EventRepository, EventLogRepository, UserStateRepository,
//            BadgeRepository, BadgeEvaluationService, DateKeys
//  Dipakai : AppStore
//

import Foundation

nonisolated struct EventClaimOutcome {
    let log: EventLog
    let unlockedBadges: [Badge]
    let userState: UserState

    /// Klaim tercatat penuh tapi poinnya dipotong cap bulanan.
    var wasCapped: Bool { log.wasCappedByMonthlyLimit }
}

nonisolated enum ClaimEventResult {
    case success(EventClaimOutcome)
    case alreadyClaimed(EventLog)
    case eventNotFound
    case checkInCodeRequired
}

nonisolated struct EventClaimService {

    let config: PointsConfiguration
    let eventRepository: EventRepositoryProtocol
    let eventLogRepository: EventLogRepositoryProtocol
    let userStateRepository: UserStateRepositoryProtocol
    let badgeRepository: BadgeRepositoryProtocol

    private var badgeService: BadgeEvaluationService { BadgeEvaluationService() }

    init(
        config: PointsConfiguration = .default,
        eventRepository: EventRepositoryProtocol,
        eventLogRepository: EventLogRepositoryProtocol,
        userStateRepository: UserStateRepositoryProtocol,
        badgeRepository: BadgeRepositoryProtocol
    ) {
        self.config = config
        self.eventRepository = eventRepository
        self.eventLogRepository = eventLogRepository
        self.userStateRepository = userStateRepository
        self.badgeRepository = badgeRepository
    }

    /// Mengklaim kehadiran event.
    ///
    /// Cap bulanan bekerja dengan cara khusus sesuai spec: klaim yang melewati
    /// batas TETAP dicatat dengan poin penuh di `eventPoints` dan tetap dihitung
    /// untuk badge, tapi `awardedPoints` bisa lebih kecil atau bahkan 0. Jadi
    /// riwayat user tetap jujur menampilkan "hadir di 6 event", sementara poin
    /// yang masuk berhenti di 150 per bulan.
    func claim(eventId: String,
               userId: String,
               checkInCode: String? = nil,
               now: Date = Date()) async throws -> ClaimEventResult {

        guard let event = try await eventRepository.fetchEvent(id: eventId) else {
            return .eventNotFound
        }

        let dedupKey = EventLog.dedupKey(userId: userId, eventId: eventId)
        if let existing = try await eventLogRepository.fetchLog(dedupKey: dedupKey) {
            return .alreadyClaimed(existing)
        }

        // Kode aslinya belum bisa diverifikasi di sisi app — nanti tugas server.
        // Untuk sekarang cukup dipastikan user memang mengisi sesuatu.
        if event.requiresCheckInCode {
            let trimmed = checkInCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty { return .checkInCodeRequired }
        }

        var state = try await userStateRepository.fetchUserState(userId: userId)

        let monthKey = DateKeys.monthKey(for: now)
        let usedThisMonth = state.effectiveMonthlyEventPoints(asOf: now)
        let remaining = max(0, config.monthlyEventPointsCap - usedThisMonth)
        let awarded = min(event.points, remaining)

        let log = EventLog(
            userId: userId,
            eventId: event.id,
            tier: event.tier,
            claimedAt: now,
            monthKey: monthKey,
            eventPoints: event.points,
            awardedPoints: awarded
        )

        try await eventLogRepository.save(log)

        state.currentPoints += awarded

        // Yang dihitung terhadap cap adalah poin yang BENAR-BENAR diberikan.
        // Kalau yang dicatat poin penuh, kelebihan yang tidak pernah masuk akan
        // ikut menghabiskan jatah bulan ini untuk kedua kalinya.
        state.monthlyEventPointsEarned = usedThisMonth + awarded
        state.monthlyEventPointsPeriod = monthKey

        if !state.hasAttended(eventID: event.id) {
            state.attendedEventIDs.append(event.id)
        }

        let allBadges = try await badgeRepository.fetchBadges(userId: userId)
        let unlocked = badgeService.newlyUnlocked(from: allBadges, state: state, at: now)
        if !unlocked.isEmpty {
            try await badgeRepository.save(badgeService.merged(allBadges, with: unlocked),
                                           userId: userId)
        }

        try await userStateRepository.save(state)

        return .success(
            EventClaimOutcome(log: log, unlockedBadges: unlocked, userState: state)
        )
    }
}
