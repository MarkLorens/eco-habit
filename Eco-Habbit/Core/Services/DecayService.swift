//
//  DecayService.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : UserState, EarthStage, PointsConfiguration, DateKeys
//  Dipakai : AppStore (dipanggil saat app dibuka), unit test
//

import Foundation

nonisolated struct DecayOutcome: Equatable {

    let daysInactive: Int

    /// Berapa hari yang benar-benar dikenakan potongan pada pemanggilan ini.
    let daysDecayed: Int

    let pointsBefore: Int
    let pointsAfter: Int

    let stageBefore: EarthStage
    let stageAfter: EarthStage

    /// Sudah waktunya mengirim notifikasi peringatan.
    let shouldWarn: Bool

    /// Potongan ditahan oleh aturan "maksimal 1 stage per periode absen".
    let limitedByStageFloor: Bool

    /// Potongan ditahan oleh lantai poin.
    let limitedByPointsFloor: Bool

    var pointsLost: Int { pointsBefore - pointsAfter }
    var didDecay: Bool { pointsAfter < pointsBefore }
}

nonisolated struct DecayService {

    let config: PointsConfiguration

    init(config: PointsConfiguration = .default) {
        self.config = config
    }

    /// Menghitung DAN menerapkan decay ke `state`.
    ///
    /// Dipanggil saat app dibuka, bukan oleh proses latar belakang — sesuai spec.
    /// Aman dipanggil berkali-kali dalam sehari: `lastDecayAppliedDate` mencegah
    /// hari yang sama dipotong dua kali.
    @discardableResult
    func apply(to state: inout UserState,
               asOf now: Date = Date(),
               calendar: Calendar = .current) -> DecayOutcome {

        let stageBefore = state.earthStage(using: config)

        func unchanged(daysInactive: Int, shouldWarn: Bool) -> DecayOutcome {
            DecayOutcome(daysInactive: daysInactive,
                         daysDecayed: 0,
                         pointsBefore: state.currentPoints,
                         pointsAfter: state.currentPoints,
                         stageBefore: stageBefore,
                         stageAfter: stageBefore,
                         shouldWarn: shouldWarn,
                         limitedByStageFloor: false,
                         limitedByPointsFloor: false)
        }

        guard let lastActivityDate = state.lastActivityDate else {
            // User baru yang belum pernah mencatat apa pun tidak layak dihukum.
            return unchanged(daysInactive: 0, shouldWarn: false)
        }

        let daysInactive = DateKeys.dayDifference(from: lastActivityDate,
                                                  to: now,
                                                  calendar: calendar)

        // Jam device diubah mundur — jangan lakukan apa-apa.
        guard daysInactive >= 0 else { return unchanged(daysInactive: 0, shouldWarn: false) }

        let shouldWarn = daysInactive >= config.decayWarningDayThreshold
            && daysInactive <= config.decayGracePeriodDays

        guard daysInactive > config.decayGracePeriodDays else {
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        // Poin di AWAL periode absen. Batas "turun maksimal 1 stage" diukur dari
        // sini, bukan dari poin saat ini — kalau diukur dari poin saat ini, user
        // yang membuka app tiap beberapa hari selama absen panjang bisa turun
        // satu stage setiap kali membuka.
        let baseline = state.decayBaselinePoints ?? state.currentPoints

        // Hari pertama yang boleh dipotong = hari terakhir aktif + masa tenggang.
        guard let graceEnd = calendar.date(byAdding: .day,
                                           value: config.decayGracePeriodDays,
                                           to: calendar.startOfDay(for: lastActivityDate))
        else {
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        // Kalau sudah pernah dipotong, lanjutkan dari sana — bukan dari awal.
        let resumeFrom = max(graceEnd, state.lastDecayAppliedDate ?? graceEnd)
        let daysToDecay = DateKeys.dayDifference(from: resumeFrom, to: now, calendar: calendar)

        guard daysToDecay > 0 else {
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        // Sudah di lantai atau di bawahnya. `max()` di bawah akan MENAIKKAN poin
        // user kalau kasus ini tidak dicegat lebih dulu.
        guard state.currentPoints > config.decayPointsFloor else {
            state.lastDecayAppliedDate = calendar.startOfDay(for: now)
            state.decayBaselinePoints = baseline
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        let pointsBefore = state.currentPoints

        // Berbunga, bukan linear: −2% dari poin SAAT INI setiap hari, sesuai
        // spec. Penurunannya melambat sendiri, jadi absen panjang tidak
        // menghabiskan segalanya.
        let decayed = Double(pointsBefore) * pow(1 - config.decayRatePerDay, Double(daysToDecay))
        let afterRate = Int(decayed.rounded())

        let afterPointsFloor = max(config.decayPointsFloor, afterRate)

        // Batas turun stage, dihitung dari stage di awal absen.
        let baselineStage = config.stage(forPoints: baseline)
        let lowestAllowedIndex = max(0, baselineStage.rawValue - config.maxStageDropPerAbsence)
        let lowestAllowedStage = EarthStage(rawValue: lowestAllowedIndex) ?? .critical
        let stageFloorPoints = config.threshold(for: lowestAllowedStage)

        let finalPoints = max(afterPointsFloor, stageFloorPoints)

        state.currentPoints = finalPoints
        state.lastDecayAppliedDate = calendar.startOfDay(for: now)
        state.decayBaselinePoints = baseline

        return DecayOutcome(
            daysInactive: daysInactive,
            daysDecayed: daysToDecay,
            pointsBefore: pointsBefore,
            pointsAfter: finalPoints,
            stageBefore: stageBefore,
            stageAfter: config.stage(forPoints: finalPoints),
            shouldWarn: shouldWarn,
            limitedByStageFloor: finalPoints > afterPointsFloor,
            limitedByPointsFloor: afterRate < config.decayPointsFloor
        )
    }
}
