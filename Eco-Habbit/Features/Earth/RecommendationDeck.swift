import SwiftUI

/// The dashboard's stack of suggested actions: swipe through five, then a card offering
/// the rest of the catalogue.
///
/// **The deck holds its own list.** `app.recommendedHabits` re-scores on every access,
/// and logging a card makes that habit unavailable — so reading the property directly
/// would mean the deck reshuffled underneath the user at the exact moment they checked
/// something off. It is snapshotted on appear and only rebuilt when the day rolls over
/// or the answers change.
///
/// What the deck *presents* is that snapshot filtered — see `queue`. Filtering only ever
/// removes, so it cannot reorder anything mid-swipe, which is what the snapshot exists to
/// prevent.
struct RecommendationDeck: View {
    @EnvironmentObject private var app: AppState

    /// Today's five, frozen. See the note above.
    @State private var deck: [Habit] = []
    /// Which day `deck` was built for, so a phone left open past midnight refreshes.
    @State private var builtFor: String = ""
    /// Swiped past this session. Not persisted: a skip means "not now", not "never".
    @State private var skipped: Set<String> = []
    @State private var drag: CGSize = .zero

    /// How far a card must be *projected* to travel before it counts as dismissed.
    private let commitDistance: CGFloat = 96
    /// Far enough to clear any screen the app runs on.
    private let throwDistance: CGFloat = 620
    /// Seconds of the flick's velocity projected past the fingertip when deciding whether
    /// the user meant to throw the card. A fast flick barely moves — without this, the
    /// gesture people actually make springs back and the deck feels dead.
    private let flickProjection: CGFloat = 0.14

    var body: some View {
        ZStack {
            backdrops
            top
        }
        .padding(.horizontal, Tokens.Spacing.xxl)
        .task(id: app.today) { rebuildIfNeeded() }
    }

    // MARK: - What is left to show

    /// The frozen deck minus anything the user has swiped past, and minus anything that
    /// has stopped being loggable since the snapshot was taken — logged from the
    /// checklist or the camera while the dashboard sat in another tab, or knocked out by
    /// a cooldown over midnight. Without this the deck keeps offering a card that can
    /// only answer "already logged today" when it is tapped.
    private var queue: [Habit] {
        deck.filter {
            !skipped.contains($0.id) && HabitRepository.isAvailable($0, on: app.today, in: app.data)
        }
    }

    /// How far the top card is towards being gone, `0...1`. This is what makes the deck
    /// feel like a deck: the card behind rises into the top slot in step with the one
    /// being pulled off it, rather than the stack sitting frozen while one card slides.
    private var advanceProgress: CGFloat {
        min(1, abs(drag.width) / commitDistance)
    }

    // MARK: - Layers

    /// The next two cards, blank and tinted with their own categories.
    ///
    /// Drawn deepest-first so the shallower card genuinely overlaps the deeper one, and
    /// taken from `dropFirst()` so the last card has nothing behind it — under the final
    /// card a backdrop promises more that is not there.
    @ViewBuilder
    private var backdrops: some View {
        let upcoming = Array(queue.dropFirst().prefix(2).enumerated())
        ForEach(upcoming.reversed(), id: \.element.id) { position, habit in
            let depth = position + 1
            let layer = RecommendationDeckLayer.interpolated(depth: depth, advancing: advanceProgress)
            RecommendationBackdrop(
                tint: habit.category.tint,
                tintStrength: RecommendationDeckLayer.tintStrength(depth: depth, advancing: advanceProgress),
                shadowOpacity: layer.shadowOpacity
            )
            .scaleEffect(layer.scale)
            .rotationEffect(.degrees(layer.rotation))
            .offset(layer.offset)
        }
    }

