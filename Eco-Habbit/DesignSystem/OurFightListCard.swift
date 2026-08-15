//
//  ActivityListCard.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

struct OurFightListCard: View {
    private let title: String
    private let caption: String
    private let category: Color
    private let date: String
    private let location: String
    private let picture: String
    private let background: Color
    private let status: Bool
    private let onToggle: () -> Void
    
    init(
        title: String,
        caption: String,
        category: Color,
        date: String,
        location: String,
        picture: String,
        background: Color,
        status: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.title = title
        self.caption = caption
        self.category = category
        self.date = date
        self.location = location
        self.picture = picture
        self.background = background
        self.status = status
        self.onToggle = onToggle
    }
    
    init(title: String,
         caption: String,
         category: Color,
         date: String,
         location: String,
         picture: String,
         background: Color,
         status: Binding<Bool>) {
        self.init(title: title,
                  caption: caption,
                  category: category,
                  date: date,
                  location: location,
                  picture: picture,
                  background: background,
                  status: status.wrappedValue,
                  onToggle: { status.wrappedValue.toggle() })
    }
    
    private let iconSize: CGFloat = 44
    
    var body: some View{
        HStack(alignment: .center){
            OurFightCategoryIcon(color: category)
            Image(picture)
                .resizable()
                .scaledToFit()
                .padding(Tokens.Spacing.xs)
                .frame(width: iconSize, height: iconSize)
                .background(
                    Circle()
                        .fill(background)
                        .frame(width: 40, height: 40)
                        
                )
                .padding([.vertical, .leading], Tokens.Spacing.xl)
            VStack (alignment: .leading, spacing: Tokens.Spacing.xs){
                Text(title)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                
                Text(date)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
            }
            Spacer(minLength: Tokens.Spacing.sm)
            Button{
                withAnimation(.snappy(duration: 0.2)) {
                    onToggle()
                }
            } label:
            {
                status ? NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .edit) {
                    print("Tapped!")}
                    :
                        NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .forward) {
                    print("Tapped!")
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(status ? "\(title), completed" : "Mark \(title) as done")
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
    
    private var pointsTag: some View {
        HStack(spacing: 0){
            Image(systemName: "leaf.fill")
//            Text("+\(points) pts")
        }
        .foregroundStyle(background)
        .textStyle(Tokens.Typography.footnote)
        .padding([.horizontal], Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(
            Capsule()
                .fill(background)
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
                    caption: "This is a very important task",
                    category: Tokens.Palette.purple,
                    date: "Wed, 9 Sep • 15.00",
                    location: "Kuta Art Market",
                    picture: "fight-list-card-image",
                    background: Tokens.Palette.orange,
                    status: $checks[0]
                )
            }
            .padding(Tokens.Spacing.md)
        }
    }

    return Harness()
}
