//
//  RecapChart.swift
//  Eco-Habbit
//
//  Created by Max on 21/08/26.
//

import SwiftUI
import Charts

struct RecapChart: View{
    struct CategoryData: Identifiable {
        /// The category *is* the identity. A generated `UUID` would be new on every
        /// body pass, so Charts would treat each pass as a fresh set of marks.
        var id: HabitCategory { category }
        let category: HabitCategory
        let value: Double
        let count: Int
    }

    /// Activities logged per category over the period being recapped. A category
    /// that is absent, or has nothing logged, leaves no slice.
    let activities: [HabitCategory: Int]

    /// The slice pulled out. Bound so the screen around the chart can caption itself
    /// with whatever the reader is looking at; `nil` is the resting state.
    @Binding var selected: HabitCategory?

    /// Built from `allCases`, so a category added to the enum shows up here without
    /// anyone having to remember this file.
    private var data: [CategoryData] {
        let total = HabitCategory.allCases.reduce(0) { $0 + (activities[$1] ?? 0) }
        guard total > 0 else { return [] }
        return HabitCategory.allCases.compactMap { category in
            let logged = activities[category] ?? 0
            guard logged > 0 else { return nil }
            return CategoryData(category: category,
                                value: Double(logged) / Double(total) * 100,
                                count: logged)
        }
    }

    /// What `selected` was before the current transition — the shape being animated
    /// *away from*. Switching slices moves two of them at once, so the "from" state
    /// has to be remembered rather than inferred.
    @State private var previous: HabitCategory?
    /// 0 = still showing `previous`, 1 = fully showing `selected`. This is the only
    /// thing that animates; everything else is derived from it.
    @State private var progress: Double = 1

    private let duration: Double = 0.3

    /// How much wider the chosen slice reads than the rest.
    private let restingInner: CGFloat = 0.7
    private let selectedInner: CGFloat = 0.52

    var body: some View {
        // The chart is measured so the mascots can be sized against it. A `resizable`
        // image inside a chart annotation has NO size constraint of its own — the
        // annotation grows to whatever the image asks for, which is how a 28pt icon
        // became a full-screen blob the moment the fixed frame came off.
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            plot(side: side)
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func plot(side: CGFloat) -> some View {
        DonutPlot(data: data,
                  previous: previous,
                  current: selected,
                  progress: progress,
                  side: side,
                  restingInner: restingInner,
                  selectedInner: selectedInner)
            // Hit-tested by hand rather than with `chartAngleSelection`, which did not
            // register taps on this donut. Doing the geometry here also buys two things
            // the built-in selection does not: taps in the hole are ignored rather than
            // snapping to whichever slice happens to be nearest, and the whole gesture
            // stays inspectable.
            .overlay {
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { point in
                            guard let tapped = category(at: point, in: geo.size) else { return }
                            select(tapped == selected ? nil : tapped)
                        }
                }
            }
    }

    // MARK: - Selection

    /// Restarts the transition, rather than animating `selected` itself.
    ///
    /// Swift Charts does not interpolate a `SectorMark`'s radius or style: whatever
    /// the mark is handed, it draws at once, so animating the selection directly —
    /// with `.animation(_:value:)` or `withAnimation` — cuts the whole plot from one
    /// frame to the next. That hard cut is the flicker. Driving a plain `Double`
    /// through `DonutPlot`'s `animatableData` instead re-runs the chart every frame
    /// with interpolated values, which is an animation Charts cannot skip.
    private func select(_ category: HabitCategory?) {
        previous = selected
        selected = category
        progress = 0
        withAnimation(.snappy(duration: duration)) { progress = 1 }
    }

    /// Which slice, if any, sits under `point`.
    ///
    /// Slices are laid out clockwise from twelve o'clock, so the tap's angle measured
    /// the same way maps straight onto the running total of `value`.
    private func category(at point: CGPoint, in size: CGSize) -> HabitCategory? {
        let radius = min(size.width, size.height) / 2
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2

        // Ignore the hole and anything outside the rim — a tap on the centrepiece is
        // not a vote for the slice behind it.
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= radius * selectedInner, distance <= radius else { return nil }

        // `atan2(dx, -dy)` measures clockwise from straight up; shift into 0..2π.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let slices = data
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return nil }
        let reached = angle / (2 * .pi) * total

        var upperBound = 0.0
        for item in slices {
            upperBound += item.value
            if reached <= upperBound { return item.category }
        }
        return slices.last?.category
    }
}

