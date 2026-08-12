import Foundation

/// **The only code that writes a signup or an attendance record** (PRD §9.7, §9.13.2).
///
/// Attendance awards points on the same scale and against the same monthly cap
/// as claiming an `Event`, so hosting is not a way around the quota.
///
/// Historical note: attendance used to record a *date* that `EvaluationLoop`
/// applies the +10 when it scores that day — the same shape §9.3 uses for the Firestore
/// design, where the attendance document is the source of truth and Vitality is derived
/// from it on-device. Keeping that split now means Phase 10 changes where the record is
/// stored, not what the number means.
enum FightRepository {

    enum SignupResult: Equatable {
        case signedUp
        case alreadySignedUp
        case eventFinished
        case eventCancelled
    }

    enum CheckInResult: Equatable {
        case checkedIn(pointsAwarded: Int, wasCapped: Bool)
        case notSignedUp
        case alreadyCheckedIn
        case windowClosed
        case eventCancelled
    }

    // MARK: - Signup (PRD §4.4)

    @discardableResult
    static func signUp(for fight: Fight, in state: inout UserState, now: Date = Date()) -> SignupResult {
        guard fight.status != .cancelled else { return .eventCancelled }
        guard fight.endsAt > now else { return .eventFinished }

        if let existing = state.fightSignups[fight.id], existing.isActive {
            return .alreadySignedUp
        }

        // Re-signing up after a cancellation issues a fresh token, so a screenshot of the
        // old QR can't be handed to someone else.
        state.fightSignups[fight.id] = FightSignup(
            fightId: fight.id,
            signedUpAt: now,
            checkInToken: token(for: fight.id, in: state)
        )
        return .signedUp
    }

    /// PRD §4.4 — cancel any time before the event starts. No penalty, no reliability
    /// score; punishing non-attendance in a v1 with no capacity pressure creates anxiety
    /// for no benefit.
    @discardableResult
    static func cancelSignup(for fightId: String, in state: inout UserState, now: Date = Date()) -> Bool {
        guard var signup = state.fightSignups[fightId], signup.isActive else { return false }
        guard state.fightAttendance[fightId] == nil else { return false }  // already attended

        signup.cancelledAt = now
        state.fightSignups[fightId] = signup
        return true
    }

    static func signup(for fightId: String, in state: UserState) -> FightSignup? {
        state.fightSignups[fightId].flatMap { $0.isActive ? $0 : nil }
    }

    static func isSignedUp(_ fightId: String, in state: UserState) -> Bool {
        signup(for: fightId, in: state) != nil
    }

    // MARK: - Check-in (PRD §4.5)

    /// Records attendance and marks the day so the evaluation loop credits +10.
    ///
    /// Locally this stands in for the host scanning the attendee's QR. The uniqueness
    /// guarantee is the same one the composite document ID gives in Firestore (§9.3):
    /// one check-in per attendee per event, no race.
    @discardableResult
    static func checkIn(to fight: Fight, in state: inout UserState, now: Date = Date()) -> CheckInResult {
        guard fight.status != .cancelled else { return .eventCancelled }
        guard isSignedUp(fight.id, in: state) else { return .notSignedUp }
        guard state.fightAttendance[fight.id] == nil else { return .alreadyCheckedIn }
        guard fight.isCheckInOpen(at: now) else { return .windowClosed }

        let day = Day.today(now)
        state.fightAttendance[fight.id] = FightAttendance(
            fightId: fight.id,
            checkedInAt: now,
            localDate: day
        )

        // Same monthly quota an Event claim draws on (§EventClaimService) —
        // otherwise attending Fights would be an uncapped way around it. Read
        // the effective total so a stale month resets to zero first.
        let config = PointsConfiguration.default
        let usedThisMonth = state.effectiveMonthlyEventPoints(asOf: now)
        let remaining = max(0, config.monthlyEventPointsCap - usedThisMonth)
        let awarded = min(fight.attendancePoints, remaining)

        state.currentPoints += awarded
        state.monthlyEventPointsEarned = usedThisMonth + awarded
        state.monthlyEventPointsPeriod = DateKeys.monthKey(for: now)
        if !state.attendedEventIDs.contains(fight.id) {
            state.attendedEventIDs.append(fight.id)
        }

        return .checkedIn(pointsAwarded: awarded, wasCapped: awarded < fight.attendancePoints)
    }

