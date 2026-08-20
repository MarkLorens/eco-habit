//
//  CustomerFightListView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//
//  Customer copy of `OurFightListView` (the admin variant keeps the plus
//  button for creating events). The header heart is a plain filter: on, the
//  same list shows only loved events; off, it shows everything.
//

import Foundation
import SwiftUI

struct CustomerFightListView: View {
    @EnvironmentObject private var app: AppState

    @State private var showingLovedOnly = false

    private var fights: [Fight] {
        showingLovedOnly ? app.favouriteFights : app.browsableFights
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.sm){

                        HStack{
                            Text("Our Fights")
                                .textStyle(Tokens.Typography.hero)
                                .foregroundStyle(Tokens.Semantic.text)

                            Spacer()

                            LoveButton(isLoved: showingLovedOnly) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    showingLovedOnly.toggle()
                                }
                            }
                        }

                        Text("Take action together for a greener tomorrow")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                    }
                    .padding(.horizontal, Tokens.Spacing.xxl)

                    if showingLovedOnly && fights.isEmpty {
                        Text("Nothing saved yet. Tap the heart on an event to keep it here.")
                            .textStyle(Tokens.Typography.footnote)
                            .foregroundStyle(Tokens.Semantic.footnote)
                            .padding(.horizontal, Tokens.Spacing.xxl)
                    } else {
                        ForEach(fights) { fight in
                            CustomerFightWrapper(
                                title: fight.title,
                                caption: fight.summary,
                                category: fight.type.tint,
                                date: fight.cardDate,
                                location: fight.locationName,
                                picture: fight.cardPicture,
                                isLoved: app.isFavourite(fight),
                                onLove: { app.toggleFavourite(fight) }
                            )
                        }
                        .padding(.horizontal, Tokens.Spacing.xl)
                    }
                }
                .tabContentInsets()
            }
            .background(Tokens.Palette.white)
        }
    }
}

//#Preview {
//    CustomerFightListView()
//        .environmentObject(AppState.preview)
//}
