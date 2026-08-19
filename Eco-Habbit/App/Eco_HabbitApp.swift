import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}


@main
struct Eco_HabbitApp: App {
    @StateObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        FontLoader.registerBundledFonts()
        // The one place the real sync is chosen. Previews, tests and the offline demo
        // build an AppState without it and stay entirely local.
        let sync = FirebaseUserStateSync()
        #if DEBUG
        _appState = StateObject(wrappedValue: AppState.fromLaunchArguments()
                                ?? AppState(sync: sync))
        #else
        _appState = StateObject(wrappedValue: AppState(sync: sync))
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
                    guard phase == .active else { return }
                    appState.evaluateIfNeeded()
                    // A launch with no signal should reconcile as soon as there is one,
                    // rather than staying local until the next cold start.
                    appState.retrySyncIfNeeded()
                }
        }
    }
}
