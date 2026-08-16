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
                    
                    ForEach(0..<6, id: \.self) { _ in
                        ExpandableFightWrapper(
                            title: "Pick N Choose",
                            caption: "Let's collect items that can be reused and share them with others who need them",
                            category: Tokens.Palette.purple,
                            date: "Wed, 9 Sep • 15.00",
                            location: "Kuta Art Market",
                            picture: "our-fight-example",
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

#Preview {
    OurFightListView()
        .environmentObject(AppState.preview)
}
