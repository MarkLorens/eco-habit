import Foundation

#if DEBUG
extension AppState {
    @MainActor
    static var preview: AppState { AppState(data: .preview) }

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

//    @MainActor
//    static var preview: AppState {
//        var state = PersistedState()
//        state.isLoggedIn = true
//        state.userName = MockData.demoName
//        state.email = MockData.demoEmail
//        state.favouriteCategories = [.waste, .energy, .water]
//        state.vitality = 65
//        state.streakDays = 12
//        state.longestStreak = 18
//        return AppState(data: state)
//    }
}

extension PersistedState {
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
