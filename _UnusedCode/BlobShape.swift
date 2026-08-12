//
//  BlobShape.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : —
//  Dipakai : EarthGlobeView
//

import SwiftUI

/// Bentuk organik tertutup, dibuat dari daftar jari-jari pada sudut yang dibagi rata.
///
/// Semua ilustrasi di Sketch berupa gumpalan membulat tanpa sudut tajam, jadi satu
/// shape yang bisa diatur jari-jarinya cukup untuk membuat benua, awan, maupun maskot
/// — tidak perlu menulis path bezier terpisah untuk tiap gambar.
struct BlobShape: Shape {

    /// Jari-jari tiap titik, 0–1 relatif terhadap setengah sisi terpendek.
    /// Jumlah elemen menentukan berapa titik yang dipakai mengelilingi bentuk.
    let radii: [CGFloat]

    /// Memutar seluruh bentuk, supaya blob yang sama bisa dipakai ulang
    /// dengan orientasi berbeda tanpa menulis radii baru.
    var rotation: Angle = .zero

    func path(in rect: CGRect) -> Path {
        guard radii.count >= 3 else { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        let step = (2 * .pi) / CGFloat(radii.count)

        let points: [CGPoint] = radii.enumerated().map { index, radius in
            let angle = step * CGFloat(index) + CGFloat(rotation.radians)
            return CGPoint(
                x: center.x + cos(angle) * radius * maxRadius,
                y: center.y + sin(angle) * radius * maxRadius
            )
        }

        // Catmull-Rom yang dikonversi ke kurva kubik: kurvanya BENAR-BENAR melewati
        // setiap titik yang dihitung di atas.
        //
        // Percobaan pertama memakai kurva kuadratik lewat titik tengah antar titik.
        // Hasilnya salah: dengan jari-jari berselang-seling besar-kecil, bentuknya
        // menciut jadi serpihan tipis karena kurvanya tidak pernah menyentuh titik
        // terjauh. Di sini jari-jari yang ditulis benar-benar jadi jari-jari.
        var path = Path()
        let count = points.count
        path.move(to: points[0])

        for index in 0..<count {
            let p0 = points[(index - 1 + count) % count]
            let p1 = points[index]
            let p2 = points[(index + 1) % count]
            let p3 = points[(index + 2) % count]

            // Faktor 1/6 adalah konversi baku Catmull-Rom → Bezier. Angka lebih
            // besar membuat kurva melar keluar dan saling potong.
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                                   y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                                   y: p2.y - (p3.y - p1.y) / 6)

            path.addCurve(to: p2, control1: control1, control2: control2)
        }

        path.closeSubpath()
        return path
    }
}

/// Sepasang mata bergaya Sketch: putih besar dengan pupil hitam yang digeser.
struct BlobEyes: View {

    var eyeSize: CGFloat
    var spacing: CGFloat
    /// Geseran pupil, dipakai untuk mengarahkan pandangan.
    var pupilOffset: CGSize = CGSize(width: 0, height: 1)

    var body: some View {
        HStack(spacing: spacing) {
            eye
            eye
        }
    }

    private var eye: some View {
        ZStack {
            Ellipse()
                .fill(.white)
                .frame(width: eyeSize, height: eyeSize * 1.25)

            Circle()
                .fill(.black)
                .frame(width: eyeSize * 0.62, height: eyeSize * 0.62)
                .offset(x: pupilOffset.width * eyeSize * 0.18,
                        y: pupilOffset.height * eyeSize * 0.18)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        BlobShape(radii: [1.0, 0.86, 0.95, 0.8, 1.0, 0.88, 0.93, 0.82])
            .fill(Tokens.Palette.yellow)
            .frame(width: 140, height: 140)
            .overlay(BlobEyes(eyeSize: 22, spacing: 8))

        BlobShape(radii: [0.95, 0.7, 1.0, 0.75, 0.9, 0.72, 1.0, 0.78, 0.88, 0.7])
            .fill(Tokens.Palette.orange)
            .frame(width: 140, height: 140)
            .overlay(BlobEyes(eyeSize: 20, spacing: 6))
    }
    .padding()
}
