//
//  ActivityListCard.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

struct OurFightListCard: View {
    let onExpand: () -> Void
    
    private let title: String
    private let caption: String
    private let category: Color
    private let date: String
    private let location: String
    private let picture: String
    
    init(title: String,
         caption: String,
         category: Color,
         date: String,
         location: String,
         picture: String,
         onExpand: @escaping () -> Void
    ) {
        
        self.title = title
        self.caption = caption
        self.category = category
        self.date = date
        self.location = location
        self.picture = picture
        self.onExpand = onExpand
    }
    
    private let iconSize: CGFloat = 44
    
    var body: some View{
        HStack(alignment: .center){
            OurFightCategoryIcon(color: category)
            
            HStack(alignment: .center, spacing: Tokens.Spacing.lg){
                ZStack{
                    Image(picture)
                        .resizable()
                        .frame(width: 110, height: 85)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    AvatarIcon(type: .avatarSmall, icon: Tokens.Icons.wasteIcon)
                        .offset(x: 48, y: 30)
                }
                
                VStack (alignment: .leading, spacing: Tokens.Spacing.sm){
                    Text(title)
                        .textStyle(Tokens.Typography.body)
                        .foregroundStyle(Tokens.Semantic.text)
                    
                    Text(date)
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                }
            }
            
            Spacer(minLength: Tokens.Spacing.sm)
            NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .forward) {
                onExpand()
            }
        }
        .padding(Tokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        )
    }
}


#Preview {
    struct Harness: View {
        @State private var checks = [false, true, false]
        
        var body: some View {
            VStack(spacing: Tokens.Spacing.sm) {
                OurFightListCard(
                    title: "Pick N Choose",
                    caption: "Let's collect items that can be reused and share them with others who need them",
                    category: Tokens.Palette.purple,
                    date: "Wed, 9 Sep • 15.00",
                    location: "Kuta Art Market",
                    picture: "our-fight-example",
                    onExpand: {}
                )
            }
            .padding(Tokens.Spacing.md)
        }
    }
    
    return Harness()
}
