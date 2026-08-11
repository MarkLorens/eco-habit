import SwiftUI

@main
struct Eco_HabbitApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
<<<<<<< Updated upstream:Eco-Habbit/Eco-Habbit/Eco_HabbitApp.swift
=======
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
                    if phase == .active { appState.evaluateIfNeeded() }
                }
>>>>>>> Stashed changes:Eco-Habbit/App/Eco_HabbitApp.swift
        }
    }
}
