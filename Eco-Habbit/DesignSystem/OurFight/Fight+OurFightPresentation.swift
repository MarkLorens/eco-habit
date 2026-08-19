//
//  Fight+OurFightPresentation.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//

import SwiftUI

/// The admin app supplies a `FightType`; the Our Fights cards speak in palette
/// colours. This mapping is the only place the two meet.
extension FightType {
    var tint: Color {
        switch self {
        case .beachCleanup: return Tokens.Palette.blue
        case .riverCleanup: return Tokens.Palette.blueLight
        case .mangrovePlanting: return Tokens.Palette.greenDark
        case .treePlanting: return Tokens.Palette.green
        case .reefRestoration: return Tokens.Palette.purple
        case .wasteDrive: return Tokens.Palette.orange
        case .workshop: return Tokens.Palette.yellow
        case .wildlifeProtection: return Tokens.Palette.lime
        }
    }
}

extension Fight {
    /// "Wed, 9 Sep • 15.00" — the exact shape the card design shows.
    var cardDateText: String {
        "\(Self.cardDayFormatter.string(from: startsAt)) • \(Self.cardTimeFormatter.string(from: startsAt))"
    }

    /// Events from the admin app carry no photo yet, so every card shows the
    /// same placeholder until an image URL lands in the seed format.
    var cardPicture: String { "our-fight-example" }

    private static let cardDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM"
        return formatter
    }()

    private static let cardTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH.mm"
        return formatter
    }()
}
