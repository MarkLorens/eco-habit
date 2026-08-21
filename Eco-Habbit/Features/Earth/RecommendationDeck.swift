import SwiftUI

/// The dashboard's stack of suggested actions: swipe through five, then a card offering
/// the rest of the catalogue.
///
/// **The deck holds its own list.** `app.recommendedHabits` re-scores on every access,
/// and logging a card makes that habit unavailable — so reading the property directly
/// would mean the deck reshuffled underneath the user at the exact moment they checked
/// something off. It is snapshotted on appear and only rebuilt when the day rolls over
/// or the answers change.
struct RecommendationDeck: View {
    @EnvironmentObject private var app: AppState

    /// Today's five, frozen. See the note above.
    @State private var deck: [Habit] = []
    /// Which day `deck` was built for, so a phone left open past midnight refreshes.
    @State private var builtFor: String = ""
    @State private var index = 0
    @State private var drag: CGSize = .zero

    /// How far a card must travel before it counts as dismissed.
    private let commitDistance: CGFloat = 96

    var body: some View {
        ZStack {
            backdrops
            top
        }
        .padding(.horizontal, Tokens.Spacing.xxl)
        .task(id: app.today) { rebuildIfNeeded() }
    }

    // MARK: - Layers

    /// Two blank cards peeking out, and only while there is something still to come.
    /// Left under the final card they promise more that is not there.
    @ViewBuilder
    private var backdrops: some View {
        let remaining = deck.count - index
        if remaining > 0 {
            // Offset diagonally rather than only downward, so the stack shows at the
            // corners the way the design does. Same size as the top card — insetting
            // them instead only ever reveals a sliver along the bottom edge.
            RecommendationBackdrop(fill: Tokens.Palette.yellowCard)
                .offset(x: -12, y: 14)
                .rotationEffect(.degrees(-3))
            if remaining > 1 {
                RecommendationBackdrop(fill: Tokens.Palette.blueCard)
                    .offset(x: 12, y: -10)
                    .rotationEffect(.degrees(2.5))
            }
        }
    }

    @ViewBuilder
    private var top: some View {
        if index < deck.count {
            let habit = deck[index]
            RecommendationCard(
                title: habit.name,
                detail: habit.detailOrCaption,
                // The projected value, not `basePoints` — it is priced through the same
                // service that does the awarding, so the chip cannot promise a number
                // the toast then contradicts.
                points: app.projectedPoints(for: habit).finalPoints,
                artwork: habit.category.iconDetail,
                tint: habit.category.tint,
                accent: habit.category.background,
                onComplete: { complete(habit) }
            )
            // A new identity per card, so the incoming one animates in from its own
            // resting position instead of inheriting the outgoing card's offset.
            .id(habit.id)
            .offset(drag)
            .rotationEffect(.degrees(Double(drag.width) / 22))
            .opacity(1 - min(1, abs(Double(drag.width)) / 420))
            .gesture(swipe)
            .accessibilityAction(named: "Skip") { advance() }
        } else {
            RecommendationDoneCard(onSeeAll: { app.selectedTab = .actions })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    // MARK: - Swiping

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = CGSize(width: $0.translation.width, height: 0) }
            .onEnded { value in
                guard abs(value.translation.width) > commitDistance else {
                    withAnimation(.snappy(duration: 0.25)) { drag = .zero }
                    return
                }
                dismissTop(towards: value.translation.width < 0 ? -1 : 1)
            }
    }

    /// Throw the card off screen, then swap in the next one once it is out of sight.
    private func dismissTop(towards direction: CGFloat) {
        withAnimation(.easeOut(duration: 0.22)) {
            drag = CGSize(width: direction * 520, height: 0)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.22))
            advance()
        }
    }

    /// Reset the offset in the same update that changes the index. Split across two
    /// updates, the incoming card renders once at the outgoing card's offset and snaps
    /// back, which looks like a flicker.
    private func advance() {
        drag = .zero
        withAnimation(.snappy(duration: 0.2)) { index += 1 }
    }

    // MARK: - Actions

    private func complete(_ habit: Habit) {
        // `logAndToast` raises the toast and the award, and refuses politely when the
        // habit is already logged or on cooldown. The card leaves either way — a
        // refusal still means the user is done with it.
        app.logAndToast(habit, source: .checklist)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy(duration: 0.25)) { advance() }
    }

    /// Build the deck once per day. Reads `recommendedHabits` exactly here, so the
    /// scoring never runs while the user is mid-swipe.
    private func rebuildIfNeeded() {
        guard builtFor != app.today || deck.isEmpty else { return }
        builtFor = app.today
        deck = app.recommendedHabits
        index = 0
        drag = .zero
    }
}

#if DEBUG
#Preview("Deck") {
    RecommendationDeck()
        .environmentObject(AppState.preview)
}
#endif
