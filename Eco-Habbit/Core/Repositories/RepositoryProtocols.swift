//
//  RepositoryProtocols.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : Activity, ActivityLog, Event, EventLog, Badge, UserState, Category
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
}

protocol EventRepositoryProtocol: Sendable {
    func fetchAllEvents() async throws -> [Event]
    func fetchEvent(id: String) async throws -> Event?
}

protocol EventLogRepositoryProtocol: Sendable {
    func fetchLog(dedupKey: String) async throws -> EventLog?

    /// Klaim pada satu bulan, untuk menghitung cap bulanan.
    func fetchLogs(userId: String, monthKey: String) async throws -> [EventLog]

    func fetchAllLogs(userId: String) async throws -> [EventLog]

    func save(_ log: EventLog) async throws
}

/// Status badge per user. Katalog badge-nya statis, yang disimpan adalah
/// `isUnlocked` + `unlockedDate` milik user.
protocol BadgeRepositoryProtocol: Sendable {
    func fetchBadges(userId: String) async throws -> [Badge]
    func save(_ badges: [Badge], userId: String) async throws
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
