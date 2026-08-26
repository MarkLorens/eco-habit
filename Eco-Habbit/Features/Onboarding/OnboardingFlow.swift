//
//  OnboardingFlow.swift
//  Eco-Habbit
//

import SwiftUI

/// What the questions produce.
///
/// A struct rather than a widening tuple because question one is still under review —
/// when the "why do you do this" answer gets somewhere to live, it lands here and the
/// two call sites keep compiling.
struct OnboardingAnswers {
    var favouriteCategories: Set<HabitCategory> = []
    /// `nil` when the question was skipped, which stays distinct from `.easy` all the
    /// way down to `RecommendationService`.
    var effort: EffortLevel?
}

struct OnboardingFlow: View {
    var onFinished: (OnboardingAnswers) -> Void = { _ in }

    private enum Stage { case welcome, questions, finish }
    @State private var stage: Stage = .welcome

    /// Held between the last question and the tap that leaves the finish screen —
    /// `onFinished` is what marks onboarding done, so firing it when the questions end
    /// would drop the user on the home screen before they ever saw the finish screen.
    @State private var answers = OnboardingAnswers()

    static let stepAnimation: Animation = .easeInOut(duration: 0.35)

    var body: some View {
        ZStack {
            Group {
                switch stage {
                case .welcome:
                    OnboardingWelcome {
                        withAnimation(Self.stepAnimation) { stage = .questions }
                    }
                case .questions:
                    OnboardingQuestions { answered in
                        answers = answered
                        withAnimation(Self.stepAnimation) { stage = .finish }
                    }
                case .finish:
                    OnboardingFinish {
                        onFinished(answers)
                    }
                }
            }
            .slidingSteps(value: stage)
        }
    }
}

extension View {
    func slidingSteps<V: Hashable>(value: V) -> some View {
        self
            .id(value)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))
    }
}

#Preview {
    OnboardingFlow()
}
