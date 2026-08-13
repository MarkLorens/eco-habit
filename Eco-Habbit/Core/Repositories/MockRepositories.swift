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

actor MockBadgeRepository: BadgeRepositoryProtocol {

    private let store: KeyValueStoring
    private let catalog: [Badge]

    init(store: KeyValueStoring = LocalJSONFileStore(),
         catalog: [Badge] = MockBadgeData.all) {
        self.store = store
        self.catalog = catalog
    }

    private func storageKey(userId: String) -> String {
        "badges_\(userId)"
    }

    /// Selalu mulai dari katalog, lalu tempelkan status unlock yang tersimpan.
    ///
    /// Kalau langsung mengembalikan array tersimpan, badge baru yang ditambahkan
    /// ke katalog setelah user sempat menyimpan tidak akan pernah muncul untuknya,
    /// dan badge yang dihapus dari katalog akan terus muncul.
    func fetchBadges(userId: String) async throws -> [Badge] {
        let stored = try await store.load([Badge].self, forKey: storageKey(userId: userId)) ?? []
        let unlockedByID = Dictionary(
            stored.filter(\.isUnlocked).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return catalog.map { badge in
            guard let unlocked = unlockedByID[badge.id] else { return badge }
            return badge.unlocked(at: unlocked.unlockedDate ?? Date())
        }
    }

    func save(_ badges: [Badge], userId: String) async throws {
        try await store.save(badges, forKey: storageKey(userId: userId))
    }

    /// Removes the stored unlock state; `fetchBadges` then rebuilds from the
    /// catalogue with everything locked again.
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
