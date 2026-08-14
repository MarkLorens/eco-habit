//
//  BadgeDetailView.swift
//  Eco-Habbit
//
//  Created by Max on 14/08/26.
//

import SwiftUI

struct BadgeDetailView: View {
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
                            Button{
                                badgeDetail = badge
                            } label: {
                                Avatar(type: .avatarBig, icon: "energy-icon")
                            }
                        }
                    }
                }
                .padding(.horizontal, Tokens.Spacing.xl)
            }
        }
    }
}
#Preview {
    BadgeDetailView()
}
