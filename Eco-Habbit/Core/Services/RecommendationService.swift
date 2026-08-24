import Foundation

struct RecommendationService {

    /// Deliberately injectable. These numbers are a product judgement, not a fact, and
    /// the only way to retune them honestly is to be able to try other values.
    struct Weights {
        /// Chose this category during onboarding, or in Settings later.
        var categoryAffinity: Double = 3
        /// How close the habit's friction is to the effort level they asked for.
        var effortFit: Double = 2
        /// Never logged. Nudges the catalogue's long tail into view.
        var novelty: Double = 1
        /// Full penalty for something logged today-ish, fading out over `recencyWindow`.
        var recency: Double = 2
        /// Days over which the recency penalty decays to nothing.
        var recencyWindow: Double = 7
        /// Stops five cards from being five variations of one category. The deck is
        /// meant to read as "here is your day", not "here is the waste tab again".
        var maxPerCategory: Int = 2
    }

    var weights = Weights()

    func recommend(from catalogue: [Habit],
                   state: PersistedState,
                   today: String = Day.today(),
                   now: Date = Date(),
                   limit: Int = 5) -> [Habit] {

        let available = catalogue.filter { HabitRepository.isAvailable($0, on: today, in: state) }
        guard !available.isEmpty else { return [] }

        let lastLogged = mostRecentLogDates(in: state)
        var scored: [(habit: Habit, score: Double)] = []
        scored.reserveCapacity(available.count)
        for habit in available {
            scored.append((habit, score(habit, state: state, lastLogged: lastLogged, now: now)))
        }
        scored.sort { left, right in
            left.score == right.score ? left.habit.id < right.habit.id : left.score > right.score
        }

        return diversified(scored.map(\.habit), limit: limit)
    }

    // MARK: - Scoring

    private func score(_ habit: Habit,
                       state: PersistedState,
                       lastLogged: [String: Date],
                       now: Date) -> Double {
        var total = 0.0

        if state.favouriteCategories.contains(habit.category) {
            total += weights.categoryAffinity
        }

        // No answer yet — an account from before the question existed, or one that
        // skipped it. Contributing nothing is right: it must not quietly favour the
        // easy end, which is what defaulting to `.easy` would do.
        if let effort = state.preferredEffort {
            total += weights.effortFit * effort.fit(habit.frictionLevel)
        }

        if let last = lastLogged[habit.id] {
            // Linear decay to zero across the window. Something done yesterday is a
            // dull suggestion; the same thing three weeks ago is a fine one.
            let days = Double(DateKeys.dayDifference(from: last, to: now))
            let staleness = max(0, 1 - days / weights.recencyWindow)
            total -= weights.recency * staleness
        } else {
            total += weights.novelty
        }

        return total
    }

    /// Most recent log per habit, in one pass rather than a filter per habit.
    private func mostRecentLogDates(in state: PersistedState) -> [String: Date] {
        state.logs.reduce(into: [:]) { seen, log in
            if let existing = seen[log.habitId], existing >= log.loggedAt { return }
            seen[log.habitId] = log.loggedAt
        }
    }

    // MARK: - Diversity

    /// Take best-first while honouring the per-category cap, then top up from whatever
    /// was passed over if the cap left the deck short.
    ///
    /// The top-up matters more than the cap does. A user who picked one category during
    /// onboarding scores everything else near zero, and without this pass they would be
    /// handed two cards instead of five.
    private func diversified(_ ranked: [Habit], limit: Int) -> [Habit] {
        var taken: [Habit] = []
        var perCategory: [HabitCategory: Int] = [:]
        var passedOver: [Habit] = []

        for habit in ranked where taken.count < limit {
            let used = perCategory[habit.category, default: 0]
            if used < weights.maxPerCategory {
                taken.append(habit)
                perCategory[habit.category] = used + 1
            } else {
                passedOver.append(habit)
            }
        }

        if taken.count < limit {
            taken += passedOver.prefix(limit - taken.count)
        }
        return taken
    }
}
