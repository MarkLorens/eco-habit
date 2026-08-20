import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.C.bg.ignoresSafeArea()

            Group {
                switch app.selectedTab {
                case .home: HomeView()
                case .actions: ActivityListView()
                // One Fights screen for everyone. An organisation gets a "My Fights"
                // segment and a plus button inside it, rather than a separate view —
                // a host still browses other people's events like anybody else, and
                // two screens would be two things to keep in step.
                case .ourFights: CustomerFightListView()
                case .profile: ProfileView()
                }
            }
            if app.selectedTab != .actions || app.actionsPath.isEmpty {
                AppTabBar(
                    selection: $app.selectedTab,
                    onCapture: { app.isCameraPresented = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.actionsPath.isEmpty)
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $app.isCameraPresented) {
            VisualSearchView()
        }
    }
}

/// Every tab's scroll view uses this so content clears the floating tab bar.
extension View {
    func tabContentInsets() -> some View {
        self.padding(.bottom, 110)
    }
}
