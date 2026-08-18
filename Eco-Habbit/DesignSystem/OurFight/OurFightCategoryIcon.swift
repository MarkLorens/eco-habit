import SwiftUI

/// The coloured spine down the left edge of an OurFight card.
///
/// Hardy's, lifted out of `Components.swift` rather than taken with it: this
/// branch's `Components.swift` is the Theme component library that Fights,
/// Profile and the camera all build on, and overwriting it to gain one capsule
/// would have taken those with it. It lives beside the cards that use it.
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
