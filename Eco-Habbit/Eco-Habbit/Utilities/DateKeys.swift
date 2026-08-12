//
//  DateKeys.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 11/08/26.
//
//  Butuh   : —
//  Dipakai : UserState, ActivityLog, semua Service, test
//

import Foundation

/// Pembuat kunci tanggal berbentuk String untuk dedup dan pengelompokan periode.
///
/// Semua formatter di sini pakai locale POSIX + kalender Gregorian secara paksa.
/// Dengan locale device, user berkalender Hijriah/Buddhis menghasilkan kunci tahun
/// berbeda, sehingga dedup harian dan reset kuota bulanan jadi tidak terduga.
nonisolated enum DateKeys {

    /// `static let` karena membuat DateFormatter mahal dan ini dipanggil sangat sering.
    private static let dayFormatter: DateFormatter = makeFormatter(format: "yyyy-MM-dd")
    private static let monthFormatter: DateFormatter = makeFormatter(format: "yyyy-MM")

    private static func makeFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter
    }

    /// "2026-08-11"
    static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// "2026-08"
    static func monthKey(for date: Date) -> String {
        monthFormatter.string(from: date)
    }

    /// Selisih hari kalender, bukan selisih jam. Dipakai streak, cooldown, dan decay
    /// supaya hasilnya tidak bergantung pada jam berapa user mencatat.
    static func dayDifference(from start: Date,
                              to end: Date,
                              calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}
