import SwiftUI

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Mark's category screen — tinted page, rounded header sheet, big category art,
/// `ActivityListCard` rows and the floating search bar — carrying this branch's
/// pricing.
///
/// **What is his:** every measurement, colour and control below. The layout is a
/// straight port, including the header-height preference trick that lets the
/// scroll content start beneath a sheet whose height nobody hardcoded.
///
/// **What is kept from here:** only the number on each row. His version showed
/// `PointsEngine.tierPoints(...)`, a fixed value per tier; rows here are priced
/// through `points(for:)`, so the streak multiplier and the remaining daily cap
/// are already in the figure and the row promises what the tap actually pays.
///
/// That arithmetic is deliberately **not** explained on screen — no streak
/// banner, no "×1.35" tag. The number is simply correct, which is the whole
/// point of computing it. The other difference is that logging is one-way here,
/// so his `revertTodaysLog` has no equivalent.
struct CategoryDetailView: View {
    @EnvironmentObject private var store: AppState
    @Environment(\.dismiss) private var dismiss

    let category: Category

    @State private var headerHeight: CGFloat = 0
    private let sheetTail: CGFloat = 56

    @State private var searchText = ""

    private var activities: [Activity] { store.activities(in: category) }

    /// Catalogue order, exactly as Mark's did. An earlier version here sank
    /// completed rows to the bottom; his does not, and a row moving out from
    /// under the finger that just tapped it is a different screen, not a detail.
    private var filteredActivity: [Activity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return activities }
        return activities.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Spacing.sm) {
                if filteredActivity.isEmpty {
                    noMatches
                        .frame(minHeight: 400, alignment: .center)
                } else {
                    ForEach(filteredActivity) { activity in
                        ActivityListCard(
                            title: activity.name,
                            points: points(for: activity),
                            icon: category.icon,
                            tint: category.tint,
                            background: category.background,
                            isChecked: store.isCompletedToday(activity.id),
                            onToggle: { logActivity(activity) }
                        )
                    }
                }
            }
            .padding(Tokens.Spacing.md)
            .padding(.top, headerHeight)
        }
        .safeAreaInset(edge: .bottom) {
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

    // MARK: - Header (Mark's, unchanged)

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .close) { dismiss() }
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

    private var noMatches: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .textStyle(Tokens.Typography.icon)
                .foregroundStyle(Tokens.Semantic.footnote)

            Text("We can't seem to find “\(searchText)”")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)
                .multilineTextAlignment(.center)

            Text("Try a shorter word, or clear the search to see all \(activities.count).")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Tokens.Spacing.xl)
    }

    // MARK: - Pricing (this branch's)

    /// A ticked row shows what it *earned*; an untouched one shows what tapping
    /// it would pay. Re-projecting a completed row would subtract a cap that this
    /// very log already spent, so it would read 0 once the day filled up.
    private func points(for activity: Activity) -> Int {
        if store.isCompletedToday(activity.id) {
            return store.loggedPoints(for: activity.id) ?? activity.basePoints
        }
        return store.projectedPoints(for: activity).finalPoints
    }

    // MARK: - Logging

    /// One way only. This economy has no same-day undo, so a completed row is
    /// inert — every entry point reports "already logged" rather than offering
    /// to take it back. `AppState.logActivity` raises the toast for every
    /// outcome, so there is nothing to report here.
    private func logActivity(_ activity: Activity) {
        guard !store.isCompletedToday(activity.id) else {
            store.toast = Toast(kind: .info, message: "Already logged today — back tomorrow.")
            return
        }
        Task { await store.logActivity(activity) }
    }
}

#if DEBUG
#Preview("Category detail") {
    NavigationStack { CategoryDetailView(category: .actions) }
        .environmentObject(AppState.preview)
}

#Preview("Long names · large type") {
    NavigationStack { CategoryDetailView(category: .foodConsumption) }
        .environmentObject(AppState.preview)
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
