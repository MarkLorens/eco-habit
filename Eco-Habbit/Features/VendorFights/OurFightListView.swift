//
//  OurFightListView.swift
//  Eco-Habbit
//
//  Created by Hardy Tee on 15/08/26.
//

import Foundation
import SwiftUI

struct OurFightListView: View {
    @EnvironmentObject private var app: AppState
    
    var body: some View {
        NavigationStack(path: $app.actionsPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.sm){
                        
                        HStack{
                            Text("Our Fights")
                                .textStyle(Tokens.Typography.hero)
                                .foregroundStyle(Tokens.Semantic.text)
                            
                            Spacer()
                            
                            NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .plus){ print("add fight") }
                        }
                        
                        Text("Take action together for a greener tomorrow")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                    }
                    .padding(.horizontal, Tokens.Spacing.xxl)
                    
                    ForEach(app.upcomingFights) { fight in
                        ExpandableFightWrapper(
                            title: fight.title,
                            caption: fight.summary,
                            category: fight.type.tint,
                            date: fight.cardDate,
                            location: fight.locationName,
                            picture: fight.cardPicture,
                            status: false
                        )
                    }
                    .padding(.horizontal, Tokens.Spacing.xl)
                }
            }
            .background(Tokens.Palette.white)
            .navigationDestination(for: HabitCategory.self) { category in
                CategoryDetailView(category: category)
            }
        }
    }
}

// `#Preview` compiles in RELEASE too, and AppState.preview /
// PersistedState.preview are `#if DEBUG`. Without this guard the
// archive build fails — which is what blocks TestFlight.
#if DEBUG
#Preview {
    OurFightListView()
        .environmentObject(AppState.preview)
}
#endif
