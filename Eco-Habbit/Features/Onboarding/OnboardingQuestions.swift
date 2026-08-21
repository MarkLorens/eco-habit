//
//  OnboardingQuestions.swift
//  Eco-Habbit
//
//  Created by Max on 20/08/26.
//

import SwiftUI

struct OnboardingQuestions: View {
    /// Called once the last question is answered, with the answers worth keeping.
    var onFinished: (OnboardingAnswers) -> Void = { _ in }

    /// Which question is on screen. Kept here rather than in `OnboardingFlow` so the
    /// answers below survive stepping between questions — lifting the step up without
    /// the state would reset every choice on each move.
    @State private var step = 1
    private let lastStep = 3

    /// One answer — "why do you do this" reads as a single reason, and "Something
    /// else" only makes sense as an alternative to the others, not alongside them.
    @State private var selectedReason: String?
    /// Many answers: the copy asks for 2-3.
    @State private var selectedCategories: Set<HabitCategory> = []
    
    /// Question three. Typed rather than a display string, so the recommender reads an
    /// answer instead of re-parsing English.
    @State private var selectedLevel: EffortLevel?

    private let reasons = [
        "Save money",
        "Live healthier",
        "Help the environment",
        "Something else",
    ]
    
    
    var body: some View{
        ZStack(alignment: .top) {
            currentQuestion
                .slidingSteps(value: step)
        }
        .padding(.top, 42)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottomTrailing) { advanceButton }
    }

    /// The only way forward, so it is disabled rather than hidden — a control that
    /// vanishes reads as a broken screen, whereas a greyed one says "not yet".
    ///
    /// There is no skip anywhere in this flow, which is exactly why this has to be
    /// right: with the gate on, an unanswered question is genuinely a dead end, and
    /// `canAdvance` is the single place that decides what counts as answered.
    private var advanceButton: some View {
        Button{
            advance()
        } label: {
            Image(systemName: "chevron.right")
                .textStyle(Tokens.Typography.hero)
                .frame(width:60, height: 60)
                .background(Circle().fill(canAdvance ? Tokens.Semantic.text
                                                     : Tokens.Semantic.statIcon))
                .foregroundStyle(Tokens.Palette.white)
        }
        .disabled(!canAdvance)
        .animation(.easeOut(duration: 0.2), value: canAdvance)
        .padding(.trailing, Tokens.Spacing.xl)
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        .accessibilityLabel(step < lastStep ? "Next question" : "Finish")
        .accessibilityHint(canAdvance ? "" : advanceBlockedReason)
    }

    /// Whether the question on screen has been answered.
    private var canAdvance: Bool {
        switch step {
        case 1:  return selectedReason != nil
        // Two, not one: the question's own subtitle says "Select 2-3", and enabling at
        // one would have the button contradict the instruction directly above it.
        // Matches `FavouriteCategoriesView`, which gates the same choice the same way.
        case 2:  return selectedCategories.count >= 2
        default: return selectedLevel != nil
        }
    }

    private var advanceBlockedReason: String {
        switch step {
        case 1:  return "Choose a reason to continue"
        case 2:  return "Choose at least two categories to continue"
        default: return "Choose an effort level to continue"
        }
    }

    @ViewBuilder
    private var currentQuestion: some View {
        switch step {
        case 1:  QuestionOne
        case 2:  QuestionTwo
        default: QuestionThree
        }
    }

    private func advance() {
        // Belt and braces. The button is disabled, but nothing stops a future caller
        // (a swipe gesture, a keyboard shortcut) from reaching this and skipping a
        // question the flow has no way to come back to.
        guard canAdvance else { return }
        if step < lastStep {
            withAnimation(OnboardingFlow.stepAnimation) { step += 1 }
        } else {
            onFinished(OnboardingAnswers(favouriteCategories: selectedCategories,
                                        effort: selectedLevel))
        }
    }

    private var QuestionOne: some View{
        VStack(spacing: Tokens.Spacing.goodLord){
            ProgressBar(progress: 0)
            
            HeaderTitle(title: "Why do you choose to live more sustainably?")
            
            VStack(spacing: Tokens.Spacing.xl){
                ForEach(reasons, id: \.self) { reason in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedReason = reason }
                    } label: {
                        QuestionCards(
                            description: reason,
                            icon: "actions-icon",
                            isSelected: selectedReason == reason
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedReason == reason ? .isSelected : [])
                }
            }
        }
    }
    
    private var QuestionTwo: some View{
        VStack(alignment: .leading, spacing: Tokens.Spacing.goodLord){
            ProgressBar(progress: 1.0 / 3.0)

            HeaderTitle(
                title: "Which part of your daily life do you want to improve first?",
                subtitle: "Select 2-3 from the category"
            )
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Tokens.Spacing.md), GridItem(.flexible())],
                spacing: Tokens.Spacing.xl
            ){
                ForEach(HabitCategory.allCases) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { toggle(category) }
                    } label: {
                        CategoryCard(
                            category: category,
                            isSelected: selectedCategories.contains(category)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selectedCategories.contains(category) ? .isSelected : []
                    )
                }
            }
        }
    }
    
    private var QuestionThree: some View{
        VStack(alignment: .leading, spacing: Tokens.Spacing.goodLord){
            ProgressBar(progress: 2.0 / 3.0)

            HeaderTitle(
                title: "What level of effort are you comfortable with?"
            )
            
            VStack(spacing: Tokens.Spacing.xl){
                ForEach(EffortLevel.allCases) { level in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selectedLevel = level }
                    } label: {
                        QuestionCards(
                            description: level.displayName,
                            icon: "energy-icon",
                            // Was `selectedReason == levels` — compared against question
                            // ONE's answer, so picking an effort level highlighted
                            // nothing. Tap handling and VoiceOver were already correct,
                            // which is why it read as a rendering glitch.
                            isSelected: selectedLevel == level
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedLevel == level ? .isSelected : [])
                }
            }
        }
    }

    private func toggle(_ category: HabitCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
}

private struct QuestionCards: View {
    let description: String
    let icon: String
    var isSelected: Bool = false

    var body: some View{
        HStack{
            Avatar(type: .avatarSmall, icon: icon)
            Text(description)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
            Spacer()
        }
        .padding(Tokens.Spacing.md)
        .background{
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                .fill(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                .strokeBorder(isSelected ? Tokens.Semantic.text : .clear, lineWidth: 2)
        )
    }
}

private struct HeaderTitle: View{
    let title: String
    var subtitle: String? = nil

    var body: some View{
        VStack(alignment: .leading, spacing: Tokens.Spacing.md){
            Text(title)
                .textStyle(Tokens.Typography.hero2)
                .foregroundStyle(Tokens.Semantic.text)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProgressBar: View {
    let progress: CGFloat // 0...1
    var body: some View{
        GeometryReader { geometry in
            ZStack(alignment: .leading){
                Capsule()
                    .fill(Tokens.Semantic.bgProgressEmpty)
                Capsule()
                    .fill(Tokens.Palette.yellow)
                    .frame(width: geometry.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }
}
#Preview {
    OnboardingQuestions()
}
