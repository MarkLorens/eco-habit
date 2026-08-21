import Foundation

#if DEBUG
extension AppState {
    @MainActor
    /// The id previews and the `-EHDemo` launch path sign in as.
    ///
    /// `isLoggedIn` is derived from `userId` now, so a preview with no id would render
    /// the sign-in screen instead of the app. This keeps every preview and the offline
    /// demo working without any of them touching Firebase.
    static let previewUserId = "preview"

    static var preview: AppState {
        let state = AppState(userId: previewUserId, data: .preview)
        
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

            let stage = defaults.string(forKey: "EHStage")

            // `-EHStage onboarding` starts the demo account before the questions.
            // Seeded state is onboarded by default, so this is the only way to reach
            // the flow without a real first-time sign-in.
            var seed = PersistedState.preview
            if stage == "onboarding" { seed.hasCompletedOnboarding = false }
            // `previewUserId` matters: `isLoggedIn` derives from `userId`, so building
            // this without one drops the demo straight onto the sign-in screen.
            let state = AppState(userId: previewUserId, data: seed)
            MockData.badges.filter(state.isUnlocked).forEach(state.acknowledgeBadge)

            if stage == "login" { state.logOut() }

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
        // The parameter is still a 0–100 reading, because that is how every
        // preview call site reads. Converted to the points that produce it, so
        // the derived `vitality` comes back out at the number asked for.
        state.currentPoints = PersistedState.points(forVitality: vitality)
        state.streakDays = streak
        state.longestStreak = longestStreak
        state.favouriteCategories = favourites
        state.notificationsEnabled = notifications

        // Was foundations-first; that ordering went with the old catalogue.
        // Cheapest-first keeps the seeded history looking like a real ramp-up.
        let catalogue = MockData.habits.sorted { $0.basePoints < $1.basePoints }
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
        // Seeded accounts are past onboarding — otherwise every demo launch and every
        // preview of the app shell opens on the questions instead of the screen under
        // test. Flip this to false to work on the flow itself.
        state.hasCompletedOnboarding = true
        state.userName = MockData.demoName
        state.email = MockData.demoEmail
        state.favouriteCategories = [.waste, .energy, .water]
        state.currentPoints = PersistedState.points(forVitality: 65)
        state.streakDays = 12
        state.longestStreak = 18
        return state
    }

    /// Inverse of `AppState.vitality`, for fixtures written in the old 0–100 terms.
    static func points(forVitality vitality: Int) -> Int {
        PointsConfiguration.default.threshold(for: .restored) * vitality / 100
    }
}
#endif
