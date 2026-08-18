import Foundation

#if DEBUG
extension AppState {
    /// Launch-argument hooks for screenshots and QA. Release ignores all of it.
    ///
    ///     -EHDemo 1                              seed a mid-game account
    ///     -EHTab home|actions|ourFights|profile  pick the tab
    ///
    /// `-EHStage login` is gone — there is no sign-in screen while `userId` is
    /// fixed at "demo-user". It returns with Firebase Auth.
    static func fromLaunchArguments() -> AppState? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "EHDemo") else { return nil }

        let state = AppState.preview

        switch defaults.string(forKey: "EHTab") {
        case "activity", "actions": state.selectedTab = .actions
        case "fights", "ourFights": state.selectedTab = .ourFights
        case "profile": state.selectedTab = .profile
        default: state.selectedTab = .home
        }
        return state
    }

    /// In-memory so previews never touch the real store. `seedDemoDataIfEmpty`
    /// then supplies `MockUserStateData.demo` on bootstrap — 1,200 points,
    /// streak 30, Recovering.
    @MainActor
    static var preview: AppState {
        AppState(store: InMemoryKeyValueStore(), seedDemoDataIfEmpty: true)
    }
}
#endif
