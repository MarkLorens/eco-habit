import SwiftUI

/// The two faces of the dashboard deck, kept presentational: plain values in, closures
/// out, no `AppState`. `RecommendationDeck` owns the swiping and the logging.
///
/// **Both are the same fixed height.** A deck of cards that resize to their content
/// makes the cards peeking out from behind sit at uneven depths, which reads as a
/// rendering bug rather than a stack.
enum RecommendationCardMetrics {
    static let height: CGFloat = 330
    static let radius: CGFloat = 24
    static let artworkSize: CGFloat = 116
}

struct RecommendationCard: View {
    let title: String
    let detail: String
    let points: Int
    let artwork: String
    /// Pale — the capsule behind the points.
    let tint: Color
    /// Saturated — the points text itself.
    let accent: Color
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Image(artwork)
                .resizable()
                .scaledToFit()
                .frame(height: RecommendationCardMetrics.artworkSize)
                .padding(.top, Tokens.Spacing.sm)

            Text(title)
                .textStyle(Tokens.Typography.hero2)
                .foregroundStyle(Tokens.Semantic.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            pointsTag

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Spacing.xl)
        .padding(.vertical, Tokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: RecommendationCardMetrics.height)
        .overlay(alignment: .bottomTrailing) { completeButton }
        .cardSurface()
    }

    private var pointsTag: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            Image(systemName: "leaf.fill")
            Text("+\(points) pts")
        }
        .textStyle(Tokens.Typography.pointsTag)
        .foregroundStyle(accent)
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(Capsule().fill(tint))
    }

    private var completeButton: some View {
        Button(action: onComplete) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Tokens.Palette.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Tokens.Palette.greenDark))
        }
        .buttonStyle(.plain)
        .padding(Tokens.Spacing.xl)
        .accessibilityLabel("Log \(title), plus \(points) points")
    }
}

/// The card after the last recommendation. Not an empty state — finishing the deck is
/// a good outcome, and this is the door to the rest of the catalogue.
struct RecommendationDoneCard: View {
    let onSeeAll: () -> Void

    /// The six category illustrations, clustered. Standing in for the mascot set the
    /// design uses, which is not in main's asset catalogue — same reason
    /// `HabitCategory.mascotName` points at `iconDetail`. One line to swap when the
    /// artwork lands.
    private let cluster: [HabitCategory] = [.water, .actions, .consumption, .waste, .energy, .mobility]

    var body: some View {
        VStack(spacing: Tokens.Spacing.xl) {
            Spacer(minLength: 0)

            HStack(spacing: -Tokens.Spacing.md) {
                ForEach(cluster) { category in
                    Image(category.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .padding(Tokens.Spacing.xs)
                        .background(Circle().fill(category.tint))
                }
            }
            .accessibilityHidden(true)

            Text("Want to do more?")
                .textStyle(Tokens.Typography.hero2)
                .foregroundStyle(Tokens.Semantic.text)

            Button(action: onSeeAll) {
                Text("See All")
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Palette.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Tokens.Palette.greenDark))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Tokens.Spacing.xxl)

            Spacer(minLength: 0)
        }
        .padding(Tokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: RecommendationCardMetrics.height)
        .cardSurface()
    }
}

private extension View {
    /// One definition of the card's shape and elevation, so the deck's real cards and
    /// its coloured understudies cannot drift apart.
    func cardSurface(_ fill: Color = Tokens.Palette.white) -> some View {
        background(
            RoundedRectangle(cornerRadius: RecommendationCardMetrics.radius, style: .continuous)
                .fill(fill)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
        )
    }
}

