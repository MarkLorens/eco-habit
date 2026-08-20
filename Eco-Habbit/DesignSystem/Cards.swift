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
                NavigateButton(background: tint, buttonAction: .forward) { print("tapped") }
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
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard, tint: Tokens.Palette.yellowCard/*, shadow: Tokens.Icons.blackShadow*/
            )
        }
        .padding(Tokens.Spacing.md)
    }
}

struct CategoryCard: View {
    let category: HabitCategory
    var isSelected: Bool = false
    var height: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text(category.title)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
                .fixedSize(horizontal: false, vertical: true)

            Image(category.icon)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(Tokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(category.tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .strokeBorder(isSelected ? category.background : .clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
    }
}

#Preview("Category grid") {
    LazyVGrid(
        columns: [GridItem(.flexible(), spacing: Tokens.Spacing.md), GridItem(.flexible())],
        spacing: Tokens.Spacing.xl
    ) {
        ForEach(HabitCategory.allCases) { CategoryCard(category: $0) }
    }
    .padding(40)
}
