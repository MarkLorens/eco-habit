//
//  CustomerFightDetailCard.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//
//  Customer copy of `OurFightDetailCard`. The admin card's edit button becomes
//  a love toggle here, so collapsing moves to a tap anywhere on the card.
//
import SwiftUI

struct CustomerFightDetailCard: View {
    let onCollapse: () -> Void
    let onLove: () -> Void

    private let title: String
    private let caption: String
    private let category: Color
    private let date: String
    private let location: String
    private let picture: String
    /// The organiser's own photo. `nil` falls back to `picture`, the bundled art.
    private let photo: UIImage?
    private let isLoved: Bool

    // Additive and defaulted, so the existing call and the preview below keep working.
    private let host: String
    private let actionTitle: String?
    private let onAction: () -> Void
    /// Defaults keep the original dark button for any caller that does not care.
    private let actionBackground: Color
    private let actionForeground: Color

    init(title: String,
         caption: String,
         category: Color,
         date: String,
         location: String,
         picture: String,
         photo: UIImage? = nil,
         isLoved: Bool,
         host: String = "Eco Tourism Bali",
         actionTitle: String? = "Scan or check in",
         actionBackground: Color = Color(hex: 0x2F3A32),
         actionForeground: Color = Tokens.Semantic.ourFightQR,
         onAction: @escaping () -> Void = {},
         onLove: @escaping () -> Void,
         onCollapse: @escaping () -> Void
    ) {
        self.title = title
        self.caption = caption
        self.category = category
        self.date = date
        self.location = location
        self.picture = picture
        self.photo = photo
        self.isLoved = isLoved
        self.host = host
        self.actionTitle = actionTitle
        self.actionBackground = actionBackground
        self.actionForeground = actionForeground
        self.onAction = onAction
        self.onLove = onLove
        self.onCollapse = onCollapse
    }


    var body: some View{
        VStack(spacing: 0){
            // Fill the banner keeping the aspect ratio, then cut what hangs over.
            // Without `scaledToFill` a portrait photo was squeezed into 170pt.
            Image(uiImage: photo ?? UIImage(named: picture) ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipped()

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

                        LoveButton(isLoved: isLoved, action: onLove)
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

                    // Was `print("seeQR code")` — the button rendered and did nothing.
                    // An attendee never *shows* a code; the organiser does. This is the
                    // check-in entry point, so it says so. `nil` hides it once there is
                    // nothing left to do.
                    if let actionTitle {
                        Button(action: onAction) {
                            Text(actionTitle)
                                .textStyle(Tokens.Typography.body)
                                .foregroundStyle(actionForeground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(actionBackground)
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
        .contentShape(Rectangle())
        .onTapGesture { onCollapse() }
    }
}


#Preview {
    struct Harness: View {
        @State private var loved = false

        var body: some View {
            VStack(spacing: Tokens.Spacing.sm) {
                CustomerFightDetailCard(
                    title: "Pick N Choose",
                    caption: "Let's collect items that can be reused and share them with others who need them",
                    category: Tokens.Palette.purple,
                    date: "Wed, 9 Sep • 15.00",
                    location: "Kuta Art Market",
                    picture: "our-fight-example",
                    isLoved: loved,
                    onLove: { loved.toggle() },
                    onCollapse: {}
                )
            }
            .padding(Tokens.Spacing.md)
        }
    }

    return Harness()
}
