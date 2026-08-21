import Foundation

/// A catalogue entry, loaded from `Resources/habits.json` and never mutated by
/// the app. Per-day state lives in `HabitLog`, so the checklist, the camera and
/// the dashboard all read one source of truth.
///
/// **This is Tio's `Activity` shape under main's name.** The economy it feeds is
/// friction-based: four effort bands (F1–F4) worth 5/10/15/20 base points, an
/// evidence strength that decides what the camera can be expected to recognise,
/// and an optional cooldown. The previous three-tier / `frequency` shape went
/// with the engine that read it.
///
/// `basePoints` is stored rather than computed so an award already granted stays
/// recorded as it was if the friction table is ever retuned — and so a one-off
/// bonus action can override it.
struct Habit: Identifiable, Codable, Hashable {

    // MARK: - Catalogue definition

    /// Stable slug, e.g. `"food_reusable_bottle"`. Referenced by user progress,
    /// so it must never be regenerated at launch.
    let id: String
    let name: String
    let category: HabitCategory
    let frictionLevel: FrictionLevel
    let basePoints: Int
    let evidenceStrength: EvidenceStrength

    /// One line of "why this matters", for the dashboard's recommendation card.
    ///
    /// Optional and **absent from `habits.json` today** — writing 38 lines of
    /// user-facing copy is a content decision, not a code one. `detailOrCaption`
    /// falls back to the category's own line so the card is never blank, and filling
    /// the field in for a habit is then a one-key edit with no code change.
    let detail: String?

    /// Minimum gap before this may be logged again. `nil` = loggable daily.
    let cooldownDays: Int?

    // MARK: - User progress

    /// The last log carried a photo. Feeds the evidence badges.
    var hasEvidence: Bool

    /// Single source for "done today?" and for the cooldown.
    var lastCompletedDate: Date?

    /// Whether the camera stands any chance with this one. Derived rather than
    /// stored: it is a restatement of `evidenceStrength`, and two fields that
    /// must agree are one field too many.
    var isCameraDetectable: Bool { evidenceStrength != .notDetectable }

    /// What a card shows under the title. The catalogue's own line when it has one,
    /// the category's otherwise.
    var detailOrCaption: String {
        // The category caption is authored as two lines for the Practices grid, and the
        // break is doing the work of punctuation — "Safe energy / Power a better future".
        // Joined with a space it reads as one broken sentence, so it becomes a dash.
        detail ?? category.caption.replacingOccurrences(of: "\n", with: " — ")
    }

    init(
        id: String,
        name: String,
        category: HabitCategory,
        frictionLevel: FrictionLevel,
        evidenceStrength: EvidenceStrength,
        detail: String? = nil,
        cooldownDays: Int? = nil,
        basePoints: Int? = nil,
        hasEvidence: Bool = false,
        lastCompletedDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.frictionLevel = frictionLevel
        self.evidenceStrength = evidenceStrength
        self.detail = detail
        self.cooldownDays = cooldownDays
        self.basePoints = basePoints ?? frictionLevel.basePoints
        self.hasEvidence = hasEvidence
        self.lastCompletedDate = lastCompletedDate
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case id, name, category, frictionLevel, basePoints
        case evidenceStrength, detail, cooldownDays, hasEvidence, lastCompletedDate
    }

    /// Hand-written so the bundled catalogue can carry **definition only**.
    /// `habits.json` has no `hasEvidence` or `lastCompletedDate` — those are
    /// per-user progress, and a shared catalogue holds nobody's progress.
    /// Synthesised decoding would demand them and fail.
    ///
    /// `basePoints` is optional in the file too: omit it and the friction level
    /// supplies it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(HabitCategory.self, forKey: .category)
        frictionLevel = try c.decode(FrictionLevel.self, forKey: .frictionLevel)
        evidenceStrength = try c.decode(EvidenceStrength.self, forKey: .evidenceStrength)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        cooldownDays = try c.decodeIfPresent(Int.self, forKey: .cooldownDays)
        basePoints = try c.decodeIfPresent(Int.self, forKey: .basePoints)
            ?? frictionLevel.basePoints
        hasEvidence = try c.decodeIfPresent(Bool.self, forKey: .hasEvidence) ?? false
        lastCompletedDate = try c.decodeIfPresent(Date.self, forKey: .lastCompletedDate)
    }

    // MARK: - Derived state

    /// Computed, not a stored flag — a stored one goes stale over midnight.
    var isCompletedToday: Bool { isCompleted(on: Date()) }

    /// Injectable date and calendar, for tests.
    func isCompleted(on referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let lastCompletedDate else { return false }
        return calendar.isDate(lastCompletedDate, inSameDayAs: referenceDate)
    }

    /// Cooldown days remaining; `0` means it may be logged now.
    ///
    /// Measured in calendar days (`startOfDay`) rather than elapsed hours, so it
    /// does not depend on what time of day the previous log happened.
    func cooldownRemainingDays(asOf referenceDate: Date = Date(),
                               calendar: Calendar = .current) -> Int {
        guard let cooldownDays, let lastCompletedDate else { return 0 }
        let lastDay = calendar.startOfDay(for: lastCompletedDate)
        let currentDay = calendar.startOfDay(for: referenceDate)
        let daysPassed = calendar.dateComponents([.day], from: lastDay, to: currentDay).day ?? 0
        // max(0,) also covers a lastCompletedDate in the future (device clock changed).
        return max(0, cooldownDays - daysPassed)
    }

    func isOnCooldown(asOf referenceDate: Date = Date(),
                      calendar: Calendar = .current) -> Bool {
        cooldownRemainingDays(asOf: referenceDate, calendar: calendar) > 0
    }
}

