//
//  MockRepositories.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : RepositoryProtocols, KeyValueStore, semua Mock*Data, semua Model
//  Dipakai : semua Service, App entry point, SwiftUI preview, test
//
//  Repository yang menyimpan log pakai `actor`: state-nya berubah dan diakses dari
//  beberapa tempat, dan actor memberi perlindungan itu tanpa lock manual.
//  Yang read-only cukup `struct`.
//

import Foundation

// MARK: - Activity (katalog, read-only)

nonisolated struct MockActivityRepository: ActivityRepositoryProtocol {

    let activities: [Activity]

    init(activities: [Activity] = MockActivityData.all) {
        self.activities = activities
    }

    func fetchAllActivities() async throws -> [Activity] {
        activities
    }

    func fetchActivity(id: String) async throws -> Activity? {
        activities.first { $0.id == id }
    }
}

// MARK: - Activity log

actor MockActivityLogRepository: ActivityLogRepositoryProtocol {

    private let store: KeyValueStoring
    private let storageKey = "activity_logs"

    /// Cache di memori supaya tidak membaca file di setiap query. Diisi sekali
    /// saat akses pertama, lalu selalu ikut diperbarui bersama file.
    private var cache: [ActivityLog]?

    init(store: KeyValueStoring = LocalJSONFileStore()) {
        self.store = store
    }

    private func allLogs() async throws -> [ActivityLog] {
        if let cache { return cache }
        let loaded = try await store.load([ActivityLog].self, forKey: storageKey) ?? []
        cache = loaded
        return loaded
    }

    func fetchLogs(userId: String, dayKey: String) async throws -> [ActivityLog] {
        try await allLogs().filter { $0.userId == userId && $0.dayKey == dayKey }
    }

    func fetchLog(dedupKey: String) async throws -> ActivityLog? {
        try await allLogs().first { $0.dedupKey == dedupKey }
    }

    func fetchMostRecentLog(userId: String, activityId: String) async throws -> ActivityLog? {
        try await allLogs()
            .filter { $0.userId == userId && $0.activityId == activityId }
            .max { $0.loggedAt < $1.loggedAt }
    }

    func fetchAllLogs(userId: String) async throws -> [ActivityLog] {
        try await allLogs()
            .filter { $0.userId == userId }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    func save(_ log: ActivityLog) async throws {
        var logs = try await allLogs()

        // Menimpa entry dengan dedupKey sama, bukan menambah duplikat. Ini jaring
        // pengaman kedua: pengecekan dedup ada di service, tapi kalau dua tap
        // terjadi hampir bersamaan, di sinilah duplikatnya berhenti.
        if let existingIndex = logs.firstIndex(where: { $0.dedupKey == log.dedupKey }) {
            logs[existingIndex] = log
        } else {
            logs.append(log)
        }

        cache = logs
        try await store.save(logs, forKey: storageKey)
    }

    /// Drops this user's logs. `cache` must be updated in the same breath as
    /// the file, or the next read serves the deleted rows straight back.
    func deleteAll(userId: String) async throws {
        let remaining = try await allLogs().filter { $0.userId != userId }
        cache = remaining
        try await store.save(remaining, forKey: storageKey)
    }
}

// MARK: - Badge

/// Stores only what was earned. The catalogue is bundled and joined on for
/// display, so nothing here knows what a badge is called or what it takes.
///
/// The file it writes maps one-to-one onto the Firestore shape it replaces —
/// `users/{uid}/badges/{badgeId}`, one small document per award — so the Firebase
/// implementation of this protocol is a transcription rather than a redesign.
actor MockBadgeRepository: BadgeRepositoryProtocol {

    private let store: KeyValueStoring

    init(store: KeyValueStoring = LocalJSONFileStore()) {
        self.store = store
    }

    private func storageKey(userId: String) -> String {
        "earned_badges_\(userId)"
    }

    func fetchEarned(userId: String) async throws -> [EarnedBadge] {
        let stored = try await store.load([EarnedBadge].self,
                                          forKey: storageKey(userId: userId)) ?? []
        return stored.sorted { $0.earnedAt < $1.earnedAt }
    }

    /// Keeps the first award and ignores the rest.
    ///
    /// Overwriting would move `earnedAt` forward every time something re-checked
    /// a badge the user already had, which quietly rewrites their history — and
    /// "when did I earn this" is the whole reason the date is stored.
    func award(_ badge: EarnedBadge, userId: String) async throws {
        var earned = try await fetchEarned(userId: userId)
        guard !earned.contains(where: { $0.badgeId == badge.badgeId }) else { return }
        earned.append(badge)
        try await store.save(earned, forKey: storageKey(userId: userId))
    }

    func deleteAll(userId: String) async throws {
        try await store.removeValue(forKey: storageKey(userId: userId))
    }
}

// MARK: - User state

actor MockUserStateRepository: UserStateRepositoryProtocol {

    private let store: KeyValueStoring

    init(store: KeyValueStoring = LocalJSONFileStore()) {
        self.store = store
    }

    private func storageKey(userId: String) -> String {
        "user_state_\(userId)"
    }

    func fetchUserState(userId: String) async throws -> UserState {
        let stored = try await store.load(UserState.self, forKey: storageKey(userId: userId))
        return stored ?? UserState(userId: userId)
    }

    func save(_ state: UserState) async throws {
        try await store.save(state, forKey: storageKey(userId: state.userId))
    }
}

// MARK: - Province priority

/// Selalu mengembalikan `false` selama `provinceCode` masih `nil`, jadi
/// priorityMultiplier tetap 1.0 untuk semua user sampai fitur lokasi diaktifkan.
nonisolated struct MockProvincePriorityProvider: ProvincePriorityProviding {

    func isPrioritized(category: Category, provinceCode: String?) -> Bool {
        MockProvincePriorityData.isPrioritized(category: category,
                                               provinceCode: provinceCode)
    }
}
