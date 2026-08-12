//
//  DailyPracticesView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Category, Category+Presentation, Cards, Tokens, CategoryDetailView
//  Dipakai : RootView (tab Practices)
//

import SwiftUI

/// Grid 6 kategori. Sumbernya `Category.allCases`, bukan daftar yang ditulis
/// manual di sini — kalau kategori berubah, layar ini ikut tanpa disunting.
struct DailyPracticesView: View {

    /// Navigasi dimiliki RootView, bukan view ini — RootView perlu tahu kapan
    /// harus menyembunyikan tab bar, karena layar detail tampil penuh di Sketch.
    var onSelectCategory: (Category) -> Void = { _ in }

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Spacing.md),
        GridItem(.flexible(), spacing: Tokens.Spacing.md)
    ]

    var body: some View {
        // Header di luar ScrollView, bukan di dalamnya. Selain mengikuti Sketch
        // (judul tidak ikut menggulung), ini juga membuat header tunduk pada
        // safe area — di dalam ScrollView tadi judulnya menabrak status bar.
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            header

            ScrollView {
                LazyVGrid(columns: columns, spacing: Tokens.Spacing.lg) {
                    ForEach(Category.displayOrder) { category in
                        Cards(
                            title: category.shortTitle,
                            caption: category.tagline,
                            icon: category.mascotName,
                            background: category.cardBackground,
                            action: { onSelectCategory(category) }
                        )
                    }
                }
                // Ruang supaya kartu terakhir tidak tertutup tab bar mengambang.
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.top, Tokens.Spacing.lg)
        .background(Tokens.Palette.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text("Daily Practices")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)

            Text("Choose a category to see suggested actions")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
    }
}

#Preview {
    NavigationStack {
        DailyPracticesView()
    }
}
