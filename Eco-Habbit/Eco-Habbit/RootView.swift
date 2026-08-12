//
//  RootView.swift
//  Eco-Habbit
//
//  Butuh   : MainTabBar, DailyPracticesView, CategoryDetailView, Tokens
//  Dipakai : Eco_HabbitApp
//

import SwiftUI

struct RootView: View {

    @State private var selectedTab: MainTab = .home

    /// Path navigasi dipegang di sini supaya tab bar bisa disembunyikan begitu
    /// user masuk ke layar detail — di Sketch layar itu tampil penuh tanpa tab bar.
    @State private var path: [Category] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack(path: $path) {
                tabContent
                    .navigationDestination(for: Category.self) { category in
                        CategoryDetailView(category: category)
                    }
            }

            if path.isEmpty {
                MainTabBar(selection: $selectedTab)
                    .padding(.bottom, Tokens.Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .practices:
            DailyPracticesView(onSelectCategory: { path.append($0) })

        case .home:
            DashboardView()

        // Dua tab sisanya belum dikerjakan — placeholder jujur, bukan layar kosong
        // yang menyamar sebagai fitur yang sudah jadi.
        case .ourFights:
            placeholder(title: "Our Fights", note: "Layar event belum dibuat")
        case .profile:
            placeholder(title: "Profile", note: "Belum dibuat")
        }
    }

    private func placeholder(title: String, note: String) -> some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Text(title)
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)

            Text(note)
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.white)
    }
}

#Preview {
    RootView()
        .environment(AppStore(store: InMemoryKeyValueStore()))
}
