import SwiftUI

/// Design tokens ported 1:1 from the "Organic" design system
/// (`_ds/organic-.../styles.css` in the Eco-Habit design project).
/// Nothing in the app should hard-code a hex, font name or radius that lives here.
enum Theme {

    // MARK: - Color roles

    enum C {
        static let bg = Color(hex: 0xF5EAD8)
        static let surface = Color(hex: 0xEBDDC5)
        static let text = Color(hex: 0x201E1D)
        static let accent = Color(hex: 0xC67139)
        static let accent2 = Color(hex: 0x7A8A5E)
        static let divider = Color(hex: 0x201E1D).opacity(0.16)

        // Neutral ramp
        static let neutral100 = Color(hex: 0xF9F4ED)
        static let neutral200 = Color(hex: 0xEEE7DB)
        static let neutral300 = Color(hex: 0xDCD3C4)
        static let neutral400 = Color(hex: 0xC0B6A5)
        static let neutral500 = Color(hex: 0xA19786)
        static let neutral600 = Color(hex: 0x82796A)
        static let neutral700 = Color(hex: 0x645C50)
        static let neutral800 = Color(hex: 0x474238)
        static let neutral900 = Color(hex: 0x2E2B25)

        // Accent (terracotta) ramp
        static let accent100 = Color(hex: 0xFFF2EB)
        static let accent200 = Color(hex: 0xFFE1D0)
        static let accent300 = Color(hex: 0xFFC6A5)
        static let accent400 = Color(hex: 0xF6A06B)
        static let accent500 = Color(hex: 0xD67F48)
        static let accent600 = Color(hex: 0xB2622D)
        static let accent700 = Color(hex: 0x8C491A)
        static let accent800 = Color(hex: 0x643312)
        static let accent900 = Color(hex: 0x402310)

        // Accent-2 (sage) ramp
        static let accent2_100 = Color(hex: 0xF0FAE1)
        static let accent2_200 = Color(hex: 0xE1EECC)
        static let accent2_300 = Color(hex: 0xCCDBB2)
        static let accent2_400 = Color(hex: 0xAEBF92)
        static let accent2_500 = Color(hex: 0x8FA073)
        static let accent2_600 = Color(hex: 0x728157)
        static let accent2_700 = Color(hex: 0x56633F)
        static let accent2_800 = Color(hex: 0x3D472B)
        static let accent2_900 = Color(hex: 0x272E1B)
    }

    // MARK: - Spacing (the 1.10x density scale)

    enum S {
        static let x1: CGFloat = 4.4
        static let x2: CGFloat = 8.8
        static let x3: CGFloat = 13.2
        static let x4: CGFloat = 17.6
        static let x6: CGFloat = 26.4
        static let x8: CGFloat = 35.2
    }

    // MARK: - Radii — "over-round": containers at lg, controls go pill

    enum R {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 28
        /// `.card` / `.dialog` get `calc(--radius-lg * 1.15)` in the stylesheet.
        static let card: CGFloat = 32.2
        static let pill: CGFloat = 999
    }

    // MARK: - Elevation

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let y: CGFloat
    }

    enum E {
        static let sm = Shadow(color: C.neutral900.opacity(0.14), radius: 2, y: 1)
        static let md = Shadow(color: C.neutral900.opacity(0.16), radius: 10, y: 3)
        static let lg = Shadow(color: C.neutral900.opacity(0.22), radius: 32, y: 12)
    }

    // MARK: - Type

    enum F {
        static let headingName = "Caprasimo"
        static let bodyName = "Figtree"

        /// Caprasimo — the only display voice in this system.
        static func heading(_ size: CGFloat) -> Font {
            .custom(headingName, size: size)
        }

        static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .custom(bodyName, size: size).weight(weight)
        }
    }
}

// MARK: - Helpers

// `Color(hex:)` now lives in Tokens.swift, at Mark's request — Theme is being
// deprecated in favour of Tokens, so the surviving copy belongs there. Two
// declarations in one module is an ambiguous-init compile error, not a warning.

extension View {
    func elevation(_ shadow: Theme.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    /// `.washed` — photographs sit *back* into the warm page, never on top of it.
    func washed() -> some View {
        self.saturation(0.6).contrast(0.85).brightness(0.04).opacity(0.94)
    }
}
