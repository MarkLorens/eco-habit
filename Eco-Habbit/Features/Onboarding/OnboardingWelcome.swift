//
//  OnboardingWelcome.swift
//  Eco-Habbit
//
//  Created by Max on 20/08/26.
//

import SwiftUI

struct OnboardingWelcome: View {
    var onContinue: () -> Void = {}

    var body: some View {
        copy
            .padding(.top, 100)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .bottomLeading) {
                Image("globe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 600)
                    .offset(x: -100, y: 150)
                    .ignoresSafeArea()
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                Button{
                    onContinue()
                } label: {
                    Image(systemName: "chevron.right")
                        .textStyle(Tokens.Typography.hero)
                        .frame(width:60, height: 60)
                        .background(Circle().fill(Tokens.Palette.white))
                        .foregroundStyle(Tokens.Semantic.text)
                }
                .padding(.trailing, Tokens.Spacing.xl)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
            }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            Text("Sustainability made simple")
                .textStyle(Tokens.Typography.hero2)
                .foregroundStyle(Tokens.Semantic.text)

            Text("You care about the planet. We'll show you exactly \nwhere to start with easy, everyday actions.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    OnboardingWelcome()
}
