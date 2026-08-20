import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Tokens.Palette.white

            Group {
                switch app.selectedTab {
                case .home: HomeView()
                case .actions: ActivityListView()
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
