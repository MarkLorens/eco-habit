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

    /// The least of the circle any one category is drawn with, as a percentage.
    ///
    /// Sized so the slice is still worth aiming at: on the 280pt chart the recap
    /// screen draws, this is about 45pt of arc across the middle of the band, which
    /// is roughly a fingertip, and it is wide enough that the tally still fits inside
    /// when the slice is picked.
    private static let minimumShare: Double = 8

    /// Built from `allCases`, so a category added to the enum shows up here without
    /// anyone having to remember this file.
    private var data: [CategoryData] {
        let logged = HabitCategory.allCases.compactMap { category -> (category: HabitCategory, count: Int)? in
            let count = activities[category] ?? 0
            return count > 0 ? (category, count) : nil
        }
        guard !logged.isEmpty else { return [] }

        return zip(logged, shares(of: logged.map(\.count))).map {
            CategoryData(category: $0.category, value: $1, count: $0.count)
        }
    }

    /// How much of the circle each category is drawn with — its share of the total,
    /// with a floor under the small ones.
    ///
    /// Straight proportion turns one activity out of thirty-three into a three-degree
    /// splinter: too thin to put a finger on, and when it *is* picked it grows inward
    /// into a needle rather than a wedge. Anything under `minimumShare` is lifted to
    /// it and the rest give up the difference in proportion, so the order and the
    /// rough weight of the categories still read true while every one of them stays a
    /// target. Deliberately a lie about the geometry and only the geometry: the tally
    /// on the slice, and the list the selection drives, are the real counts.
    private func shares(of counts: [Int]) -> [Double] {
        let total = counts.reduce(0, +)
        guard total > 0 else { return [] }
        let raw = counts.map { Double($0) / Double(total) * 100 }

        // The floor is paid for out of the slices above it, so it can never ask for
        // more than an even split would leave — six categories cannot all be given a
        // fifth of the circle.
        let floor = min(Self.minimumShare, 100 / Double(counts.count))

        // Lifting one slice takes room from the others, which can push the next
        // smallest under the floor in turn. Pin them one at a time, smallest first,
        // until the scale that fits everyone else leaves them all clear.
        var pinned = Set<Int>()
        var scale = 1.0
        while true {
            let free = raw.indices.filter { !pinned.contains($0) }
            let freeTotal = free.reduce(0.0) { $0 + raw[$1] }
            guard freeTotal > 0 else { break }
            scale = (100 - Double(pinned.count) * floor) / freeTotal

            let sinking = free.filter { raw[$0] * scale < floor }
            guard let next = sinking.min(by: { raw[$0] < raw[$1] }) else { break }
            pinned.insert(next)
        }

        return raw.indices.map { pinned.contains($0) ? floor : raw[$0] * scale }
    }

    /// What `selected` was before the current transition — the shape being animated
    /// *away from*. Switching slices moves two of them at once, so the "from" state
    /// has to be remembered rather than inferred.
    @State private var previous: HabitCategory?
    /// Which end of the crossfade `selected` currently sits at: 0 or 1, never in
    /// between. The only thing that animates; everything else is derived from it.
    ///
    /// It *alternates* rather than resetting. See `select(_:)`.
    @State private var phase: Double = 1

    /// The selection the plot draws at `phase == 0`, and the one at `phase == 1`.
    /// Whichever end `phase` points at holds the live selection, so a selection set
    /// from outside — the recap screen opening on its busiest category — still shows
    /// at full weight, with no transition left to run.
    private var endA: HabitCategory? { phase == 0 ? selected : previous }
    private var endB: HabitCategory? { phase == 0 ? previous : selected }

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
                  endA: endA,
                  endB: endB,
                  current: selected,
                  phase: phase,
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

    /// Turns the crossfade round, rather than animating `selected` itself.
    ///
    /// Swift Charts does not interpolate a `SectorMark`'s radius or style: whatever
    /// the mark is handed, it draws at once, so animating the selection directly —
    /// with `.animation(_:value:)` or `withAnimation` — cuts the whole plot from one
    /// frame to the next. That hard cut is the flicker. Driving a plain `Double`
    /// through `DonutPlot`'s `animatableData` instead re-runs the chart every frame
    /// with interpolated values, which is an animation Charts cannot skip.
    ///
    /// `phase` **flips** between its two ends instead of being reset to 0 and animated
    /// back to 1. Resetting writes the animated value twice in one tap — once plainly,
    /// once animated — and SwiftUI has to render the plain one before it can animate
    /// out of it. That cost two still frames and about 27ms of nothing happening after
    /// the tap, which is short enough to look like a stutter rather than a delay.
    /// Flipping writes it once, inside a single transaction, so the first frame after
    /// the tap is already moving.
    private func select(_ category: HabitCategory?) {
        withAnimation(.snappy(duration: duration)) {
            previous = selected
            selected = category
            phase = 1 - phase
        }
    }

    /// Which slice, if any, sits under `point`.
    ///
    /// Slices are laid out clockwise from twelve o'clock, so the tap's angle measured
    /// the same way maps straight onto the running total of `value`.
    private func category(at point: CGPoint, in size: CGSize) -> HabitCategory? {
        let radius = min(size.width, size.height) / 2
        let dx = point.x - size.width / 2
        let dy = point.y - size.height / 2

        // Anything past the rim is off the chart.
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius else { return nil }

        // `atan2(dx, -dy)` measures clockwise from straight up; shift into 0..2π.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        let slices = data
        let total = slices.reduce(0) { $0 + $1.value }
        guard total > 0 else { return nil }
        let reached = angle / (2 * .pi) * total

        var upperBound = 0.0
        var hit = slices.last
        for item in slices {
            upperBound += item.value
            if reached <= upperBound {
                hit = item
                break
            }
        }
        guard let hit else { return nil }

        // Then the hole, measured against the band *that* slice is drawn at rather
        // than the widest one any slice could take: the pulled-out slice reaches
        // further in than the rest, so where the hole starts depends on which slice
        // the tap is lined up with. Either way a tap inside it is a tap on nothing —
        // it is not a vote for the slice behind the centrepiece.
        let inner = hit.category == selected ? selectedInner : restingInner
        guard distance >= radius * inner else { return nil }
        return hit.category
    }
}

