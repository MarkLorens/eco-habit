import Foundation

/// One badge a user actually earned — the award itself, not a flag on a catalogue entry.
///
/// **Why this exists as its own record.** Badges used to be stored by writing the
/// whole catalogue back with `isUnlocked` flipped, and read by starting from the
/// catalogue and merging those flags on. That made the *catalogue* the source of
/// truth for what somebody owned, with three consequences:
///
/// - Remove a badge from `MockBadgeData`, or change an organiser's reward id, and a
///   badge the user genuinely earned silently disappeared from their profile.
/// - Recording two owned badges wrote all twenty-one.
/// - Every user carried their own copy of each badge's name, description and
///   criteria, so fixing a typo never reached anyone who had already earned it.
///
/// An award is a fact about a moment, so it is stored like one. This is the same
/// reasoning behind `ActivityLog` freezing its multipliers: the record has to stay
/// explainable even after the thing that produced it has changed.
nonisolated struct EarnedBadge: Identifiable, Codable, Hashable {

    /// Where the badge came from.
    ///
    /// Kept because "Shoreline Keeper" is a very different story depending on
    /// whether it was reached by counting or handed over by an organiser, and
    /// because it folds in `FightAttendance.awardedBadgeId` — that fact used to
    /// live in a second place with no link back to here.
    nonisolated enum Source: Codable, Hashable {
        /// Reached by counting: streak, points, evidence photos, category actions.
        case threshold(Int)
        /// Awarded for attending a Fight, which set it as its reward.
        case fight(fightId: String)
    }

    let badgeId: String

    /// Snapshot of the badge's name **at the moment it was awarded**.
    ///
    /// The redundancy is the point: it is what lets an earned badge still render
    /// after it has been pulled from the catalogue or renamed. Display prefers the
    /// live catalogue entry when there is one, so a rename still propagates to
    /// anyone whose badge is still listed.
    let name: String

    let earnedAt: Date
    let source: Source

    var id: String { badgeId }

    init(badgeId: String, name: String, earnedAt: Date = Date(), source: Source) {
        self.badgeId = badgeId
        self.name = name
        self.earnedAt = earnedAt
        self.source = source
    }

    /// Build an award from a catalogue entry.
    init(awarding badge: Badge, at date: Date = Date(), source: Source) {
        self.init(badgeId: badge.id, name: badge.name, earnedAt: date, source: source)
    }
}
