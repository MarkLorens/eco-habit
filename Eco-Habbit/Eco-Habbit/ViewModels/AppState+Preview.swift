import Foundation

#if DEBUG
extension AppState {
    /// Screenshot/QA hook. Launch with `-EHDemo 1` to start from the seeded mid-game
    /// account, plus optionally:
    ///   `-EHStage login|onboarding|app`  which flow to open on
    ///   `-EHTab home|activity|redeem|profile`  which tab to land on
    /// Debug builds only — release builds always boot from the real on-disk state.
    static func fromLaunchArguments() -> AppState? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "EHDemo") else { return nil }

        let state = AppState.preview

        switch defaults.string(forKey: "EHStage") {
        case "login": state.logOut()
        case "onboarding": state.reopenOnboarding()
        default: break
        }

        switch defaults.string(forKey: "EHTab") {
        case "activity": state.selectedTab = .activity
        case "redeem": state.selectedTab = .redeem
        case "profile": state.selectedTab = .profile
        default: state.selectedTab = .home
        }
        return state
    }

    /// A mid-game account for Xcode previews — never touches the on-disk state.
    @MainActor
    static var preview: AppState {
        var state = PersistedState()
        state.isLoggedIn = true
        state.hasCompletedOnboarding = true
        state.userName = MockData.demoName
        state.email = MockData.demoEmail
        state.motivations = [.planet, .health]
        state.favouriteCategories = [.waste, .mobility, .water]
        state.earthPoints = 1_650
        state.rewardPoints = 1_190
        state.lifetimeEarthPoints = 1_650
        state.streakDays = 12
        state.longestStreak = 18
        state.lastActiveDay = Calendar.current.startOfDay(for: Date())
        state.history = (0..<14).map { index in
            let activity = MockData.activities[index % MockData.activities.count]
            return HistoryEntry(
                id: UUID(),
                title: activity.name,
                categoryRaw: activity.category.rawValue,
                points: activity.basePoints,
                date: Calendar.current.date(byAdding: .hour, value: -index * 7, to: Date()) ?? Date(),
                sourceRaw: index.isMultiple(of: 3) ? "camera" : "checklist",
                completionId: nil
            )
        }
        return AppState(data: state)
    }
}
#endif
