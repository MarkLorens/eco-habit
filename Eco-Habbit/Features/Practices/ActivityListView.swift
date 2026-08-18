import SwiftUI

/// Mark's category grid, ported verbatim — only `HabitCategory` became `Category`.
///
/// `Category.title`, `.caption`, `.icon`, `.background` and `.tint` were added to
/// `Category+Presentation` so this file did not need editing; the strings and
/// colours they return are the ones his version showed.
struct ActivityListView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack(path: $app.actionsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.sm){
                        Text("Daily Practices")
                            .textStyle(Tokens.Typography.hero)
                            .foregroundStyle(Tokens.Semantic.text)
                        
                        Text("Choose a category to see suggested actions")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                    }
                    .padding(.horizontal, Tokens.Spacing.xxl)
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
                    .padding(Tokens.Spacing.md)
                }
            }
            .background(Tokens.Palette.white)
            .navigationDestination(for: Category.self) { category in
                CategoryDetailView(category: category)
            }
        }
    }

    private var sortedCategories: [Category] {
        Category.allCases.sorted { lhs, rhs in
            let l = app.favouriteCategories.contains(lhs)
            let r = app.favouriteCategories.contains(rhs)
            if l != r { return l }
            return lhs.rawValue < rhs.rawValue
        }
    }
}

#if DEBUG
#Preview {
    ActivityListView()
        .environmentObject(AppState.preview)
}
#endif
