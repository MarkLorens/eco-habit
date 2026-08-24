import SwiftUI

extension Fight {

    /// "Wed, 9 Sep • 15.00" — the format Hardy's cards were designed against.
    var cardDate: String {
        let day = startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let time = startsAt.formatted(date: .omitted, time: .shortened)
        return "\(day) • \(time)"
    }

    /// Only one Fight photograph shipped with the design (`our-fight-example`),
    /// so every card uses it until there is real art per event.
    var cardPicture: String { "our-fight-example" }
}

extension HabitCategory {

    /// The category's **saturated** colour, straight from `Tokens.Palette`.
    ///
    /// Distinct from `tint`, which is the pale `…Card` wash used as a page or card
    /// background on the Habits screens. A Fight card's spine is a 6pt stripe — a wash
    /// that faint disappears against white, which is why every spine looked the same.
    var accent: Color {
        switch self {
        case .energy:      Tokens.Palette.yellow
        case .waste:       Tokens.Palette.purple
        case .actions:     Tokens.Palette.lime
        case .water:       Tokens.Palette.blue
        case .mobility:    Tokens.Palette.green
        case .consumption: Tokens.Palette.orange
        }
    }
}

extension HabitCategory {

    /// Text that stays legible on `accent`.
    ///
    /// Blue and orange are dark enough to need white; lime, yellow, lilac and the pale
    /// green need the usual dark text. Stated per case rather than computed from
    /// luminance so a designer can disagree with it in one place.
    var accentForeground: Color {
        switch self {
        case .water, .consumption: Tokens.Palette.white
        default:                   Tokens.Semantic.text
        }
    }
}
