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
                    if phase == .active { appState.evaluateIfNeeded() }
                }
        }
    }
}
