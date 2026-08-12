//
//  ActivityListCard.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

struct ActivityListCard: View {
    private let title: String
    private let points: Int
    private let icon: String
    private let tint: Color
    private let background: Color
    private let isChecked: Bool
    private let onToggle: () -> Void
    
    init(
        title: String,
        points: Int,
        icon: String,
        tint: Color,
        background: Color,
        isChecked: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.title = title
        self.points = points
        self.icon = icon
        self.tint = tint
        self.background = background
        self.isChecked = isChecked
        self.onToggle = onToggle
    }
    
    init(title: String, points: Int, icon: String, tint: Color, background: Color,
         isChecked: Binding<Bool>) {
        self.init(title: title, points: points, icon: icon, tint: tint, background: background,
                  isChecked: isChecked.wrappedValue,
                  onToggle: { isChecked.wrappedValue.toggle() })
    }
    
    private let iconSize: CGFloat = 44
    
    var body: some View{
        HStack(alignment: .center, spacing: Tokens.Spacing.md){
            Image(icon)
                .resizable()
                .scaledToFit()
                .padding(Tokens.Spacing.xs)
                .frame(width: iconSize, height: iconSize)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                        .fill(tint)
                        
                )
//                .padding([.vertical, .leading], Tokens.Spacing.xl)
            VStack (alignment: .leading, spacing: Tokens.Spacing.xs){
                Text(title)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                pointsTag
            }
            Spacer(minLength: Tokens.Spacing.sm)
            Button{
                withAnimation(.snappy(duration: 0.2)) {
                    onToggle()
                }
            } label:
            {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? background : Tokens.Palette.black)
                    .textStyle(Tokens.Typography.checkMark)
                    .frame(width: 52, height: 52)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChecked ? "\(title), completed" : "Mark \(title) as done")
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
            Text("+\(points) pts")
        }
        .foregroundStyle(background)
        .textStyle(Tokens.Typography.footnote)
        .padding([.horizontal], Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(
            Capsule()
                .fill(tint)
        )
    }
}

//#Preview {
//    struct Harness: View {
//        @State private var checks = [false, true, false]
// 
//        var body: some View {
//            ScrollView {
//                VStack(spacing: Tokens.Spacing.sm) {
//                    ActivityListCard(
//                        title: "Bring a reusable bottle",
//                        points: 5,
//                        icon: "trash",
//                        tint: Tokens.Palette.orangeCard,
//                        background: Tokens.Palette.orange,
//                        isChecked: false,
//                        onToggle: { _ in }
//                    )
//                    ActivityListCard(
//                        title: "Bring your own food container",
//                        points: 10,
//                        icon: "trash",
//                        tint: Tokens.Palette.orangeCard,
//                        background: Tokens.Palette.orange,
//                        isChecked: false,
//                        onToggle: { _ in }
//                    )
//                    ActivityListCard(
//                        title: "Borrow instead of buying new things you rarely use",
//                        points: 10,
//                        icon: "trash",
//                        tint: Tokens.Palette.orangeCard,
//                        background: Tokens.Palette.orange,
//                        isChecked: false,
//                        onToggle: { _ in }
//                    )
//                }
//                .padding(Tokens.Spacing.md)
//            }
//        }
//    }
//    return Harness()
//}
