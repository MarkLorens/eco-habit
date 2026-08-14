import SwiftUI

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let category: HabitCategory
    @State private var headerHeight: CGFloat = 0
    private let sheetTail: CGFloat = 56
    
    @State private var searchText = ""
    
    var filteredActivity: [HabitRow] {
        let rows = app.rows(in: category)
        
        guard !searchText.isEmpty else {
            return rows
        }
        
        return rows.filter {
            $0.habit.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.sm) {
                if filteredActivity.isEmpty {
                    noMatches
                        .frame(minHeight: 400, alignment: .center)
                } else {
                    ForEach(filteredActivity) { row in
                        ActivityListCard(title: row.habit.name,
                                         points: PointsEngine.tierPoints(row.habit.tier),
                                         icon: category.icon,
                                         tint: category.tint,
                                         background: category.background,
                                         isChecked: row.isCompletedToday,
                                         onToggle: { toggle(row) }
                        )
                    }
                }
            }
            .padding(Tokens.Spacing.md)
            .padding(.top, headerHeight)
        }
        .safeAreaInset(edge: .bottom){
            AppSearchBar(text: $searchText)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.md)
        }
        .background(alignment: .top) {
            UnevenRoundedRectangle(
                bottomLeadingRadius: 40,
                bottomTrailingRadius: 40,
                style: .continuous
            )
            .fill(Tokens.Palette.white)
            .frame(height: headerHeight + sheetTail)
        }
        .overlay(alignment: .top) {
            header
                .padding(.horizontal, Tokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 40,
                        bottomTrailingRadius: 40,
                        style: .continuous
                    )
                    .fill(Tokens.Palette.white)
                    .ignoresSafeArea(edges: .top)
                )
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HeaderHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                )
        }
        .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
        .background(category.tint.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
    

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                NavigateButton(background: Tokens.Semantic.buttonTintDefault, direction: .left){ dismiss() }
                Text(category.title)
                    .foregroundStyle(Tokens.Semantic.text)
                    .textStyle(Tokens.Typography.hero)
                Text(category.caption)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .textStyle(Tokens.Typography.footnote)
            }
            Spacer(minLength: Tokens.Spacing.sm)
            Image(category.iconDetail)
                .resizable()
                .scaledToFit()
                .frame(width: 130 * category.iconScale, height: 130 * category.iconScale)
        }
        .padding([.horizontal], Tokens.Spacing.sm)
    }

    // For empty search
    private var noMatches: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .textStyle(Tokens.Typography.icon)
                .foregroundStyle(Tokens.Semantic.footnote)

            Text("We can't seem to find “\(searchText)”")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)
                .multilineTextAlignment(.center)

            Text("Try a shorter word, or clear the search to see all \(app.rows(in: category).count).")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Tokens.Spacing.xl)
    }

    private func toggle(_ row: HabitRow) {
        // Same-day undo (PRD §3.4) — tapping a completed row takes it back.
        if row.isCompletedToday {
            app.revertTodaysLog(habitId: row.habit.id)
            app.toast = Toast(kind: .info, message: "Removed \(row.habit.name).")
        } else {
            app.logAndToast(row.habit, source: .checklist)
        }
    }
}

#if DEBUG
#Preview("Category detail") {
    NavigationStack {
        CategoryDetailView(category: .actions)
    }
    .environmentObject(AppState.preview)
}

#Preview("With completions") {
    NavigationStack {
        CategoryDetailView(category: .energy)
    }
    .environmentObject(AppState.preview(completing: .energy))
}

#Preview("Long habit names") {
    NavigationStack {
        CategoryDetailView(category: .consumption)
    }
    .environmentObject(AppState.preview)
    .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