/// The blank coloured cards visible behind the top one. Deliberately not real cards:
/// rendering the next two recommendations underneath means their titles show through
/// the gaps, and the deck stops reading as "one thing to decide about". They are tinted
/// with the category of the habit each one actually stands for, so advancing the deck
/// changes the colours underneath and the stack reads as a queue rather than decoration.
struct RecommendationBackdrop: View {
    let tint: Color
    /// `1` is fully the next habit's colour, `0` is the white of a real card. A layer
    /// fades to white as it rises into the top slot, so the handoff — backdrop out, real
    /// card in — happens between two identical surfaces instead of flashing a colour.
    let tintStrength: Double
    let shadowOpacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: RecommendationCardMetrics.radius, style: .continuous)
            .fill(Tokens.Palette.white)
            .overlay {
                RoundedRectangle(cornerRadius: RecommendationCardMetrics.radius, style: .continuous)
                    .fill(tint)
                    .opacity(tintStrength)
            }
            .frame(height: RecommendationCardMetrics.height)
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 4)
    }
}

/// Where a card sits in the stack, by depth: `0` is the card in hand, `1` and `2` are the
/// ones still underneath it.
///
/// **Every value moves the same way as depth increases** — smaller, lower, further round,
/// fainter shadow. The stack this replaces fanned its two backdrops in *opposite*
/// directions at full size, with the deeper one drawn on top of the shallower one, which
/// is why it read as three cards dropped on a table rather than a pile with a top card.
struct RecommendationDeckLayer {
    var scale: CGFloat
    var offset: CGSize
    var rotation: Double
    var shadowOpacity: Double

    /// Index is depth. Kept modest on the horizontal: the deck sits inside a 24pt margin
    /// and these corners are meant to peek, not to reach the bezel.
    private static let slots: [RecommendationDeckLayer] = [
        .init(scale: 1.00, offset: .zero,                          rotation:  0.0, shadowOpacity: 0.10),
        .init(scale: 0.95, offset: .init(width:  12, height: 20),  rotation:  3.5, shadowOpacity: 0.07),
        .init(scale: 0.90, offset: .init(width: -16, height: 34),  rotation: -4.0, shadowOpacity: 0.05)
    ]

    /// `progress` is how far the top card has travelled towards being dismissed, `0...1`.
    ///
    /// At `1` every layer has taken the place of the one in front of it — so when the top
    /// card finally leaves and the depths all shift down by one, every remaining layer is
    /// already standing exactly where it needs to end up and nothing jumps.
    static func interpolated(depth: Int, advancing progress: CGFloat) -> RecommendationDeckLayer {
        let here = slots[min(depth, slots.count - 1)]
        let ahead = slots[min(max(depth - 1, 0), slots.count - 1)]
        let t = clamp(progress)
        return .init(
            scale: here.scale + (ahead.scale - here.scale) * t,
            offset: CGSize(width: here.offset.width + (ahead.offset.width - here.offset.width) * t,
                           height: here.offset.height + (ahead.offset.height - here.offset.height) * t),
            rotation: here.rotation + (ahead.rotation - here.rotation) * Double(t),
            shadowOpacity: here.shadowOpacity + (ahead.shadowOpacity - here.shadowOpacity) * Double(t)
        )
    }

    /// See `RecommendationBackdrop.tintStrength`. Only the layer next in line fades — the
    /// one behind it is still two slots from the top and stays its own colour throughout.
    static func tintStrength(depth: Int, advancing progress: CGFloat) -> Double {
        min(1, max(0, Double(depth) - Double(clamp(progress))))
    }

    private static func clamp(_ progress: CGFloat) -> CGFloat { min(max(progress, 0), 1) }
}

#if DEBUG
#Preview("Card") {
    RecommendationCard(
        title: "Bring your own tumbler",
        detail: "Use a reusable bottle — helps reduce plastic waste",
        points: 5,
        artwork: HabitCategory.waste.iconDetail,
        tint: HabitCategory.waste.tint,
        accent: HabitCategory.waste.background,
        onComplete: {}
    )
    .padding(Tokens.Spacing.xxl)
    .background(Tokens.Palette.white)
}

#Preview("Done") {
    RecommendationDoneCard(onSeeAll: {})
        .padding(Tokens.Spacing.xxl)
        .background(Tokens.Palette.white)
}
#endif
