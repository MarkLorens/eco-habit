//
//  CameraActionView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 19/08/26.
//
//  The low-confidence half of the camera flow ("What Did You Do?"): the photo
//  the user took, plus likely actions to pick from — seeded by the classifier's
//  best guesses, topped up with habits still available today. Rows are the same
//  `ActivityListCard` the checklist uses, so a camera log looks identical to a
//  checklist log.
//

import SwiftUI

struct CameraActionView: View {
    @EnvironmentObject private var app: AppState

    let photo: UIImage
    let suggestions: [Habit]
    let onBack: () -> Void
    let onDone: () -> Void

    @State private var selectedId: String?

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous))

                    Text("Recommended for you")
                        .textStyle(Tokens.Typography.title)
                        .foregroundStyle(Tokens.Semantic.text)

                    VStack(spacing: Tokens.Spacing.sm) {
                        ForEach(suggestions) { habit in
                            ActivityListCard(
                                title: habit.name,
                                points: habit.basePoints,
                                icon: habit.category.icon,
                                tint: habit.category.tint,
                                background: habit.category.background,
                                isChecked: selectedId == habit.id,
                                onToggle: { choose(habit) }
                            )
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.xl)
                .padding(.top, Tokens.Spacing.sm)
            }

            footer
        }
        .background(Tokens.Palette.white.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            VStack(spacing: Tokens.Spacing.xs) {
                Text("What Did You Do?")
                    .textStyle(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Semantic.text)
                Text("Choose an action to log")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }

            HStack {
                NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .back, action: onBack)
                Spacer()
            }
        }
        .padding(.horizontal, Tokens.Spacing.xl)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    // MARK: - Selection

    /// The checkmark fills first, then the log lands — the beat makes the
    /// selection feel acknowledged instead of the screen just vanishing.
    private func choose(_ habit: Habit) {
        guard selectedId == nil else { return }
        selectedId = habit.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            try? await Task.sleep(for: .seconds(0.35))
            app.logAndToast(habit, source: .visualSearch)
            onDone()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Text("Can't find your actions?")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)

            Button {
                app.selectedTab = .actions
                onDone()
            } label: {
                Text("See All Actions >")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.text)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.xl)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(Tokens.Palette.limeCard)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

//#Preview {
//    CameraActionView(
//        photo: UIGraphicsImageRenderer(size: CGSize(width: 960, height: 720)).image { context in
//            UIColor(white: 0.35, alpha: 1).setFill()
//            context.fill(CGRect(x: 0, y: 0, width: 960, height: 720))
//        },
//        suggestions: Array(MockData.habits.prefix(3)),
//        onBack: {},
//        onDone: {}
//    )
//    .environmentObject(AppState.preview)
//}
