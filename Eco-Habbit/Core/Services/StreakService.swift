//
//  StreakService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : UserState, PointsConfiguration, DateKeys
//  Dipakai : ActivityLoggingService, DashboardView, unit test
//

import Foundation

nonisolated struct StreakOutcome: Equatable {
    let newStreak: Int

    /// Jatah "ampun" bulanan terpakai untuk menutup satu hari bolong.
    let usedFreeze: Bool

    /// Streak putus dan dimulai lagi dari 1.
    let didReset: Bool
}

nonisolated struct StreakService {

    let config: PointsConfiguration

    init(config: PointsConfiguration = .default) {
        self.config = config
    }

    /// Streak setelah user mencatat aksi pada `date`.
    ///
    /// Aturan jarak hari:
    /// - belum pernah mencatat → mulai dari 1
    /// - hari yang sama        → tidak berubah (aksi kedua di hari yang sama)
    /// - selisih 1 hari        → bertambah
    /// - selisih 2 hari        → satu hari bolong; freeze dipakai kalau tersedia
    /// - selisih ≥ 3 hari      → reset, freeze tidak menolong
    ///
    /// Freeze sengaja hanya menutup TEPAT satu hari. Kalau dibuat menutup absen
    /// sepanjang apa pun, user bisa hilang tiga minggu dengan streak 60 tetap
    /// utuh sementara decay memotong poinnya — dua sistem yang saling
    /// bertentangan di mata user.
    func outcome(for state: UserState,
                 loggingOn date: Date,
                 calendar: Calendar = .current) -> StreakOutcome {

        guard let lastActivityDate = state.lastActivityDate else {
            return StreakOutcome(newStreak: 1, usedFreeze: false, didReset: false)
        }

        let dayGap = DateKeys.dayDifference(from: lastActivityDate,
                                            to: date,
                                            calendar: calendar)

        switch dayGap {
        case ..<0:
            // Tanggal terakhir ada di masa depan — jam device diubah user.
            // Streak dibiarkan apa adanya; menghukum user karena hal ini salah.
            return StreakOutcome(newStreak: state.currentStreak,
                                 usedFreeze: false,
                                 didReset: false)

        case 0:
            // Sudah mencatat hari ini. Aksi berikutnya tidak menambah streak,
            // karena streak dihitung per HARI, bukan per aksi.
            return StreakOutcome(newStreak: max(1, state.currentStreak),
                                 usedFreeze: false,
                                 didReset: false)

        case 1:
            return StreakOutcome(newStreak: state.currentStreak + 1,
                                 usedFreeze: false,
                                 didReset: false)

        case 2 where state.isStreakFreezeAvailable(asOf: date):
            return StreakOutcome(newStreak: state.currentStreak + 1,
                                 usedFreeze: true,
                                 didReset: false)

        default:
            return StreakOutcome(newStreak: 1, usedFreeze: false, didReset: true)
        }
    }

    /// Streak yang PANTAS DITAMPILKAN hari ini, tanpa mengubah apa pun.
    ///
    /// Beda dari `state.currentStreak` mentah: kalau user sudah bolong dua hari
    /// dan tidak punya freeze, angka tersimpan masih 12 padahal streaknya sudah
    /// putus. Menampilkan 12 sampai user membuka app lagi itu berbohong.
    func displayStreak(for state: UserState,
                       asOf date: Date = Date(),
                       calendar: Calendar = .current) -> Int {

        guard let lastActivityDate = state.lastActivityDate else { return 0 }

        let dayGap = DateKeys.dayDifference(from: lastActivityDate,
                                            to: date,
                                            calendar: calendar)

        switch dayGap {
        case ..<0, 0, 1:
            // Hari ini atau kemarin: streak masih hidup.
            return state.currentStreak
        case 2 where state.isStreakFreezeAvailable(asOf: date):
            return state.currentStreak
        default:
            return 0
        }
    }
}
