import SwiftUI

@main
struct Eco_HabbitApp: App {
    @StateObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontLoader.registerBundledFonts()
        #if DEBUG
        _appState = StateObject(wrappedValue: AppState.fromLaunchArguments() ?? AppState())
        #else
        _appState = StateObject(wrappedValue: AppState())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .task(priority: .background) {
                    // Warm the Core ML model while the user is looking at the
                    // dashboard. Loading 68 MB takes seconds on first use, and
                    // paying that when the camera opens makes the camera look
                    // broken. `shared` is a `static let`, so this is the only
                    // time it happens.
                    _ = HabitClassifier.shared
                }
                .onChange(of: scenePhase) { _, phase in
                    // Decay is computed on app open, not by a background job.
                    if phase == .active { Task { await appState.bootstrap() } }
                }
        }
    }
}
