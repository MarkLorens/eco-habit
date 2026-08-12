import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var app: AppState

    /// Owned here rather than inside `DailyPracticesView`, because the tab bar
    /// has to disappear while a category detail is open — that screen is
    /// full-bleed in the Sketch. This is the same arrangement Tio used on the
    /// MockData branch, where `RootView` held the path for the same reason.
    @State private var categoryPath: [Category] = []

    private var isShowingDetail: Bool { !categoryPath.isEmpty }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.C.bg.ignoresSafeArea()

            Group {
                switch app.selectedTab {
                case .home:
                    DashboardView()

                case .actions:
                    // Only this tab gets a stack from here. `FightListView` and
                    // `ProfileView` own their own `NavigationStack`s, and a
                    // stack nested inside a `navigationDestination` renders
                    // blank and pops straight back out.
                    NavigationStack(path: $categoryPath) {
                        DailyPracticesView(onSelectCategory: { categoryPath.append($0) })
                            .navigationDestination(for: Category.self) { category in
                                CategoryDetailView(category: category)
                                    .navigationBarBackButtonHidden()
                            }
                    }

                case .ourFights:
                    FightListView()

                case .profile:
                    ProfileView()
                }
            }

            if !isShowingDetail {
                AppTabBar(
                    selection: $app.selectedTab,
                    onCapture: { app.isCameraPresented = true }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: isShowingDetail)
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $app.isCameraPresented) {
            VisualSearchView()
        }
        // Leaving the tab shouldn't strand you inside a category on return.
        .onChange(of: app.selectedTab) { _, _ in categoryPath.removeAll() }
    }
}

/// Every tab's scroll view uses this so content clears the floating tab bar.
extension View {
    func tabContentInsets() -> some View {
        self.padding(.bottom, 110)
    }
}
