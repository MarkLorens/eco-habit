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

    /// The most the mark trims off each angular edge of a sector, to leave the gaps
    /// between slices. Only the most: a slice narrower than the gap would be trimmed
    /// out of existence, so `angularInset(for:)` gives the thin ones a smaller one.
    private let maximumInset: CGFloat = 12

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

    /// Where one slice sits on the circle: the angle its centre line points along,
    /// and how wide it opens. Both are measured clockwise from twelve o'clock, the
    /// same way `SectorMark` lays the slices out and `RecapChart` reads taps back.
    private struct Placement: Identifiable {
        var id: HabitCategory { item.category }
        let item: RecapChart.CategoryData
        let midAngle: Double
        let sweep: Double
    }

    private var placements: [Placement] {
        let total = data.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }

        var start = 0.0
        var result: [Placement] = []
        for item in data {
            let sweep = item.value / total * 2 * .pi
            result.append(Placement(item: item, midAngle: start + sweep / 2, sweep: sweep))
            start += sweep
        }
        return result
    }

    var body: some View {
        Chart(placements) { placed in
            let amount = selectedness(placed.item.category)

            SectorMark(
                angle: .value("Value", placed.item.value),
                // The selected slice grows inward, so its outer edge stays on the
                // circle and only the band thickens — the shape in the design.
                innerRadius: .ratio(restingInner + (selectedInner - restingInner) * amount),
                angularInset: angularInset(for: placed.sweep)
            )
            // Pale `tint` at rest, saturated `background` when chosen. Blended by
            // hand: Charts would cut straight from one to the other, and `Color.mix`
            // needs iOS 18.
            .foregroundStyle(placed.item.category.tint.blended(with: placed.item.category.background,
                                                               by: amount))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
        .chartLegend(.hidden)
        .overlay { faces }
        // The mascot in the middle: whichever category is chosen, or the app's own
        // when nothing is. Cross-faded on the same clock as the slices.
        .overlay { centrepiece }
    }

    // MARK: - Slice contents

    /// What each slice carries, placed on its own centre line.
    ///
    /// Not `.annotation(position: .overlay)`, which was what this used to be. That
    /// drops the content near the rim rather than in the middle of the band, and it
    /// hands the content's size back to the chart as layout — so anything measured
    /// against the plot could only ever chase its own tail. Placing the faces here
    /// costs the polar arithmetic below and settles both: each one is centred in its
    /// slice, at a size measured from that slice, and none of it moves the plot.
    private var faces: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height) / 2
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ForEach(placements) { placed in
                let amount = selectedness(placed.item.category)
                // The band this slice is drawn at right now, so its contents ride
                // outward with the edge that is moving.
                let ratio = restingInner + (selectedInner - restingInner) * amount
                let middle = outer * (1 + ratio) / 2

                // Each face is measured against the band *it* appears in, not the
                // one showing at this instant: a number that resized every frame
                // would rescale its own digits all the way through the transition.
                let iconSide = fittedSide(outer: outer, innerRatio: restingInner, sweep: placed.sweep)
                let labelSide = fittedSide(outer: outer, innerRatio: selectedInner, sweep: placed.sweep)

                ZStack {
                    // The selected slice carries its tally instead of its mascot: the
                    // number is the reason to tap, and the icon is already identified
                    // by the colour it just turned.
                    Text("\(placed.item.count)")
                        .textStyle(Tokens.Typography.hero)
                        .foregroundStyle(Tokens.Palette.white)
                        .lineLimit(1)
                        // The token sets the largest the tally is drawn at; a slice
                        // with less room to spare gets the same number set smaller,
                        // rather than one running out over the rim.
                        .minimumScaleFactor(0.2)
                        .frame(width: labelSide, height: labelSide)
                        .opacity(amount * legibility(labelSide))

                    // No percentage — the mascot fills the band on its own.
                    Image(placed.item.category.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSide, height: iconSide)
                        .opacity((1 - amount) * legibility(iconSide))
                }
                .position(x: centre.x + sin(placed.midAngle) * middle,
                          y: centre.y - cos(placed.midAngle) * middle)
            }
        }
        .allowsHitTesting(false)
    }

    /// The side of the largest square that fits inside one slice's band.
    ///
    /// A square of side `h` centred half-way across the band reaches down to
    /// `middle - h / 2`, and that is the tight spot: a wedge is narrowest nearest the
    /// centre. The slice is `2 * r * sin(sweep / 2)` across at radius `r`, less the
    /// inset taken off both edges, and setting that equal to `h` solves in one step.
    /// Past a half-circle the chord stops being the binding constraint, so the sweep
    /// is capped rather than allowed to fold back on itself.
    ///
    /// Whichever is smaller — that width or the band's own thickness — is the room
    /// there is, and the face is set just inside it so it never touches an edge.
    private func fittedSide(outer: CGFloat, innerRatio: CGFloat, sweep: Double) -> CGFloat {
        let inner = outer * innerRatio
        let middle = (inner + outer) / 2
        let sinHalf = CGFloat(sin(min(sweep, .pi) / 2))

        let width = (2 * middle * sinHalf - 2 * angularInset(for: sweep)) / (1 + sinHalf)
        return max(min(width, outer - inner) * 0.86, 0)
    }

    /// How much of the gap between slices a slice can afford to give up.
    ///
    /// A flat 12pt is most of a thin slice and all of a very thin one, which is how a
    /// category with a couple of activities ended up with a mascot hanging in empty
    /// space: the slice under it had been inset out of existence. Capping the inset at
    /// a quarter of the slice's own arc leaves every slice something to draw.
    private func angularInset(for sweep: Double) -> CGFloat {
        let arc = side / 2 * (1 + restingInner) / 2 * CGFloat(sweep)
        return min(maximumInset, arc / 4)
    }

    /// Fades a face out as its slice runs out of room. Past a point there is nothing
    /// useful left to show, and a two-point smudge of a mascot reads as a rendering
    /// fault rather than as a category.
    private func legibility(_ fitted: CGFloat) -> Double {
        let vanishing = side * 0.03
        return Double(min(max((fitted - vanishing) / vanishing, 0), 1))
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
