import Foundation

/// **The only code that writes a saved bookmark or an attendance record.**
///
/// A namespace of pure functions over `inout UserState` rather than a protocol —
/// everything a Fight needs already lives inside the user document, so there is
/// nothing for a repository protocol to abstract yet. `AppState.mutateUser`
/// bridges it to storage. That changes when Fights become Firestore documents.
///
/// Attendance is capped by the same monthly quota as everything else, so hosting
/// or attending is never a way around it.
enum FightRepository {

    enum CheckInResult: Equatable {
        case checkedIn(pointsAwarded: Int, wasCapped: Bool, badge: Badge?)
        /// The code was wrong. Deliberately not "not signed up" — there is no signup.
        case wrongCode
        case alreadyCheckedIn
        case windowClosed
        case eventCancelled
    }

    // MARK: - Saved (a private bookmark)

    /// Saving is a shortlist and nothing more: no commitment, the organiser is
    /// never told, and check-in does not require it. Anything stronger would be
    /// an RSVP, and an RSVP that nobody can see is just a bookmark with anxiety
    /// attached.
    @discardableResult
    static func toggleSaved(_ fightId: String, in state: inout UserState) -> Bool {
        if let index = state.savedFightIds.firstIndex(of: fightId) {
            state.savedFightIds.remove(at: index)
            return false
        }
        state.savedFightIds.append(fightId)
        return true
    }

    static func isSaved(_ fightId: String, in state: UserState) -> Bool {
        state.savedFightIds.contains(fightId)
    }

    /// Saved Fights that haven't finished, soonest first. A saved Fight that has
    /// been and gone drops off by itself — the shortlist is about what's next.
    static func saved(_ fights: [Fight], in state: UserState, now: Date = Date()) -> [Fight] {
        fights
            .filter { isSaved($0.id, in: state) && $0.endsAt > now && $0.status != .draft }
            .sorted { $0.startsAt < $1.startsAt }
    }

    // MARK: - Check-in

    /// Credits attendance after the attendee enters the organiser's code.
    ///
    /// The organiser publishes one code for the whole Fight; the attendee scans
    /// or types it. That direction is what lets this be a purely local write —
    /// the attendee's own device credits the attendee. The old design had the
    /// host scanning each attendee, which is a cross-user write and needs a
    /// server to authorise.
    ///
    /// Uniqueness comes from refusing a second write, the same guarantee the
    /// composite document ID `{fightId}_{uid}` will give in Firestore.
    @discardableResult
    static func checkIn(
        to fight: Fight,
        code: String,
        in state: inout UserState,
        now: Date = Date()
    ) -> CheckInResult {
        guard fight.status != .cancelled else { return .eventCancelled }
        guard state.fightAttendance[fight.id] == nil else { return .alreadyCheckedIn }
        // Order matters: a wrong code should say so even outside the window,
        // but a *right* code outside the window is the more useful message.
        guard fight.matchesCheckInCode(code) else { return .wrongCode }
        guard fight.isCheckInOpen(at: now) else { return .windowClosed }

        let config = PointsConfiguration.default
        let usedThisMonth = state.effectiveMonthlyEventPoints(asOf: now)
        let remaining = max(0, config.monthlyEventPointsCap - usedThisMonth)
        let awarded = min(fight.attendancePoints, remaining)

        // The badge is awarded even when the points are capped. Attendance
        // happened; the quota limits the score, not the record of showing up.
        // Only reported, never recorded here. The award is written by the
        // caller as an `EarnedBadge`, so "what did I earn and when" lives in one
        // place instead of being split between a flag here and a badge store.
        let badge = fight.rewardBadgeId.flatMap(MockBadgeData.fightReward(withID:))

        state.fightAttendance[fight.id] = FightAttendance(
            fightId: fight.id,
            checkedInAt: now,
            localDate: Day.today(now),
            awardedBadgeId: badge?.id
        )

        state.currentPoints += awarded
        state.monthlyEventPointsEarned = usedThisMonth + awarded
        state.monthlyEventPointsPeriod = DateKeys.monthKey(for: now)
        if !state.attendedEventIDs.contains(fight.id) {
            state.attendedEventIDs.append(fight.id)
        }

        return .checkedIn(
            pointsAwarded: awarded,
            wasCapped: awarded < fight.attendancePoints,
            badge: badge
        )
    }

    static func attendance(for fightId: String, in state: UserState) -> FightAttendance? {
        state.fightAttendance[fightId]
    }

    static func hasAttended(_ fightId: String, in state: UserState) -> Bool {
        state.fightAttendance[fightId] != nil
    }

    // MARK: - Reads

    /// The list is chronological. No map, no distance filter in v1.
    static func upcoming(_ fights: [Fight], now: Date = Date()) -> [Fight] {
        fights
            .filter { $0.status == .published && $0.endsAt > now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    /// Attended Fights are archived permanently, newest first. This is the
    /// record the Fight badges are built on.
    static func attended(_ fights: [Fight], in state: UserState) -> [Fight] {
        fights
            .filter { hasAttended($0.id, in: state) }
            .sorted {
                let a = state.fightAttendance[$0.id]?.checkedInAt ?? .distantPast
                let b = state.fightAttendance[$1.id]?.checkedInAt ?? .distantPast
                return a > b
            }
    }

    // MARK: - Hosting

    static func hostedFights(in state: UserState) -> [Fight] {
        state.hostedFights.sorted { $0.startsAt < $1.startsAt }
    }

    static func isHost(of fight: Fight, in state: UserState) -> Bool {
        state.isOrganization && state.hostedFights.contains { $0.id == fight.id }
    }

    /// A new event starts as a **draft** (PRD §6.5.1) so a half-written one never
    /// appears in the public list.
    static func createDraft(_ fight: Fight, in state: inout UserState) {
        var draft = fight
        draft.status = .draft
        state.hostedFights.append(draft)
    }

    @discardableResult
    static func update(_ fight: Fight, in state: inout UserState) -> Bool {
        guard let index = state.hostedFights.firstIndex(where: { $0.id == fight.id }) else { return false }
        // Status transitions go through publish/cancel, never through an edit.
        var updated = fight
        updated.status = state.hostedFights[index].status
        state.hostedFights[index] = updated
        return true
    }

    @discardableResult
    static func publish(_ fightId: String, in state: inout UserState) -> Bool {
        guard let index = state.hostedFights.firstIndex(where: { $0.id == fightId }),
              state.hostedFights[index].status == .draft else { return false }
        state.hostedFights[index].status = .published
        return true
    }

    /// **Cancelling is not deletion.** The Fight stays visible to anyone who
    /// saved it, which is the whole point: they need to find out.
    @discardableResult
    static func cancel(_ fightId: String, in state: inout UserState) -> Bool {
        guard let index = state.hostedFights.firstIndex(where: { $0.id == fightId }),
              state.hostedFights[index].status != .cancelled else { return false }
        state.hostedFights[index].status = .cancelled
        return true
    }

    /// How many people this device knows have checked in.
    ///
    /// Locally that is only ever the account itself — one device cannot see
    /// another's attendance without a server. It becomes a real headcount when
    /// `/attendance/{fightId}_{uid}` is a Firestore query; until then the host
    /// screen labels it honestly rather than implying a roster it doesn't have.
    static func knownCheckInCount(for fightId: String, in state: UserState) -> Int {
        state.fightAttendance[fightId] == nil ? 0 : 1
    }
}
