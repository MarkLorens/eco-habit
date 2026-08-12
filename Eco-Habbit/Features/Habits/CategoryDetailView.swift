import SwiftUI

struct CategoryDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let category: HabitCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.bottom, Tokens.Spacing.xl)
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
            ScrollView {
                VStack{
                    ForEach(app.rows(in: category)) { row in
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
        }
        .background(category.tint.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            CircleIconButton(systemName: "chevron.left") { dismiss() }
            Text(category.title)
                .foregroundStyle(Tokens.Semantic.text)
                .textStyle(Tokens.Typography.hero)
            Text(category.caption)
                .foregroundStyle(Tokens.Semantic.footnote)
                .textStyle(Tokens.Typography.footnote)
        }
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
        CategoryDetailView(category: .energy)
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
