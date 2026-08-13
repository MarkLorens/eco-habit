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
    private let points: Int?
    private let multiplier: Double
    private let onToggle: () -> Void

    /// `points` adalah poin SUNGGUHAN untuk baris ini — hasil proyeksi (kalau
    /// belum dikerjakan) atau yang benar-benar didapat (kalau sudah). Sengaja
    /// dioper sebagai nilai, bukan dibaca dari AppState: komponen ini tinggal di
    /// DesignSystem dan harus tetap bisa di-preview tanpa state apa pun.
    ///
    /// `nil` jatuh kembali ke `activity.basePoints`, yaitu perilaku lama.
    init(activity: Activity,
         isCompleted: Bool,
         points: Int? = nil,
         multiplier: Double = 1.0,
         onToggle: @escaping () -> Void = {}) {
        self.activity = activity
        self.isCompleted = isCompleted
        self.points = points
        self.multiplier = multiplier
        self.onToggle = onToggle
    }

    private var displayedPoints: Int { points ?? activity.basePoints }

    /// Tag pengali hanya muncul kalau memang ada bonusnya, dan tidak pernah pada
    /// baris yang sudah selesai — angka di situ sudah final, bukan tawaran.
    private var showsMultiplier: Bool { multiplier > 1.0 && !isCompleted }

    /// Cap harian sudah habis: baris jujur menampilkan 0, bukan angka penuh yang
    /// tidak akan pernah dibayar.
    private var isWorthless: Bool { displayedPoints == 0 && !isCompleted }

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

            HStack(spacing: Tokens.Spacing.sm) {
                pointsPill
                    .opacity(isCompleted ? 0.6 : 1)

                if showsMultiplier {
                    multiplierTag
                }
            }
        }
    }

    /// "+14 pts" — poin sungguhan, streak dan cap sudah ikut dihitung.
    private var pointsPill: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 9))
            Text("+\(displayedPoints) pts")
                .textStyle(Tokens.Typography.footnote)
        }
        .foregroundStyle(isWorthless ? Tokens.Semantic.footnote
                                     : activity.category.pillTextColor)
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(isWorthless ? Tokens.Semantic.footnote.opacity(0.12)
                                       : activity.category.cardBackground)
        )
    }

    /// Sengaja teks polos, bukan kapsul kedua. Pill poin harus tetap jadi angka
    /// utama — dua kapsul bersebelahan membuat baris terlihat seperti punya dua
    /// nilai yang setara.
    private var multiplierTag: some View {
        Text("×\(multiplier.formatted(.number.precision(.fractionLength(0...2))))")
            .textStyle(Tokens.Typography.footnote)
            .foregroundStyle(Tokens.Semantic.footnote)
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
                // Streak 30 hari: pengali 1,35 dan poin sudah dikalikan, seperti
                // yang dilihat user sungguhan.
                ActivityRow(
                    activity: activity,
                    isCompleted: index == 1,
                    points: index == 3 ? 0   // contoh cap harian habis
                        : Int((Double(activity.basePoints) * 1.35).rounded()),
                    multiplier: 1.35
                )
            }
        }
        .padding(Tokens.Spacing.lg)
    }
    .background(Tokens.Palette.orangeCard)
}