    static func attendance(for fightId: String, in state: UserState) -> FightAttendance? {
        state.fightAttendance[fightId]
    }

    static func hasAttended(_ fightId: String, in state: UserState) -> Bool {
        state.fightAttendance[fightId] != nil
    }

    // MARK: - Reads

    /// PRD §4.7 — the list is chronological. No map, no distance filter in v1.
    static func upcoming(_ fights: [Fight], now: Date = Date()) -> [Fight] {
        fights
            .filter { $0.status == .published && $0.endsAt > now }
            .sorted { $0.startsAt < $1.startsAt }
    }

    static func signedUp(_ fights: [Fight], in state: UserState, now: Date = Date()) -> [Fight] {
        upcoming(fights, now: now).filter { isSignedUp($0.id, in: state) }
    }

    /// PRD §4.6 — attended Fights are archived permanently, newest first. This is the
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

    /// A check-in token for this `(user, event)` pair.
    ///
    /// **Not signed.** Phase 10 replaces this with something Security Rules can
    /// verify; until then it only needs to be unique and stable per signup, and
    /// the trust model is unchanged either way — §9.6 already accepts that a
    /// user can forge their own Vitality.
    private static func token(for fightId: String, in state: UserState) -> String {
        let user = state.displayName.isEmpty ? "Local user" : state.displayName
        return "\(tokenPrefix)|\(fightId)|\(user)|\(UUID().uuidString.prefix(8))"
    }

    static let tokenPrefix = "EHF"

    /// `EHF|<fightId>|<display name>|<nonce>`
    static func parseToken(_ raw: String) -> (fightId: String, attendeeLabel: String)? {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == tokenPrefix, !parts[1].isEmpty else { return nil }
        return (String(parts[1]), String(parts[2]))
    }

    // MARK: - Hosting (PRD §6.5.1)

    enum ScanResult: Equatable {
        case accepted(attendee: String)
        case duplicate(attendee: String)
        /// A valid token, but for somebody else's event.
        case wrongEvent
        case unreadable
        case windowClosed
        /// Separate from `windowClosed` so a host standing at a cancelled event
        /// is told that, rather than "check-in isn't open yet".
        case eventCancelled
    }

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

    /// PRD §6.5.1 — **cancelling is not deletion.** The event stays visible to
    /// anyone signed up, which is the whole point: they need to find out.
    @discardableResult
    static func cancel(_ fightId: String, in state: inout UserState) -> Bool {
        guard let index = state.hostedFights.firstIndex(where: { $0.id == fightId }),
              state.hostedFights[index].status != .cancelled else { return false }
        state.hostedFights[index].status = .cancelled
        return true
    }

    // MARK: - Scanning

    static func scans(for fightId: String, in state: UserState) -> [HostScan] {
        (state.hostScans[fightId] ?? []).sorted { $0.scannedAt > $1.scannedAt }
    }

    /// Records one scan on the host's device.
    ///
    /// This does **not** award the attendee any Vitality — that is a cross-user
    /// write with no server to authorise it (§9.3). The host's roster and the
    /// attendee's own credit stay separate until Phase 10. The one case where
    /// both happen is a single-device demo, handled by the caller.
    @discardableResult
    static func recordScan(
        _ raw: String,
        for fight: Fight,
        in state: inout UserState,
        now: Date = Date()
    ) -> ScanResult {
        guard let parsed = parseToken(raw) else { return .unreadable }
        guard parsed.fightId == fight.id else { return .wrongEvent }
        guard fight.status != .cancelled else { return .eventCancelled }
        // Covers drafts too: `isCheckInOpen` requires `.published`, and nobody
        // can have signed up to something that was never public.
        guard fight.isCheckInOpen(at: now) else { return .windowClosed }

        var existing = state.hostScans[fight.id] ?? []
        // The token is the identity, so a code scanned twice is one attendee.
        guard !existing.contains(where: { $0.token == raw }) else {
            return .duplicate(attendee: parsed.attendeeLabel)
        }

        existing.append(HostScan(
            fightId: fight.id,
            token: raw,
            attendeeLabel: parsed.attendeeLabel,
            scannedAt: now
        ))
        state.hostScans[fight.id] = existing
        return .accepted(attendee: parsed.attendeeLabel)
    }
}
