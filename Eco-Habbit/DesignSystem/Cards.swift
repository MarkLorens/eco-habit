//
//  Cards.swift
//  Eco-Habbit
//
//  Created by Max on 10/08/26.
//

import SwiftUI

struct Cards: View {
    private let title: String
    private let caption: String
    private let icon: String
    private let tint: Color
    private let background: Color
//    private let shadow: String
    
    init(title: String, caption: String, icon: String, background: Color, tint: Color /*shadow: String*/){
        self.title = title
        self.caption = caption
        self.icon = icon
        self.background = background
        self.tint = tint
//        self.shadow = shadow
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing: Tokens.Spacing.sm){
            VStack(alignment: .leading){
                Text(title)
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
                Text(caption)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Tokens.Spacing.xl)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: Tokens.Spacing.sm){
//                    ZStack{
//                        Image(shadow)
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 100, height: 100)
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
//                    }
                Spacer()
                NavigateButton(background: tint, direction: .right) { print("tapped") }
            }
            .padding([.horizontal, .bottom], Tokens.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(tint)
                .stroke(Tokens.Palette.white, lineWidth: 1)
        )
    }
}

#Preview {
    ScrollView{
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Tokens.Spacing.md), GridItem(.flexible())],
            spacing: Tokens.Spacing.xl
        ){
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
        }
        .padding(Tokens.Spacing.md)
    }
}