    @ViewBuilder
    private var top: some View {
        if let habit = queue.first {
            RecommendationCard(
                title: habit.name,
                detail: habit.detailOrCaption,
                // The projected value, not `basePoints` — it is priced through the same
                // service that does the awarding, so the chip cannot promise a number
                // the toast then contradicts.
                points: app.projectedPoints(for: habit).finalPoints,
                artwork: habit.category.icon,
                tint: habit.category.tint,
                accent: habit.category.background,
                onComplete: { complete(habit) }
            )
            // A new identity per card, so the incoming one animates in from its own
            // resting position instead of inheriting the outgoing card's offset.
            .id(habit.id)
            // Pivoting below the card rather than about its middle: a card held at the
            // bottom swings, and that swing is most of what reads as "a real card".
            .rotationEffect(.degrees(tiltDegrees), anchor: .bottom)
            .offset(drag)
            .gesture(swipe)
            .accessibilityAction(named: "Skip") { skip(habit) }
        } else {
            RecommendationDoneCard(onSeeAll: { app.selectedTab = .actions })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    /// Capped, so dragging a long way does not spin the card past the angle at which it
    /// still reads as a card being moved.
    private var tiltDegrees: Double {
        min(18, max(-18, Double(drag.width) / 8))
    }

    // MARK: - Swiping

    private var swipe: some Gesture {
        DragGesture()
            // The full translation, not just the horizontal component. Discarding the
            // vertical part puts the card on a rail, and a card on a rail is the thing
            // that reads as "no animation" however smoothly it slides.
            .onChanged { drag = $0.translation }
            .onEnded { value in
                // The gesture is attached to the top card, so this is the card being
                // thrown. Read now rather than in the completion handler: by the time the
                // throw lands the queue has already moved on.
                guard let habit = queue.first else { return }
                let travel = projected(value)
                guard abs(travel.width) > commitDistance else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.34)) { drag = .zero }
                    return
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                throwOff(travel) { skipped.insert(habit.id) }
            }
    }

    /// Where the gesture was heading, not just where it ended. Distance alone rejects the
    /// short fast flick most people actually swipe with.
    private func projected(_ value: DragGesture.Value) -> CGSize {
        CGSize(width: value.translation.width + value.velocity.width * flickProjection,
               height: value.translation.height + value.velocity.height * flickProjection)
    }

    /// Extend the throw along its own direction until it is off screen, then hand over.
    ///
    /// Driven off the animation's completion rather than a hand-matched `sleep`, so the
    /// swap cannot drift out of step with the animation and flash the next card.
    private func throwOff(_ travel: CGSize, then finish: @escaping () -> Void) {
        withAnimation(.spring(duration: 0.34, bounce: 0.06), completionCriteria: .logicallyComplete) {
            drag = exit(along: travel)
        } completion: {
            drag = .zero
            finish()
        }
    }

    /// The off-screen resting point for a throw that went `travel`. The vertical slope is
    /// damped: a steep flick should leave at an angle, not shoot straight off the top.
    private func exit(along travel: CGSize) -> CGSize {
        let direction: CGFloat = travel.width < 0 ? -1 : 1
        let slope = min(0.6, max(-0.6, travel.height / max(abs(travel.width), 1)))
        return CGSize(width: direction * throwDistance, height: slope * throwDistance)
    }

    // MARK: - Actions

    private func skip(_ habit: Habit) {
        withAnimation(.snappy(duration: 0.25)) { skipped.insert(habit.id) }
    }

    private func complete(_ habit: Habit) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Thrown up and to the right rather than simply vanishing, so a check reads as
        // the same physical act as a swipe.
        //
        // The log runs *after* the throw lands. Logging first makes the habit
        // unavailable, `queue` drops it, and the card the user just checked disappears
        // mid-flight instead of finishing its animation.
        throwOff(CGSize(width: 320, height: -110)) {
            // `logAndToast` raises the toast and the award, and refuses politely when the
            // habit is already logged or on cooldown. The card leaves either way — a
            // refusal still means the user is done with it, which is what `skipped`
            // records here.
            app.logAndToast(habit, source: .checklist)
            skipped.insert(habit.id)
        }
    }

    /// Build the deck once per day. Reads `recommendedHabits` exactly here, so the
    /// scoring never runs while the user is mid-swipe.
    private func rebuildIfNeeded() {
        guard builtFor != app.today || deck.isEmpty else { return }
        builtFor = app.today
        deck = app.recommendedHabits
        skipped = []
        drag = .zero
    }
}

#if DEBUG
#Preview("Deck") {
    RecommendationDeck()
        .environmentObject(AppState.preview)
}
#endif
