//
//  BadgeDetailView.swift
//  Eco-Habbit
//
//  Created by Max on 14/08/26.
//

import SwiftUI

struct BadgeDetailView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var badgeDetail: Badge?
    
    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Spacing.lg), count: 3)

    var body: some View {
        VStack{
            VStack(alignment:.leading, spacing: Tokens.Spacing.sm){
                VStack (alignment: .leading){
                    NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .close){ dismiss() }
                        .padding(.bottom, Tokens.Spacing.xl)
                    Text("Badges")
                        .textStyle(Tokens.Typography.hero)
                        .foregroundStyle(Tokens.Semantic.text)
                    Text("Your sustainability milestones")
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                }
                .padding(.top, Tokens.Spacing.sm)
                .padding(.bottom, Tokens.Spacing.xxl)
                .padding(.horizontal, Tokens.Spacing.xxl)
                
                ScrollView{
                    LazyVGrid(columns: badgeColumns, spacing: Tokens.Spacing.lg){
                        ForEach(MockData.badges) { badge in
                            let unlocked = app.isUnlocked(badge)
                            Button{
                                badgeDetail = badge
                            } label: {
                                if unlocked {
                                    Avatar(type: .avatarBig, icon: badge.icon)

                                } else {
                                    LockedAvatar(type: .avatarBig, icon: badge.icon)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(badge.name), \(unlocked ? "unlocked" : "locked")")
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.xl)
            }
        }
        .modalCard(item: $badgeDetail) { badge in
            BadgeDetailSheet(badge: badge, unlocked: app.isUnlocked(badge)) {
                badgeDetail = nil
            }
        }
    }
}


// `#Preview` compiles in RELEASE too, and AppState.preview /
// PersistedState.preview are `#if DEBUG`. Without this guard the
// archive build fails — which is what blocks TestFlight.
#if DEBUG
#Preview("Badges · mostly unlocked") {
    BadgeDetailView()
        .environmentObject(AppState(data: .preview(vitality: 92, streak: 34, actions: 120)))
}

#Preview("Badges · fresh account") {
    BadgeDetailView()
        .environmentObject(AppState(data: .preview(streak: 0, actions: 0)))
}
#endif
