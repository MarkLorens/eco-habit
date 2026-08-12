//
//  EarthGlobeView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : BlobShape, EarthStage, Tokens
//  Dipakai : DashboardView
//
//  Bumi digambar sepenuhnya dengan kode, bukan asset. Alasannya: earth.svg dari
//  Sketch isinya PNG raster, jadi tidak ada lapisan yang bisa dinyalakan atau
//  dimatikan per stage. Versi kode membuat tiap elemen — pohon, tunas, awan,
//  teman-teman maskot, dan warna daratan — bisa dikendalikan EarthStage.
//

import SwiftUI

struct EarthGlobeView: View {

    let stage: EarthStage

    /// Menganimasikan perubahan saat stage naik atau turun.
    var animated: Bool = true

    var body: some View {
        GeometryReader { proxy in
            // Semua ukuran dan posisi relatif terhadap diameter bumi, sehingga
            // komposisinya tetap sama di layar kecil maupun besar.
            let diameter = min(proxy.size.width, proxy.size.height) * 0.66

            ZStack {
                globe(diameter: diameter)
                satellites(diameter: diameter)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(animated ? .easeInOut(duration: 0.45) : nil, value: stage)
        }
    }

    // MARK: - Bumi

    private func globe(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Appearance.oceanColor)

            landmasses(diameter: diameter)
                .clipShape(Circle())

            BlobEyes(
                eyeSize: diameter * 0.13,
                spacing: diameter * 0.06,
                pupilOffset: appearance.eyePupilOffset
            )
            .offset(y: -diameter * 0.04)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Empat gumpalan daratan. Bentuknya tidak meniru peta sungguhan — ilustrasi
    /// aslinya pun tidak — yang penting siluetnya organik dan seimbang.
    private func landmasses(diameter: CGFloat) -> some View {
        let land = appearance.landColor

        // Jari-jari sengaja dijaga di rentang 0.72–1.0. Variasi yang lebih ekstrem
        // membuat kurva Catmull-Rom saling potong dan siluetnya jadi berlekuk aneh.
        return ZStack {
            BlobShape(radii: [1.0, 0.86, 0.94, 0.78, 0.98, 0.82, 0.9, 0.88])
                .fill(land)
                .frame(width: diameter * 0.62, height: diameter * 0.5)
                .offset(x: -diameter * 0.2, y: -diameter * 0.24)

            BlobShape(radii: [0.92, 0.84, 1.0, 0.76, 0.9, 0.88, 0.96, 0.8],
                      rotation: .degrees(35))
                .fill(land)
                .frame(width: diameter * 0.54, height: diameter * 0.62)
                .offset(x: diameter * 0.3, y: diameter * 0.02)

            BlobShape(radii: [0.96, 0.8, 0.9, 0.86, 1.0, 0.78, 0.92, 0.84],
                      rotation: .degrees(-20))
                .fill(land)
                .frame(width: diameter * 0.58, height: diameter * 0.44)
                .offset(x: -diameter * 0.24, y: diameter * 0.32)
        }
    }

    // MARK: - Elemen di sekeliling bumi

    @ViewBuilder
    private func satellites(diameter: CGFloat) -> some View {
        ZStack {
            // Awan selalu ada, tapi warnanya berubah: keabuan saat bumi kritis,
            // krem bersih saat pulih.
            cloud(size: diameter * 0.28)
                .offset(x: -diameter * 0.52, y: diameter * 0.12)

            cloud(size: diameter * 0.3)
                .offset(x: diameter * 0.5, y: -diameter * 0.2)

            cloud(size: diameter * 0.28)
                .offset(x: diameter * 0.46, y: diameter * 0.32)

            if appearance.showsSprout {
                sprout(size: diameter * 0.26)
                    .offset(x: diameter * 0.32, y: -diameter * 0.44)
            }

            if appearance.showsTree {
                tree(size: diameter * 0.34)
                    .offset(x: -diameter * 0.36, y: -diameter * 0.42)
            }

            if appearance.showsSunFriend {
                friend(
                    size: diameter * 0.34,
                    color: Tokens.Palette.yellow,
                    radii: [1.0, 0.84, 0.96, 0.8, 1.0, 0.82, 0.94, 0.86]
                )
                .offset(x: -diameter * 0.02, y: -diameter * 0.5)
            }

            if appearance.showsWaterFriend {
                friend(
                    size: diameter * 0.24,
                    color: Tokens.Palette.blueLight,
                    radii: [0.98, 0.86, 0.94, 0.82, 1.0, 0.84, 0.92, 0.88]
                )
                .offset(x: -diameter * 0.5, y: -diameter * 0.16)
            }

            if appearance.showsWarmFriend {
                friend(
                    size: diameter * 0.24,
                    color: Tokens.Palette.orange,
                    radii: [1.0, 0.84, 0.94, 0.8, 0.96, 0.86, 0.9, 0.82]
                )
                .offset(x: diameter * 0.5, y: diameter * 0.02)
            }
        }
    }

    /// Awan disusun dari lingkaran bertumpuk, bukan satu gumpalan.
    /// BlobShape menghasilkan bentuk terlalu membulat seragam untuk ini —
    /// awan butuh siluet bergelombang dengan alas rata.
    private func cloud(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(x: -size * 0.28, y: size * 0.08)

            Circle()
                .frame(width: size * 0.74, height: size * 0.74)
                .offset(x: 0, y: -size * 0.04)

            Circle()
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: size * 0.3, y: size * 0.1)

            Capsule()
                .frame(width: size * 1.05, height: size * 0.42)
                .offset(y: size * 0.16)
        }
        .foregroundStyle(appearance.cloudColor)
        .frame(width: size * 1.2, height: size * 0.8)
    }

    /// Maskot kecil: gumpalan berwarna dengan mata.
    private func friend(size: CGFloat, color: Color, radii: [CGFloat]) -> some View {
        BlobShape(radii: radii)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                BlobEyes(eyeSize: size * 0.26, spacing: size * 0.08)
                    .offset(y: -size * 0.02)
            )
    }

    /// Tajuk pohon = tiga lingkaran bertumpuk, mengikuti ilustrasi aslinya.
    private func tree(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(Color(hex: 0x9C6B3F))
                .frame(width: size * 0.13, height: size * 0.52)
                .offset(x: size * 0.02, y: size * 0.3)

            ZStack {
                Circle()
                    .frame(width: size * 0.56, height: size * 0.56)
                    .offset(x: -size * 0.24, y: size * 0.06)

                Circle()
                    .frame(width: size * 0.54, height: size * 0.54)
                    .offset(x: size * 0.24, y: size * 0.04)

                Circle()
                    .frame(width: size * 0.62, height: size * 0.62)
                    .offset(y: -size * 0.14)
            }
            .foregroundStyle(Tokens.Palette.greenDark)
        }
        .frame(width: size, height: size)
    }

    private func sprout(size: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Tokens.Palette.greenDark)
                .frame(width: size * 0.08, height: size * 0.62)
                .offset(y: size * 0.16)

            Ellipse()
                .fill(Tokens.Palette.greenDark)
                .frame(width: size * 0.44, height: size * 0.3)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.22, y: -size * 0.08)

            Ellipse()
                .fill(Tokens.Palette.green)
                .frame(width: size * 0.5, height: size * 0.34)
                .rotationEffect(.degrees(22))
                .offset(x: size * 0.2, y: -size * 0.18)
        }
    }

    // MARK: - Tampilan per stage

    private var appearance: Appearance { Appearance(stage: stage) }

    /// Satu-satunya tempat yang memutuskan bumi terlihat seperti apa di tiap stage.
    /// Menambah elemen baru cukup menambah satu properti di sini.
    struct Appearance {

        let stage: EarthStage

        static let oceanColor = Tokens.Palette.blue

        /// Daratan bergerak dari tanah kering kecoklatan menuju hijau subur.
        var landColor: Color {
            switch stage {
            case .critical:     return Color(hex: 0xB9A98C)
            case .fragile:      return Color(hex: 0xC6C57C)
            case .stabilizing:  return Color(hex: 0xAFCC6B)
            case .recovering:   return Color(hex: 0x9BCB53)
            case .flourishing:  return Color(hex: 0x8CC63F)
            case .restored:     return Color(hex: 0x7FC13A)
            }
        }

        var cloudColor: Color {
            switch stage {
            case .critical:     return Color(hex: 0xBFBDB6)
            case .fragile:      return Color(hex: 0xD5D2C9)
            default:            return Color(hex: 0xEDE7DC)
            }
        }

        /// Bumi menunduk saat kritis, menatap lurus saat sudah pulih.
        var eyePupilOffset: CGSize {
            switch stage {
            case .critical, .fragile: return CGSize(width: 0, height: 1.4)
            default:                  return CGSize(width: 0, height: 0.6)
            }
        }

        var showsSprout: Bool      { stage >= .stabilizing }
        var showsTree: Bool        { stage >= .recovering }
        var showsWaterFriend: Bool { stage >= .recovering }
        var showsSunFriend: Bool   { stage >= .flourishing }
        var showsWarmFriend: Bool  { stage >= .restored }
    }
}

#Preview("Semua stage") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(EarthStage.allCases, id: \.self) { stage in
                VStack(spacing: 4) {
                    EarthGlobeView(stage: stage, animated: false)
                        .frame(height: 220)

                    Text(stage.displayName)
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                }
            }
        }
    }
}
