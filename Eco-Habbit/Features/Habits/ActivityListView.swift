import SwiftUI

struct ActivityListView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack(path: $app.actionsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack{
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm){
                            Text("Daily Practices")
                                .textStyle(Tokens.Typography.hero)
                                .foregroundStyle(Tokens.Semantic.text)
                            
                            Text("Choose a category to see suggested actions")
                                .textStyle(Tokens.Typography.footnote)
                                .foregroundStyle(Tokens.Semantic.footnote)
                        }
                        Spacer()
                        NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .camera){
                            app.isCameraPresented = true
                        }
                    }
                    .padding(.horizontal, Tokens.Spacing.xxl)
                    .padding(.top, Tokens.Spacing.lg)
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: Tokens.Spacing.md), GridItem(.flexible())],
                        spacing: Tokens.Spacing.xl
                    ){
                        ForEach(sortedCategories) { category in
                            NavigationLink(value: category) {
                                Cards(
                                    title: category.title,
                                    caption: category.caption,
                                    icon: category.icon,
                                    background: category.background,
                                    tint: category.tint
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Tokens.Spacing.xxl)
                }
                .tabContentInsets()
            }
            .background(Tokens.Palette.white)
            .statusBarCover()
            .navigationDestination(for: HabitCategory.self) { category in
                CategoryDetailView(category: category)
            }
        }
    }

    private var sortedCategories: [HabitCategory] {
        HabitCategory.allCases.sorted { lhs, rhs in
            let l = app.favouriteCategories.contains(lhs)
            let r = app.favouriteCategories.contains(rhs)
            if l != r { return l }
            return lhs.rawValue < rhs.rawValue
        }
    }
}

// `#Preview` compiles in RELEASE too, and AppState.preview /
// PersistedState.preview are `#if DEBUG`. Without this guard the
// archive build fails — which is what blocks TestFlight.
#if DEBUG
#Preview {
    ActivityListView()
        .environmentObject(AppState.preview)
}
#endif
