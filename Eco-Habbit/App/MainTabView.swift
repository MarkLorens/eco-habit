import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    /// An organisation runs events. It has no habits to log, so Home, Practices and the
    /// camera are not just empty for it — they are not its app.
    private var tabs: [AppTab] {
        app.isOrganization ? [.ourFights, .profile] : AppTab.allCases
    }

    /// What to actually draw. A stored `selectedTab` of `.home` — the default, or left
    /// over from before the account was verified — would otherwise render a dashboard
    /// with no tab to leave by.
    private var activeTab: AppTab {
        tabs.contains(app.selectedTab) ? app.selectedTab : .ourFights
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Tokens.Palette.white

            Group {
                switch activeTab {
                case .home: HomeView()
                case .actions: ActivityListView()
                // One Fights screen for both audiences: a person browses and checks in,
                // an organisation sees only its own events. Two files would be two
                // things to keep in step.
                case .ourFights: CustomerFightListView()
                // An organiser has no streak, vitality, badges or Earth — showing
                // those as permanent zeroes reads as a broken account rather than a
                // different kind of one.
                case .profile:
                    if app.isOrganization {
                        OrganisationProfileView()
                    } else {
                        ProfileView()
                    }
                }
            }
            if activeTab != .actions || app.actionsPath.isEmpty {
                AppTabBar(
                    selection: $app.selectedTab,
                    tabs: tabs,
                    showsCapture: !app.isOrganization,
                    // Two tabs stretched across a phone leave a lake of black between
                    // them; the hi-fi shows a small centred pill.
                    fillsWidth: !app.isOrganization,
                    onCapture: { app.isCameraPresented = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.actionsPath.isEmpty)
        .ignoresSafeArea(.keyboard)
        // Writes the correction back, so the selected pill matches what is on screen.
        // `activeTab` alone would leave the bar highlighting a tab it no longer draws.
        .onChange(of: app.isOrganization, initial: true) { _, _ in
            if !tabs.contains(app.selectedTab) { app.selectedTab = activeTab }
        }
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
