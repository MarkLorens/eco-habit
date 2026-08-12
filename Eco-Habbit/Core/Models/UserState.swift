//
//  UserState.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : EarthStage, Category, PointsConfiguration, DateKeys
//  Dipakai : semua Service, UserStateRepository, hampir semua View
//

import Foundation

/// Seluruh progres user. Di Firestore nanti = satu dokumen `users/{uid}`.
nonisolated struct UserState: Codable, Hashable {

    let userId: String

    // MARK: - Poin & stage

    var currentPoints: Int

    /// Ambang stage ada di config, jadi stage tidak bisa jadi computed property
    /// tanpa argumen. Disediakan sebagai fungsi supaya test bisa menyuntik config
    /// lain tanpa mengubah state global.
    func earthStage(using config: PointsConfiguration = .default) -> EarthStage {
        config.stage(forPoints: currentPoints)
    }

    // MARK: - Streak

    var currentStreak: Int

    /// Tanggal terakhir user mencatat aksi apa pun. Dasar streak dan decay.
    var lastActivityDate: Date?

    /// Periode ("2026-08") saat streak freeze terakhir dipakai. `nil` = belum
    /// pernah. Freeze jatahnya 1× per bulan dan tidak ada proses yang jalan tiap
    /// tanggal 1, jadi ketersediaannya dihitung dari periode ini saat dibaca.
    var streakFreezeUsedPeriod: String?

    // MARK: - Kuota poin event bulanan

    var monthlyEventPointsEarned: Int

    /// Periode dari angka di atas, format "2026-08".
    var monthlyEventPointsPeriod: String

    // MARK: - Penghitung untuk badge

    var totalEvidencePhotoCount: Int

    /// Daftar id, bukan counter, supaya klaim ganda bisa ditolak.
    var attendedEventIDs: [String]

    /// Kunci `String` (bukan `[Category: Int]`) karena dictionary berkunci enum
    /// tidak ter-serialize sebagai map JSON. Akses lewat helper di bawah.
    var actionCountsByCategoryRaw: [String: Int]

    // MARK: - Decay

    /// Tanggal decay terakhir diterapkan. Mencegah poin dipotong dua kali untuk
    /// hari yang sama kalau user membuka-tutup app berulang.
    var lastDecayAppliedDate: Date?

    /// Poin saat periode absen ini mulai. `nil` = tidak sedang absen.
    ///
    /// Perlu disimpan karena batas "maksimal 1 stage per periode absen" diukur
    /// dari stage di awal absen, bukan dari stage saat decay terakhir dihitung.
    /// Tanpa baseline ini, user yang membuka app tiap beberapa hari selama absen
    /// panjang bisa turun 1 stage per pembukaan.
    var decayBaselinePoints: Int?

    // MARK: - Provinsi

    /// Selalu `nil` untuk sekarang; app belum meminta izin lokasi, jadi
    /// priorityMultiplier selalu 1.0 untuk semua user.
    var currentProvinceCode: String?

    // MARK: - Fights (hosted events, QR check-in)
    //
    // Ported from the Vincent branch and kept: this branch's `Event` is a
    // read-only catalogue you claim, with no host, no QR and no attendance.
    // `Fight` is the organisation-hosted event from PRD §4 / §6.5.1. The two
    // coexist deliberately — an Event is claimed, a Fight is hosted and scanned.

    var displayName: String = ""

    /// UI preference. Nothing is scheduled with the system yet — see PRD §9.4,
    /// still unbuilt.
    var notificationsEnabled: Bool = true

    /// PRD §4.3 — verified organisations only. Never user-writable in the
    /// shipped UI; an admin flips it. §9.6 makes that a Security Rules
    /// requirement once Firebase lands.
    var isOrganization: Bool = false
    var orgName: String = ""

    /// Keyed by fight id.
    var fightSignups: [String: FightSignup] = [:]
    var fightAttendance: [String: FightAttendance] = [:]
    /// Events this account hosts, and the scans taken on this device.
    var hostedFights: [Fight] = []
    var hostScans: [String: [HostScan]] = [:]

    init(
        userId: String,
        currentPoints: Int = 0,
        currentStreak: Int = 0,
        lastActivityDate: Date? = nil,
        streakFreezeUsedPeriod: String? = nil,
        monthlyEventPointsEarned: Int = 0,
        monthlyEventPointsPeriod: String = DateKeys.monthKey(for: Date()),
        totalEvidencePhotoCount: Int = 0,
        attendedEventIDs: [String] = [],
        actionCountsByCategoryRaw: [String: Int] = [:],
        lastDecayAppliedDate: Date? = nil,
        decayBaselinePoints: Int? = nil,
        currentProvinceCode: String? = nil,
        displayName: String = "",
        notificationsEnabled: Bool = true,
        isOrganization: Bool = false,
        orgName: String = "",
        fightSignups: [String: FightSignup] = [:],
        fightAttendance: [String: FightAttendance] = [:],
        hostedFights: [Fight] = [],
        hostScans: [String: [HostScan]] = [:]
    ) {
        self.userId = userId
        self.currentPoints = currentPoints
        self.currentStreak = currentStreak
        self.lastActivityDate = lastActivityDate
        self.streakFreezeUsedPeriod = streakFreezeUsedPeriod
        self.monthlyEventPointsEarned = monthlyEventPointsEarned
        self.monthlyEventPointsPeriod = monthlyEventPointsPeriod
        self.totalEvidencePhotoCount = totalEvidencePhotoCount
        self.attendedEventIDs = attendedEventIDs
        self.actionCountsByCategoryRaw = actionCountsByCategoryRaw
        self.lastDecayAppliedDate = lastDecayAppliedDate
        self.decayBaselinePoints = decayBaselinePoints
        self.currentProvinceCode = currentProvinceCode
        self.displayName = displayName
        self.notificationsEnabled = notificationsEnabled
        self.isOrganization = isOrganization
        self.orgName = orgName
        self.fightSignups = fightSignups
        self.fightAttendance = fightAttendance
        self.hostedFights = hostedFights
        self.hostScans = hostScans
    }

    // MARK: - Helper hitungan kategori

    func actionCount(for category: Category) -> Int {
        actionCountsByCategoryRaw[category.rawValue] ?? 0
    }

    mutating func incrementActionCount(for category: Category, by amount: Int = 1) {
        let current = actionCountsByCategoryRaw[category.rawValue] ?? 0
        actionCountsByCategoryRaw[category.rawValue] = current + amount
    }

    func hasAttended(eventID: String) -> Bool {
        attendedEventIDs.contains(eventID)
    }

    // MARK: - Periode bulanan

    /// Reset saat dibaca: periode kedaluwarsa dianggap 0 tanpa menulis apa pun.
    /// Perlu karena tidak ada proses yang jalan tiap tanggal 1 — user bisa tidak
    /// membuka app selama berminggu-minggu.
    func effectiveMonthlyEventPoints(asOf referenceDate: Date = Date()) -> Int {
        let currentPeriod = DateKeys.monthKey(for: referenceDate)
        return monthlyEventPointsPeriod == currentPeriod ? monthlyEventPointsEarned : 0
    }

    /// Freeze tersedia kalau belum pernah dipakai, atau terakhir dipakai di bulan lain.
    func isStreakFreezeAvailable(asOf referenceDate: Date = Date()) -> Bool {
        guard let streakFreezeUsedPeriod else { return true }
        return streakFreezeUsedPeriod != DateKeys.monthKey(for: referenceDate)
    }
}
