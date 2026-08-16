//
//  ActivityListCard.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

struct OurFightDetailCard: View {
    let onCollapse: () -> Void
    
    private let title: String
    private let caption: String
    private let category: Color
    private let date: String
    private let location: String
    private let picture: String
    /// Hardy's mock read "Organized by Eco Tourism Bali". Defaulted to it so his
    /// previews are unchanged, but the list passes the real host.
    private let organiser: String
    /// Label and action for the primary button. It said "See QR Code" and
    /// printed; what it does depends on whether you host this Fight or attend it,
    /// which only the caller knows.
    private let actionTitle: String
    private let onAction: () -> Void

    init(title: String,
         caption: String,
         category: Color,
         date: String,
         location: String,
         picture: String,
         organiser: String = "Eco Tourism Bali",
         actionTitle: String = "See QR Code",
         onAction: @escaping () -> Void = {},
         onCollapse: @escaping () -> Void,
    )
    {
        self.organiser = organiser
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.title = title
        self.caption = caption
        self.category = category
        self.date = date
        self.location = location
        self.picture = picture
        self.onCollapse = onCollapse
    }
    
    private let iconSize: CGFloat = 44
    
    var body: some View{
        VStack(spacing: 0){
            Image(picture)
                .resizable()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
            
            VStack{
                
                VStack (alignment: .leading, spacing: Tokens.Spacing.sm){
                    
                    HStack{
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm){
                            Text(title)
                                .textStyle(Tokens.Typography.body)
                                .foregroundStyle(Tokens.Semantic.text)
                            
                            HStack (spacing: Tokens.Spacing.sm){
                                Text(date)
                                    .textStyle(Tokens.Typography.footnote)
                                    .foregroundStyle(Tokens.Semantic.footnote)
                                
                                Text("|")
                                    .textStyle(Tokens.Typography.footnote)
                                    .foregroundStyle(Tokens.Semantic.footnote)
                                
                                HStack(spacing: Tokens.Spacing.xxs){
                                    Image(systemName: "mappin")
                                        .textStyle(Tokens.Typography.footnote)
                                        .foregroundStyle(Tokens.Semantic.footnote)
                                    
                                    Text(location)
                                        .textStyle(Tokens.Typography.footnote)
                                        .foregroundStyle(Tokens.Semantic.footnote)
                                }
                            }
                        }
                        Spacer()
                        
                        NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .edit) {
                            onCollapse()
                        }
                        .padding(.trailing, 0)
                        
                    }
                    
                    VStack(alignment: .leading, spacing: Tokens.Spacing.lg){
                        Text("Organized by \(organiser)")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                        
                        Text(caption)
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.ourFightCaption)
                            .frame(width: 230)
                    }
                    
                    Button {
                        onAction()
                    } label: {
                        Text(actionTitle)
                            .textStyle(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Semantic.ourFightQR)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color(hex: 0x2F3A32))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.bottom, Tokens.Spacing.xl)
                }
            }
            .padding(.horizontal, Tokens.Spacing.xl)
            .padding(.top, Tokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
    }
}


#Preview {
    struct Harness: View {
        @State private var checks = [false, true, false]
        
        var body: some View {
            VStack(spacing: Tokens.Spacing.sm) {
                OurFightDetailCard(
                    title: "Pick N Choose",
                    caption: "Let's collect items that can be reused and share them with others who need them",
                    category: Tokens.Palette.purple,
                    date: "Wed, 9 Sep • 15.00",
                    location: "Kuta Art Market",
                    picture: "our-fight-example",
                    onCollapse: {},
                )
            }
            .padding(Tokens.Spacing.md)
        }
    }
    
    return Harness()
}
