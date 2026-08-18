import Foundation

/// What an absence cost.
nonisolated struct DecayOutcome: Equatable {
    let daysInactive: Int
    /// Days actually charged on this call.
    let daysDecayed: Int
    let pointsBefore: Int
    let pointsAfter: Int
    let stageBefore: EarthStage
    let stageAfter: EarthStage
    /// Time to show the "your Earth is slipping" warning.
    let shouldWarn: Bool
    /// The drop was held back by the one-stage-per-absence limit.
    let limitedByStageFloor: Bool
    /// The drop was held back by the points floor.
    let limitedByPointsFloor: Bool

    var pointsLost: Int { pointsBefore - pointsAfter }
    var didDecay: Bool { pointsAfter < pointsBefore }
}

/// Points slip away during an absence, with three brakes on how far.
///
/// Tio's algorithm, working in `YYYY-MM-DD` day strings rather than `Date` to
/// match the rest of main — the day counts come out the same, and the strings are
/// what `lastActiveDay` already stores.
///
/// Applied when the app is opened, not by a background job, and safe to call
/// repeatedly: `lastDecayAppliedDay` stops a day being charged twice.
nonisolated struct DecayService {

    let config: PointsConfiguration

    init(config: PointsConfiguration = .default) {
        self.config = config
    }

    @discardableResult
    func apply(to state: inout PersistedState, today: String) -> DecayOutcome {

        let stageBefore = config.stage(forPoints: state.currentPoints)

        func unchanged(daysInactive: Int, shouldWarn: Bool) -> DecayOutcome {
            DecayOutcome(daysInactive: daysInactive, daysDecayed: 0,
                         pointsBefore: state.currentPoints, pointsAfter: state.currentPoints,
                         stageBefore: stageBefore, stageAfter: stageBefore,
                         shouldWarn: shouldWarn,
                         limitedByStageFloor: false, limitedByPointsFloor: false)
        }

        // Somebody who has never logged anything has done nothing to be punished for.
        guard let lastActiveDay = state.lastActiveDay,
              let daysInactive = StreakService.dayGap(from: lastActiveDay, to: today)
        else { return unchanged(daysInactive: 0, shouldWarn: false) }

        // Device clock moved backwards — do nothing.
        guard daysInactive >= 0 else { return unchanged(daysInactive: 0, shouldWarn: false) }

        let shouldWarn = daysInactive >= config.decayWarningDayThreshold
            && daysInactive <= config.decayGracePeriodDays

        guard daysInactive > config.decayGracePeriodDays else {
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        let baseline = state.decayBaselinePoints ?? state.currentPoints

        // First chargeable day = last active day + the grace period.
        guard let graceEnd = Day.adding(config.decayGracePeriodDays, to: lastActiveDay) else {
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        // Already charged some of it? Resume from there, not from the start.
        // YYYY-MM-DD compares correctly with `max`.
        let resumeFrom = max(graceEnd, state.lastDecayAppliedDay ?? graceEnd)
        guard let daysToDecay = StreakService.dayGap(from: resumeFrom, to: today),
              daysToDecay > 0
        else { return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn) }

        // Already at or below the floor. The `max()` below would otherwise RAISE
        // the user's points, so this case has to be intercepted first.
        guard state.currentPoints > config.decayPointsFloor else {
            state.lastDecayAppliedDay = today
            state.decayBaselinePoints = baseline
            return unchanged(daysInactive: daysInactive, shouldWarn: shouldWarn)
        }

        let pointsBefore = state.currentPoints

        // Compounding, not linear: −2% of the CURRENT total per day. The fall
        // slows itself, so a long absence does not wipe everything.
        let decayed = Double(pointsBefore) * pow(1 - config.decayRatePerDay, Double(daysToDecay))
        let afterRate = Int(decayed.rounded())

        let afterPointsFloor = max(config.decayPointsFloor, afterRate)

        // Stage floor, measured from the stage at the START of the absence.
        let baselineStage = config.stage(forPoints: baseline)
        let lowestAllowedIndex = max(0, baselineStage.rawValue - config.maxStageDropPerAbsence)
        let lowestAllowedStage = EarthStage(rawValue: lowestAllowedIndex) ?? .critical
        let stageFloorPoints = config.threshold(for: lowestAllowedStage)

        let finalPoints = max(afterPointsFloor, stageFloorPoints)

        state.currentPoints = finalPoints
        state.lastDecayAppliedDay = today
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