/// The donut itself, rebuilt on every frame of a selection change.
///
/// `Animatable` is what makes that happen: SwiftUI interpolates `progress` and calls
/// `body` for each step, so the chart is handed a slightly different shape each time
/// instead of being asked to animate between two of them.
private struct DonutPlot: View, Animatable {
    let data: [RecapChart.CategoryData]
    /// The selection being animated away from, and the one being animated towards.
    let previous: HabitCategory?
    let current: HabitCategory?
    nonisolated var progress: Double
    let side: CGFloat
    let restingInner: CGFloat
    let selectedInner: CGFloat

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// How selected a category is right now: 1 fully out, 0 fully at rest. Both the
    /// slice being left and the one being taken are part-way through mid-transition.
    private func selectedness(_ category: HabitCategory) -> Double {
        let from = previous == category ? 1.0 : 0.0
        let to = current == category ? 1.0 : 0.0
        return from + (to - from) * progress
    }

    var body: some View {
        // The band is the gap between the inner ratio and the rim: `(1 - ratio) * r`,
        // and `r` is half the chart. A mascot slightly under that fills the slice
        // without spilling over either edge.
        let restingIcon = side * (1 - restingInner) / 2 * 0.86
        // The selected slice's band is wider than the resting one, and the tally has
        // to live inside it: "Activities" set at full size is wider than the band and
        // spills over the rim.
        let labelWidth = side * (1 - selectedInner) / 2 * 0.9

        Chart(data) { item in
            let amount = selectedness(item.category)

            SectorMark(
                angle: .value("Value", item.value),
                // The selected slice grows inward, so its outer edge stays on the
                // circle and only the band thickens — the shape in the design.
                innerRadius: .ratio(restingInner + (selectedInner - restingInner) * amount),
                angularInset: 12
            )
            // Pale `tint` at rest, saturated `background` when chosen. Blended by
            // hand: Charts would cut straight from one to the other, and `Color.mix`
            // needs iOS 18.
            .foregroundStyle(item.category.tint.blended(with: item.category.background,
                                                        by: amount))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
            .annotation(position: .overlay) {
                // Both faces are always present and only their opacity moves. Swapping
                // them with `if` instead rebuilds the annotation — a new view tree of a
                // different size — and re-lays out the plot around it. The fixed frame
                // keeps the annotation's footprint constant for the same reason.
                ZStack {
                    // The selected slice carries its tally instead of its mascot: the
                    // number is the reason to tap, and the icon is already identified
                    // by the colour it just turned.
                    VStack(spacing: 0) {
                        Text("\(item.count)")
                            .textStyle(Tokens.Typography.title2)
                        Text("Activities")
                            .textStyle(Tokens.Typography.body)
                    }
                    .foregroundStyle(Tokens.Palette.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: labelWidth)
                    .opacity(amount)

                    // No percentage — the mascot fills the band on its own.
                    Image(item.category.icon)
                        .resizable()
                        .scaledToFit()
                        .opacity(1 - amount)
                }
                .frame(width: restingIcon, height: restingIcon)
            }
        }
        .chartLegend(.hidden)
        // The mascot in the middle: whichever category is chosen, or the app's own
        // when nothing is. Cross-faded on the same clock as the slices.
        .overlay { centrepiece }
    }

    /// Sits in the hole, so it has to stay inside the inner radius.
    private var centrepiece: some View {
        ZStack {
            mascot(previous).opacity(1 - progress)
            mascot(current).opacity(progress)
        }
        .frame(width: side * restingInner * 0.55)
        .allowsHitTesting(false)
    }

    private func mascot(_ category: HabitCategory?) -> some View {
        Image(category?.iconDetail ?? HabitCategory.waste.iconDetail)
            .resizable()
            .scaledToFit()
    }
}

private extension Color {
    /// Linear blend in sRGB. Enough for two flat brand colours a third of a second
    /// apart, and it keeps the deployment target at iOS 17.
    func blended(with other: Color, by amount: Double) -> Color {
        guard amount > 0 else { return self }
        guard amount < 1 else { return other }

        let from = UIColor(self).resolvedColor(with: .current)
        let to = UIColor(other).resolvedColor(with: .current)

        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

        let t = CGFloat(amount)
        return Color(.sRGB,
                     red: fr + (tr - fr) * t,
                     green: fg + (tg - fg) * t,
                     blue: fb + (tb - fb) * t,
                     opacity: fa + (ta - fa) * t)
    }
}

#if DEBUG
private struct RecapChartPreview: View {
    @State private var selected: HabitCategory? = .waste

    var body: some View {
        RecapChart(activities: [.energy: 220, .actions: 165, .waste: 110, .water: 55],
                   selected: $selected)
            .padding(40)
    }
}

#Preview {
    RecapChartPreview()
}
#endif
