//
//  RecapView.swift
//  Eco-Habbit
//
//  Created by Max on 22/08/26.
//

import SwiftUI

/// A recap of one period: how much was logged, split by category, with a top five
/// underneath — every category's, or the focused category's own.
///
/// The period is the only thing that changes between the Profile screen's three
/// recap cards — the screen itself is the same either way.
///
/// Everything here is a tally of **logs**, not points. Two habits worth 5 and 20
/// points count the same, because the question the screen answers is "what did I
/// actually do", and mixing in the friction table would make the slices disagree
/// with the numbers in the list.
struct RecapView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// What slice of history this is a recap of.
    var period: RecapPeriod = .allTime

    /// Which slice is pulled out, and therefore what the list below is about.
    /// `nil` is the resting state the screen opens in: no slice pulled out, and a top
    /// five drawn from every category at once.
    @State private var focus: HabitCategory?

    @State private var showsCollage = false

    private var counts: [HabitCategory: Int] { app.actionCounts(in: period) }
    private var total: Int { app.totalActions(in: period) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                header

                Text("Recap \(period.title)")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Semantic.text)

                if total == 0 {
                    emptyState
                } else {
                    tally
                    // Capped rather than full-width: the donut is read against the
                    // number above it, and at the full width of the screen the band
                    // is thick enough to compete with it.
                    RecapChart(activities: counts, selected: $focus)
                        .frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)
                    topActivities(in: focus)
                }
            }
            .padding(.horizontal, Tokens.Spacing.xl)
            .tabContentInsets()
        }
        .background(Tokens.Palette.white.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        // Passed explicitly rather than relied on being inherited — a cover builds its
        // own hierarchy, and a missing `EnvironmentObject` is a crash, not a warning.
        .fullScreenCover(isPresented: $showsCollage) {
            RecapCollageView(period: period, summary: summary)
                .environmentObject(app)
        }
    }

    private var header: some View {
        HStack {
            NavigateButton(background: Tokens.Semantic.buttonTintDefault,
                           buttonAction: .back) { dismiss() }
            Spacer()
            // Share opens the photo wall rather than a share sheet: the sheet is still
            // there, one screen further in, and it now has something worth handing over
            // — a picture of the month instead of a sentence about it.
            Button { showsCollage = true } label: {
                NavigateBadge(background: Tokens.Semantic.buttonTintDefault,
                              buttonAction: .share)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share your recap")
        }
    }

    /// The headline number, above the chart it is the sum of.
    private var tally: some View {
        VStack(spacing: Tokens.Spacing.xxs) {
            Text("\(total)")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)
            Text("Activities")
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity)
    }

    /// The list under the chart: the focused category's top five, or — with nothing
    /// selected — the top five across all of them, each row wearing the colours of
    /// whichever category it came from.
    private func topActivities(in category: HabitCategory?) -> some View {
        let tallies = app.topActivities(in: category, period: period)

        return VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text(heading(for: tallies.count, in: category))
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)

            ForEach(tallies) { tally in
                RecapActivityRow(name: tally.habit.name,
                                 count: tally.count,
                                 category: tally.habit.category)
            }
        }
        // The list is the reason the chart is tappable, so it should not look like a
        // different screen's content when the selection changes.
        .animation(.snappy(duration: 0.2), value: category)
    }

    /// "Top 5" is a claim about the list, not a fixed label: an account with three
    /// waste habits behind it has a top three. The category is named only when one is
    /// selected — with the chart at rest the list is about everything.
    private func heading(for count: Int, in category: HabitCategory?) -> String {
        let subject = category.map { " in \($0.title)" } ?? ""
        return count == 1
            ? "Your Top Activity\(subject)"
            : "Your Top \(count) Activities\(subject)"
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Image(HabitCategory.actions.iconDetail)
                .resizable()
                .scaledToFit()
                .frame(width: 140)
            Text(period.datePrefix == nil
                 ? "Nothing to recap yet"
                 : "Nothing logged in \(period.title)")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)
            Text("Check an activity off and it will turn up here.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Spacing.goodLord)
    }

    /// What the share sheet is titled with, once the collage has an image to hand it.
    /// Plain text, and only this account's own totals.
    private var summary: String {
        let window = period.datePrefix == nil ? "" : " in \(period.title)"
        guard total > 0 else { return "I'm just getting started on Eco Habbit." }
        guard let focus, let count = counts[focus] else {
            return "I've logged \(total) activities on Eco Habbit\(window)."
        }
        return "I've logged \(total) activities on Eco Habbit\(window) — \(count) of them in \(focus.title)."
    }
}

/// One line of the top-five list: the category's mascot, the habit, the tally.
private struct RecapActivityRow: View {
    let name: String
    let count: Int
    /// The habit's own category, not the chart's selection: the list can hold rows
    /// from several categories at once.
    let category: HabitCategory

    private let iconSize: CGFloat = 44

    var body: some View {
        HStack(spacing: Tokens.Spacing.md) {
            Image(category.icon)
                .resizable()
                .scaledToFit()
                .padding(Tokens.Spacing.xs)
                .frame(width: iconSize, height: iconSize)
                .background(Circle().fill(category.tint).frame(width: 40, height: 40))

            Text(name)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)

            Spacer(minLength: Tokens.Spacing.sm)

            Text("\(count)")
                .textStyle(Tokens.Typography.hero2)
                .foregroundStyle(Tokens.Semantic.text)
        }
        .padding(Tokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        )
    }
}

#if DEBUG
#Preview("All time") {
    NavigationStack {
        RecapView()
            .environmentObject(AppState.preview)
    }
}

#Preview("This month") {
    NavigationStack {
        RecapView(period: .month(of: Day.today()))
            .environmentObject(AppState.preview)
    }
}
#endif
