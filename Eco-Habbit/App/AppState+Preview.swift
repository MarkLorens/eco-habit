import Foundation

#if DEBUG
extension AppState {
    @MainActor
    static var preview: AppState {
        let state = AppState(data: .preview)
        
        // Seeding badge to prevent re-showing badges on announcedBadgesIDs empty
        // Guard to "catch up" in case we add new badges to the catalogue
        // Lemme know if any better alternative though
        MockData.badges.filter(state.isUnlocked).forEach(state.acknowledgeBadge)
        return state
}

    /// Baseline plus the first `count` habits of `category` already logged today,
    /// for checking the dimmed / disabled row treatment.
    @MainActor
    static func preview(completing category: HabitCategory, count: Int = 2) -> AppState {
        var data = PersistedState.preview
        data.logs = MockData.habits(in: category).prefix(count).map {
            HabitLog(habitId: $0.id, localDate: Day.today(), source: .checklist)
        }
        return AppState(data: data)
    }
    
    static func fromLaunchArguments() -> AppState? {
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: "EHDemo") else { return nil }

            let state = AppState.preview

            if defaults.string(forKey: "EHStage") == "login" { state.logOut() }

            switch defaults.string(forKey: "EHTab") {
            case "activity", "actions": state.selectedTab = .actions
            case "fights": state.selectedTab = .ourFights
            case "profile": state.selectedTab = .profile
            default: state.selectedTab = .home
            }
            return state
        }
}

extension PersistedState {
    /// Helper to preview profile from Tio
    static func preview(
        name: String = MockData.demoName,
        vitality: Int = 65,
        streak: Int = 12,
        longestStreak: Int = 18,
        actions: Int = 24,
        favourites: Set<HabitCategory> = [.waste, .energy, .water],
        notifications: Bool = true
    ) -> PersistedState {
        var state = PersistedState.preview
        state.userName = name
        state.vitality = vitality
        state.streakDays = streak
        state.longestStreak = longestStreak
        state.favouriteCategories = favourites
        state.notificationsEnabled = notifications

        let catalogue = MockData.habits.sorted { $0.isFoundation && !$1.isFoundation }
        state.logs = (0..<max(0, actions)).map { i in
            let habit = catalogue[i % catalogue.count]
            return HabitLog(
                habitId: habit.id,
                localDate: Day.adding(-(i / 4), to: Day.today()) ?? Day.today(),
                source: i.isMultiple(of: 5) ? .visualSearch : .checklist
            )
        }
        return state
    }

    /// The seeded baseline every preview starts from.
    static var preview: PersistedState {
        var state = PersistedState()
        state.isLoggedIn = true
        state.userName = MockData.demoName
        state.email = MockData.demoEmail
        state.favouriteCategories = [.waste, .energy, .water]
        state.vitality = 65
        state.streakDays = 12
        state.longestStreak = 18
        return state
    }
}
#endif
