//
//  DashboardView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : EarthGlobeView, UserState, MockUserStateData, PointsConfiguration, Tokens
//  Dipakai : RootView (tab Home)
//

import SwiftUI

struct DashboardView: View {

    @EnvironmentObject private var store: AppState

    var body: some View {
        VStack(spacing: Tokens.Spacing.lg) {
            header

            // Memakai asset dari Sketch, bukan bumi versi kode. Konsekuensinya
            // gambar ini SAMA di semua stage — perubahan stage hanya terlihat pada
            // teks di bawah. Versi kode yang bisa berubah per stage disimpan di
            // /_UnusedCode/EarthGlobeView.swift, lengkap dengan cara mengaktifkannya.
            Image(Tokens.Icons.earth)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            stageCaption
        }
        .padding(.horizontal, Tokens.Spacing.lg)
        .padding(.top, Tokens.Spacing.lg)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("Hi, \(store.firstName)!")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)

            Spacer()

            streakBadge
        }
    }

    private var streakBadge: some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .bold))

            Text("\(store.displayStreak())")
                .textStyle(Tokens.Typography.hero)
        }
        .foregroundStyle(Tokens.Palette.orange)
    }

    /// Menyebutkan stage saat ini dan sisa poin menuju stage berikutnya, supaya
    /// perubahan bentuk bumi punya penjelasan dan tidak terasa acak.
    private var stageCaption: some View {
        let stage = store.earthStage
        let remaining = store.pointsToNextStage

        return VStack(spacing: Tokens.Spacing.xs) {
            Text(stage.displayName)
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)

            if let remaining, let next = stage.next {
                Text("\(remaining) pts to \(next.displayName)")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            } else {
                Text("\(store.userState.currentPoints) pts — the Earth is fully restored")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState(store: InMemoryKeyValueStore()))
}
