//
//  CustomerFightWrapper.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//
//  Customer copy of `ExpandableFightWrapper`: same list card, but expanding
//  shows `CustomerFightDetailCard` (love toggle) instead of the admin card.
//

import SwiftUI

struct CustomerFightWrapper: View {
    let title: String
    let caption: String
    let category: Color
    let date: String
    let location: String
    let picture: String
    let isLoved: Bool
    let onLove: () -> Void

    // Defaulted so existing callers and the preview below are unaffected.
    var host: String = "Eco Tourism Bali"
    var actionTitle: String? = "Scan or check in"
    var onAction: () -> Void = {}

    @State private var isExpanded = false

    var body: some View {
        if isExpanded {
            CustomerFightDetailCard(
                title: title,
                caption: caption,
                category: category,
                date: date,
                location: location,
                picture: picture,
                isLoved: isLoved,
                host: host,
                actionTitle: actionTitle,
                onAction: onAction,
                onLove: onLove,
                onCollapse: {
                    withAnimation(.snappy(duration: 0.2)) {
                        isExpanded = false
                    }
                }
            )
        } else {
            OurFightListCard(
                title: title,
                caption: caption,
                category: category,
                date: date,
                location: location,
                picture: picture,
                onExpand: {
                    withAnimation(.snappy(duration: 0.2)) {
                        isExpanded = true
                    }
                }
            )
        }
    }
}

#Preview{
    struct Harness: View {
        @State private var loved = false

        var body: some View {
            CustomerFightWrapper(
                title: "Pick N Choose",
                caption: "Let's collect items that can be reused and share them with others who need them",
                category: Tokens.Palette.purple,
                date: "Wed, 9 Sep • 15.00",
                location: "Kuta Art Market",
                picture: "our-fight-example",
                isLoved: loved,
                onLove: { loved.toggle() }
            )
            .padding(Tokens.Spacing.md)
        }
    }

    return Harness()
}
