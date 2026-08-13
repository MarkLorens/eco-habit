import SwiftUI

/// The icon set from the design project's `CategoryIcon` component, drawn as
/// SwiftUI paths in the same 24x24 viewBox the SVGs use.
enum IconGlyph: String, Codable, CaseIterable {
    case energy, waste, actions, water, mobility, consumption
}

struct CategoryIconView: View {
    let glyph: String
    var size: CGFloat = 24
    var color: Color = Theme.C.accent2

    var body: some View {
        Image(glyph)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}
