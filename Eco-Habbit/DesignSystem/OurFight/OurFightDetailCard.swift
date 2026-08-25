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

    // Everything below is additive and defaulted, so the original call — and
    // `ExpandableFightWrapper`, which is not ours to change — still compiles and still
    // looks exactly as designed.
    private let host: String
    private let actionTitle: String?
    private let onAction: () -> Void
    private let isFavourite: Bool
    private let onToggleFavourite: (() -> Void)?

    /// When set, the pencil **edits** and the card collapses on a tap elsewhere, which
    /// is what the hi-fi shows for an organiser. Left `nil`, the pencil collapses — the
    /// original behaviour, so nothing that already calls this changes.
    private let onEdit: (() -> Void)?

    init(title: String,
         caption: String,
         category: Color,
         date: String,
         location: String,
         picture: String,
         host: String = "Eco Tourism Bali",
         actionTitle: String? = "See QR Code",
         isFavourite: Bool = false,
         onToggleFavourite: (() -> Void)? = nil,
         onAction: @escaping () -> Void = {},
         onEdit: (() -> Void)? = nil,
         onCollapse: @escaping () -> Void,
    )
    {
        self.onEdit = onEdit

        self.title = title
        self.caption = caption
        self.category = category
        self.date = date
        self.location = location
        self.picture = picture
        self.host = host
        self.actionTitle = actionTitle
        self.isFavourite = isFavourite
        self.onToggleFavourite = onToggleFavourite
        self.onAction = onAction
        self.onCollapse = onCollapse
    }
    
    
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

                        if let onToggleFavourite {
                            Button(action: onToggleFavourite) {
                                Image(systemName: isFavourite ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Tokens.Semantic.text)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isFavourite ? "Saved" : "Save this Fight")
                        }

                        NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .edit) {
                            (onEdit ?? onCollapse)()
                        }
                        .padding(.trailing, 0)

                    }

                    VStack(alignment: .leading, spacing: Tokens.Spacing.lg){
                        Text("Organized by \(host)")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                        
                        Text(caption)
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.ourFightCaption)
                            .frame(maxWidth: 230, alignment: .leading)
                    }
                    
                    // `nil` hides it — outside a Fight's check-in window there is
                    // nothing for either side to do, and a button that only ever
                    // reports "not yet" is worse than no button.
                    if let actionTitle {
                        Button(action: onAction) {
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
            }
            .padding(.horizontal, Tokens.Spacing.xl)
            .padding(.top, Tokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        // Only when the pencil has been given a job of its own — otherwise the pencil
        // is still the way back and a tap-to-collapse would be a second, invisible one.
        .contentShape(Rectangle())
        .onTapGesture { if onEdit != nil { onCollapse() } }
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
