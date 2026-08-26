//
//  OnboardingFinish.swift
//  Eco-Habbit
//
//  Created by Max on 26/08/26.
//

import SwiftUI

struct OnboardingFinish: View {
    /// Tapping anywhere is the only way on — there is no button, so the whole screen
    /// has to carry the gesture, and the caller decides what "on" means.
    var onContinue: () -> Void = {}

    var body: some View {
        VStack(spacing: Tokens.Spacing.huge){
            Spacer()
            Text("Time to heal your earth!")
                .textStyle(Tokens.Typography.hero3)
                .foregroundStyle(Tokens.Semantic.text)
            Text("Your earth starts small — and so do you.\nWe've picked a few easy actions to begin with.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
                .padding(.bottom, Tokens.Spacing.xxl)
            Image("globe")
                .resizable()
                .scaledToFit()
            Spacer()
            Text("Tap to continue")
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.footnote).opacity(0.5)
        }
        .padding(.bottom, Tokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.white.ignoresSafeArea())
        // The spacers and the image leave gaps a hit test would otherwise fall through.
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to continue")
    }
}

#Preview {
    OnboardingFinish()
}
