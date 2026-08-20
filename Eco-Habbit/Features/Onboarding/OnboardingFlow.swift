//
//  OnboardingFlow.swift
//  Eco-Habbit
//

import SwiftUI

struct OnboardingFlow: View {
    var onFinished: (Set<HabitCategory>) -> Void = { _ in }

    private enum Stage { case welcome, questions }
    @State private var stage: Stage = .welcome

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
                    OnboardingQuestions(onFinished: onFinished)
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
