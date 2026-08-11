import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.C.bg.ignoresSafeArea()

            Group {
                switch app.selectedTab {
                case .home: HomeView()
                case .activity: ActivityListView()
                case .fights: FightListView()
                case .profile: ProfileView()
                }
            }

            EHTabBar(
                selection: $app.selectedTab,
                onCamera: { app.isCameraPresented = true }
            )
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $app.isCameraPresented) {
            VisualSearchView()
        }
    }
}

struct EHTabBar: View {
    @Binding var selection: AppTab
    let onCamera: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            item(.home, symbol: "house", label: "Home")
            item(.activity, symbol: "square.grid.2x2", label: "Activity")

            Button(action: onCamera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Theme.C.accent500))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: Theme.C.accent.opacity(0.4), radius: 10, x: 0, y: 10)
            }
            .buttonStyle(PlainPressStyle())
            .frame(maxWidth: .infinity)
            .offset(y: -24)
            .accessibilityLabel("Log an action with the camera")

            item(.fights, symbol: "figure.2.arms.open", label: "Fights")
            item(.profile, symbol: "person.crop.circle", label: "Profile")
        }
        .padding(.top, 10)
        .frame(height: 62, alignment: .top)
        .padding(.bottom, 4)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(.white.opacity(0.72))
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.C.neutral200).frame(height: 1)
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ tab: AppTab, symbol: String, label: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(symbol).fill" : symbol)
                    .font(.system(size: 19, weight: .medium))
                    .symbolVariant(.none)
                Text(label)
                    .font(Theme.F.body(10.5, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Theme.C.accent600 : Theme.C.neutral500)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainPressStyle())
    }
}

extension View {
    func tabContentInsets() -> some View {
        self.padding(.bottom, 110)
    }
}