/// The donut itself, rebuilt on every frame of a selection change.
///
/// `Animatable` is what makes that happen: SwiftUI interpolates `phase` and calls
/// `body` for each step, so the chart is handed a slightly different shape each time
/// instead of being asked to animate between two of them.
private struct DonutPlot: View, Animatable {
    let data: [RecapChart.CategoryData]
    /// The two ends of the crossfade: what to draw at `phase == 0` and at `phase == 1`.
    /// Which one is being travelled towards alternates with every tap, so neither is
    /// permanently the "from" or the "to".
    let endA: HabitCategory?
    let endB: HabitCategory?
    /// The live selection. Only the fill colour uses it, and that does not interpolate.
    let current: HabitCategory?
    nonisolated var phase: Double
    let side: CGFloat
    let restingInner: CGFloat
    let selectedInner: CGFloat

    /// The most the mark trims off each angular edge of a sector, to leave the gaps
    /// between slices. Only the most: a slice narrower than the gap would be trimmed
    /// out of existence, so `angularInset(for:)` gives the thin ones a smaller one.
    private let maximumInset: CGFloat = 12

    nonisolated var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// How selected a category is right now: 1 fully out, 0 fully at rest. Both the
    /// slice being left and the one being taken are part-way through mid-transition.
    private func selectedness(_ category: HabitCategory) -> Double {
        let a = endA == category ? 1.0 : 0.0
        let b = endB == category ? 1.0 : 0.0
        return a + (b - a) * phase
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
            .foregroundStyle(placed.item.category == current
                             ? placed.item.category.tintDark
                             : placed.item.category.tint)
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
    ///
    /// Empty when nothing is selected. The hole belongs to whichever slice is pulled
    /// out, and a mascot left standing in it at rest reads as a selection of its own —
    /// which is exactly the state the reader has just tapped their way out of.
    private var centrepiece: some View {
        ZStack {
            mascot(endA).opacity(1 - phase)
            mascot(endB).opacity(phase)
        }
        .frame(width: side * restingInner * 0.55)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func mascot(_ category: HabitCategory?) -> some View {
        if let category {
            Image(category.iconDetail)
                .resizable()
                .scaledToFit()
        }
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
