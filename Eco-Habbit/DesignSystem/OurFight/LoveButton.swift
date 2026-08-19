//
//  LoveButton.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//
//  Same footprint as `NavigateBadge`, but the heart carries the state: outline
//  when idle, red fill when loved — so it reads as a like button, not a
//  navigation control. Kept separate from `NavigateButton` because that one
//  belongs to the shared admin design system.
//

import SwiftUI

struct LoveButton: View {
    let isLoved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack{
                Circle()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Tokens.Palette.white)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
                Ellipse()
                    .frame(width: 36, height: 30)
                    .rotationEffect(.degrees(135))
                    .foregroundStyle(Tokens.Semantic.buttonTintDefault)
                    .shadow(color: Tokens.Semantic.buttonTintDefault.opacity(0.8), radius: 2, x: 0, y: 1)
                    .shadow(color: Tokens.Semantic.buttonTintDefault.opacity(0.4), radius: 10, x: 0, y: 6)
                Image(systemName: isLoved ? "heart.fill" : "heart")
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(isLoved ? Color.red : Tokens.Semantic.text)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct Harness: View {
        @State private var loved = false

        var body: some View {
            LoveButton(isLoved: loved) { loved.toggle() }
        }
    }

    return Harness()
}
