//
//  RepositoryProtocols.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Activity, ActivityLog, Badge, UserState, Category
//  Dipakai : MockRepositories.swift, semua Service di Services/
//
//  Semua kontrak data access dikumpulkan di satu file supaya bisa dibaca sekaligus.
//  Implementasinya di MockRepositories.swift; nanti tambah FirebaseRepositories.swift
//  tanpa menyentuh Services/.
//
//  Semua method `async throws` — bukan karena mock butuh, tapi karena Firebase butuh.
//  Kalau sekarang dibuat sinkron, menukar implementasinya nanti berarti mengubah
//  setiap call site di service dan setiap ViewModel di atasnya.
//

import Foundation

/// Katalog aktivitas. Read-only: user tidak pernah membuat aktivitas baru.
protocol ActivityRepositoryProtocol: Sendable {
    func fetchAllActivities() async throws -> [Activity]
    func fetchActivity(id: String) async throws -> Activity?
}

/// Riwayat pencatatan aktivitas. Sumber kebenaran untuk dedup, cap harian,
/// dan cooldown.
protocol ActivityLogRepositoryProtocol: Sendable {
    /// Log satu hari tertentu, untuk menjumlahkan cap harian.
    func fetchLogs(userId: String, dayKey: String) async throws -> [ActivityLog]

    /// Pengecekan dedup lintas flow (checklist manual vs kamera).
    func fetchLog(dedupKey: String) async throws -> ActivityLog?

    /// Log terbaru satu aktivitas, untuk menghitung cooldown.
    func fetchMostRecentLog(userId: String, activityId: String) async throws -> ActivityLog?

    func fetchAllLogs(userId: String) async throws -> [ActivityLog]

    func save(_ log: ActivityLog) async throws

    /// Wipes this user's logs. Needed by "reset local data" — clearing only
    /// `UserState` leaves every log behind, so the day's activities come
    /// straight back and their dedup keys still block re-logging.
    func deleteAll(userId: String) async throws
}

// Fights have no repository protocol. Everything about them — saved bookmarks,
// attendance, hosted drafts — lives inside `UserState`, so `FightRepository` is a
// namespace of pure functions over it rather than a data-access boundary. That
// changes when Fights become their own Firestore collection.

/// An **append-only award log**, not a mirror of the badge catalogue.
///
/// Only what the user actually earned is stored. The catalogue stays bundled and
/// is joined on at display time, so a badge's copy can be edited without touching
/// anybody's record — and an award survives its catalogue entry being removed.
protocol BadgeRepositoryProtocol: Sendable {
    func fetchEarned(userId: String) async throws -> [EarnedBadge]

    /// Records an award. **Idempotent**: awarding a badge that is already earned
    /// leaves the original `earnedAt` alone rather than moving it, which is what
    /// makes `badges/{badgeId}` safe as a Firestore document id and means the
    /// caller never has to read before writing.
    func award(_ badge: EarnedBadge, userId: String) async throws

    func deleteAll(userId: String) async throws
}

protocol UserStateRepositoryProtocol: Sendable {
    /// Membuat state baru kalau user belum punya, sehingga pemanggilnya tidak
    /// perlu menangani kasus "user belum ada".
    func fetchUserState(userId: String) async throws -> UserState
    func save(_ state: UserState) async throws
}

/// Sumber data prioritas provinsi. Dipisah jadi protocol supaya nanti bisa
/// diganti Remote Config tanpa mengubah PointsCalculationService.
protocol ProvincePriorityProviding: Sendable {
    func isPrioritized(category: Category, provinceCode: String?) -> Bool
}