// MARK: - Logs

/// One completion. Authoritative — every number in the app is derived from these,
/// and a derived total is never stored.
///
/// **Carries the points breakdown as it was awarded.** Recomputing a past log's
/// value from today's config would let a retune of the friction table, or the
/// user's streak moving, silently rewrite history. What was earned was earned.
struct HabitLog: Codable, Hashable, Identifiable {
    var id = UUID()
    let habitId: String
    /// Written at log time, never re-derived from `loggedAt`.
    let localDate: String
    let loggedAt: Date
    let source: Source

    // MARK: - Points, frozen at log time

    /// What the habit is worth before the daily cap.
    let basePoints: Int
    /// What actually counted against the cap — less than `basePoints` on the log
    /// that crosses the ceiling. This, not `basePoints`, is what spends the day's
    /// allowance, or a capped log would eat quota it never received credit for.
    let countedBasePoints: Int
    let evidenceBonus: Double
    let streakMultiplier: Double
    let priorityMultiplier: Double
    /// The number the user was actually shown.
    let finalPoints: Int

    var wasCappedByDailyLimit: Bool { countedBasePoints < basePoints }

    init(id: UUID = UUID(),
         habitId: String,
         localDate: String,
         loggedAt: Date = Date(),
         source: Source,
         breakdown: PointsBreakdown? = nil) {
        self.id = id
        self.habitId = habitId
        self.localDate = localDate
        self.loggedAt = loggedAt
        self.source = source
        self.basePoints = breakdown?.basePoints ?? 0
        self.countedBasePoints = breakdown?.countedBasePoints ?? 0
        self.evidenceBonus = breakdown?.evidenceBonus ?? 1
        self.streakMultiplier = breakdown?.streakMultiplier ?? 1
        self.priorityMultiplier = breakdown?.priorityMultiplier ?? 1
        self.finalPoints = breakdown?.finalPoints ?? 0
    }

    enum Source: String, Codable {
        case checklist
        case visualSearch
        case fightCheckIn
    }

    // MARK: - Decoding

    private enum CodingKeys: String, CodingKey {
        case id, habitId, localDate, loggedAt, source
        case basePoints, countedBasePoints, evidenceBonus
        case streakMultiplier, priorityMultiplier, finalPoints
    }

    /// Hand-written because the points fields are new. Synthesized `Decodable`
    /// ignores property defaults and throws `keyNotFound` on a missing key, so a
    /// log saved before this existed would fail to decode and take the whole
    /// `PersistedState` with it. `decodeIfPresent` reads those as zero instead.
    ///
    /// A pre-existing log therefore scores 0. That is already true regardless:
    /// the catalogue ids changed with the friction catalogue, so an old log
    /// points at a habit that is no longer there.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        habitId = try c.decode(String.self, forKey: .habitId)
        localDate = try c.decode(String.self, forKey: .localDate)
        loggedAt = try c.decode(Date.self, forKey: .loggedAt)
        source = try c.decode(Source.self, forKey: .source)
        basePoints = try c.decodeIfPresent(Int.self, forKey: .basePoints) ?? 0
        countedBasePoints = try c.decodeIfPresent(Int.self, forKey: .countedBasePoints) ?? 0
        evidenceBonus = try c.decodeIfPresent(Double.self, forKey: .evidenceBonus) ?? 1
        streakMultiplier = try c.decodeIfPresent(Double.self, forKey: .streakMultiplier) ?? 1
        priorityMultiplier = try c.decodeIfPresent(Double.self, forKey: .priorityMultiplier) ?? 1
        finalPoints = try c.decodeIfPresent(Int.self, forKey: .finalPoints) ?? 0
    }
}

/// Catalogue entry joined with today's state — what a list row renders.
struct HabitRow: Identifiable, Hashable {
    let habit: Habit
    let log: HabitLog?

    var id: String { habit.id }
    var isCompletedToday: Bool { log != nil }
}
