import Foundation

#if DEBUG
extension AppState {
    static func fromLaunchArguments() -> AppState? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "EHDemo") else { return nil }

        let state = AppState.preview

        if defaults.string(forKey: "EHStage") == "login" { state.logOut() }

        switch defaults.string(forKey: "EHTab") {
        case "activity": state.selectedTab = .activity
        case "fights": state.selectedTab = .fights
        case "profile": state.selectedTab = .profile
        default: state.selectedTab = .home
        }
        return state
    }

    @MainActor
    static var preview: AppState {
        var state = PersistedState()
        state.isLoggedIn = true
        state.userName = MockData.demoName
        state.email = MockData.demoEmail
        state.favouriteCategories = [.waste, .transport, .water]
        state.vitality = 65
        state.streakDays = 12
        state.longestStreak = 18
        return AppState(data: state)
    }
}
#endif
