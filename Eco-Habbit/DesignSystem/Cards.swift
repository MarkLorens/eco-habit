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
    private let background: Color
//    private let shadow: String
    private let action: () -> Void
    
    init(title: String, caption: String, icon: String, background: Color /*shadow: String*/, action: @escaping () -> Void = {}) {
        self.title = title
        self.caption = caption
        self.icon = icon
        self.background = background
//        self.shadow = shadow
        self.action = action
    }
    
    var body: some View {
        Button(action: action){
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
                    ZStack{
                        Circle()
                            .frame(width: 36, height: 36)
                            .foregroundStyle(Tokens.Palette.white)
                            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                        Ellipse()
                            .frame(width: 36, height: 30)
                            .rotationEffect(.degrees(135))
                            .foregroundStyle(background).opacity(1)
                            .shadow(color: background.opacity(0.8), radius: 2, x: 0, y: 1)
                            .shadow(color: background.opacity(0.4), radius: 10, x: 0, y: 6)
                        Image(systemName: "chevron.right")
                            .textStyle(Tokens.Typography.title)
                            .foregroundStyle(Tokens.Semantic.text)
                    }
                }
                .padding([.horizontal, .bottom], Tokens.Spacing.sm)
            }
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                    .fill(background)
                    .stroke(Tokens.Palette.white, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView{
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Tokens.Spacing.md), GridItem(.flexible())],
            spacing: Tokens.Spacing.xl
        ){
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, background: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
        }
        .padding(Tokens.Spacing.md)
    }
}
