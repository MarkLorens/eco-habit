import SwiftUI

/// Colour for the spine down the left edge of an OurFight card.
///
/// Hardy's cards take a `Color` directly rather than a `FightType`, which is what
/// keeps them presentational and previewable. This is the one place that decides
/// which colour a type gets, so the list and any future screen agree without the
/// mapping being copied.
extension FightType {

    var tint: Color {
        switch self {
        case .beachCleanup:      return Tokens.Palette.blue
        case .riverCleanup:      return Tokens.Palette.blueLight
        case .mangrovePlanting:  return Tokens.Palette.green
        case .treePlanting:      return Tokens.Palette.greenDark
        case .reefRestoration:   return Tokens.Palette.purple
        case .wasteDrive:        return Tokens.Palette.orange
        case .workshop:          return Tokens.Palette.yellow
        case .wildlifeProtection: return Tokens.Palette.lime
        }
    }
}

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
