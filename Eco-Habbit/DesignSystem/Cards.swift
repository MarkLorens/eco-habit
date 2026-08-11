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
    private let shadow: String
    private let action: () -> Void
    
    init(title: String, caption: String, icon: String, shadow: String, action: @escaping () -> Void = {}) {
        self.title = title
        self.caption = caption
        self.icon = icon
        self.shadow = shadow
        self.action = action
    }
    
    var body: some View {
        Button(action: action){
            VStack (alignment: .leading, spacing: Tokens.Spacing.sm){
                Text(title)
                    .textStyle(Tokens.Typography.title)
                Text(caption)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Palette.gray)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: Tokens.Spacing.sm){
                    ZStack{
                        Image(shadow)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .textStyle(Tokens.Typography.title)
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Tokens.Spacing.lg)
            .frame(width: 176.91, height:186)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                    .fill(Tokens.Palette.white)
                    .stroke(Tokens.Palette.grayLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let columns = [
        GridItem(.adaptive(minimum: 176.91))
        ]
    ScrollView{
        LazyVGrid(columns: columns, spacing: Tokens.Spacing.xl){
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
            Cards(
                title: "Waste", caption: "Less waste today\nCleaner Tomorrow", icon: Tokens.Icons.trash, shadow: Tokens.Icons.blackShadow
            )
        }
    }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Spacing.xl)
        .background(Tokens.Palette.bgColor)
}
