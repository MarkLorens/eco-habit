//
//  ActivityRow.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Activity (Models/), Category+Presentation, Tokens
//  Dipakai : CategoryDetailView
//

import SwiftUI

/// Satu baris aksi di daftar kategori: tile maskot, nama, pill poin, lingkaran centang.
struct ActivityRow: View {

    private let activity: Activity
    private let isCompleted: Bool
    private let onToggle: () -> Void

    init(activity: Activity, isCompleted: Bool, onToggle: @escaping () -> Void = {}) {
        self.activity = activity
        self.isCompleted = isCompleted
        self.onToggle = onToggle
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Tokens.Spacing.md) {
                mascotTile
                textStack
                Spacer(minLength: Tokens.Spacing.sm)
                checkCircle
            }
            .padding(Tokens.Spacing.md)
            // Shadow HARUS di dalam .background, menempel pada bentuk kartunya.
            //
            // Kalau ditulis sebagai .shadow() setelah .background, SwiftUI
            // membayangi seluruh isi yang sudah tergabung — teks, tile maskot,
            // pill, dan lingkaran centang masing-masing ikut punya bayangan.
            // Pada opacity kecil itu tidak kelihatan, tapi di 25% hasilnya
            // halo kotor di sekeliling tiap elemen.
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                    .fill(Tokens.Palette.white)
                    // Sketch menyebut 25%, tapi di layar hasilnya terlalu gelap:
                    // latar kategori sudah berwarna pucat, jadi bayangan pekat
                    // membuatnya terlihat kotor. Diturunkan ke 10% — kartu tetap
                    // terangkat tapi tidak mendominasi. Naikkan lagi kalau
                    // nanti latarnya diganti jadi lebih putih.
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    private var mascotTile: some View {
        RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
            .fill(activity.category.cardBackground)
            .frame(width: 52, height: 52)
            .overlay(
                Image(activity.category.mascotName)
                    .resizable()
                    .scaledToFit()
                    .padding(Tokens.Spacing.sm)
            )
            // Maskot ikut meredup supaya baris yang sudah selesai mundur ke
            // latar belakang, bukan bersaing perhatian dengan yang belum.
            .opacity(isCompleted ? 0.55 : 1)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            Text(activity.name)
                .textStyle(Tokens.Typography.body)
                .strikethrough(isCompleted, color: Tokens.Semantic.footnote)
                .foregroundStyle(isCompleted ? Tokens.Semantic.footnote
                                             : Tokens.Semantic.text)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            pointsPill
                .opacity(isCompleted ? 0.6 : 1)
        }
    }

    /// "+5 pts" — angkanya dari `basePoints`, yang diturunkan dari FrictionLevel.
    private var pointsPill: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 9))
            Text("+\(activity.basePoints) pts")
                .textStyle(Tokens.Typography.footnote)
        }
        .foregroundStyle(activity.category.pillTextColor)
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(activity.category.cardBackground)
        )
    }

    private var checkCircle: some View {
        ZStack {
            Circle()
                .strokeBorder(isCompleted ? activity.category.pillTextColor
                                          : Tokens.Semantic.footnote.opacity(0.5),
                              lineWidth: 1.5)
                .background(
                    Circle().fill(isCompleted ? activity.category.pillTextColor : .clear)
                )
                .frame(width: 26, height: 26)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Palette.white)
            }
        }
    }
}

#Preview {
    let activities = MockActivityData.activities(in: .foodConsumption)

    ScrollView {
        VStack(spacing: Tokens.Spacing.md) {
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                ActivityRow(activity: activity, isCompleted: index == 1)
            }
        }
        .padding(Tokens.Spacing.lg)
    }
    .background(Tokens.Palette.orangeCard)
}
