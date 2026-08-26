import SwiftUI

/// What survived the `Theme` teardown.
///
/// This file used to be the "Organic" design system's control set — a capsule button in
/// three weights, a cream card, a tag, a segmented control, a text field, a progress bar,
/// a settings row. Every one of those was drawn in `Theme` (terracotta on cream,
/// Caprasimo) and every one of them lost its last caller when the screens that used them
/// were either deleted or moved to `Tokens`. Anything new belongs in `Tokens` and in a
/// file named after what it is, not here.

/// A whole card that behaves as a button without the default blue tint.
struct PlainPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The colour spine down the left of an Our Fights card.
struct OurFightCategoryIcon: View {
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 10, height: 85)
    }
}

#Preview {
    OurFightCategoryIcon(color: Tokens.Palette.purple)
}
