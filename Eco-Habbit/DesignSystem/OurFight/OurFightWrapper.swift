//
//  OurFightWrapper.swift
//  Eco-Habbit
//
//  Created by Hardy Tee on 16/08/26.
//

import SwiftUI

struct ExpandableFightWrapper: View {
    @State var title: String
    @State var caption: String
    @State var category: Color
    @State var date: String
    @State var location: String
    @State var picture: String
    @State var status: Bool
    var organiser: String = "Eco Tourism Bali"
    var actionTitle: String = "See QR Code"
    var onAction: () -> Void = {}
    
    var body: some View {
        if status {
            OurFightDetailCard(
                title: title,
                caption: caption,
                category: category,
                date: date,
                location: location,
                picture: picture,
                organiser: organiser,
                actionTitle: actionTitle,
                onAction: onAction,
                onCollapse: {
                    withAnimation(.snappy(duration: 0.2)) {
                        status = false
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
                        status = true
                    }
                }
            )
        }
    }
}

#Preview{
    ExpandableFightWrapper(
        title: "Pick N Choose",
        caption: "Let's collect items that can be reused and share them with others who need them",
        category: Tokens.Palette.purple,
        date: "Wed, 9 Sep • 15.00",
        location: "Kuta Art Market",
        picture: "our-fight-example",
        status: false
    )
}
