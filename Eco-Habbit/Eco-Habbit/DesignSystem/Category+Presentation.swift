//
//  Category+Presentation.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Category (Models/), Tokens (DesignSystem/)
//  Dipakai : DailyPracticesView, CategoryDetailView, ActivityRow
//

import SwiftUI

// Tampilan kategori dipisah dari modelnya supaya Models/Category.swift tetap cuma
// butuh Foundation. Semua teks dan warna yang muncul di Sketch ada di sini.
extension Category {

    /// Judul di kartu dan header layar. Sengaja beda dengan `displayName`:
    /// Sketch memakai "Consumption", spec memakai "Food & Consumption".
    var shortTitle: String {
        switch self {
        case .foodConsumption:  return "Consumption"
        case .water:            return "Water"
        case .wasteManagement:  return "Waste"
        case .energy:           return "Energy"
        case .mobility:         return "Mobility"
        case .actions:          return "Actions"
        }
    }

    /// Caption dua baris di kartu grid, mengikuti Sketch.
    var tagline: String {
        switch self {
        case .foodConsumption:  return "Consume less\nLive better"
        case .water:            return "Every drop matters"
        case .wasteManagement:  return "Less waste today\nCleaner tomorrow"
        case .energy:           return "Safe energy\nPower a better future"
        case .mobility:         return "Move smarter\nTravel greener"
        case .actions:          return "Small steps\nCreate big impacts"
        }
    }

    var mascotName: String {
        switch self {
        case .foodConsumption:  return Tokens.Icons.mascotConsumption
        case .water:            return Tokens.Icons.mascotWater
        case .wasteManagement:  return Tokens.Icons.mascotWaste
        case .energy:           return Tokens.Icons.mascotEnergy
        case .mobility:         return Tokens.Icons.mascotMobility
        case .actions:          return Tokens.Icons.mascotActions
        }
    }

    /// Latar kartu dan tile — versi pucat.
    var cardBackground: Color {
        switch self {
        case .foodConsumption:  return Tokens.Palette.orangeCard
        case .water:            return Tokens.Palette.blueCardSoft
        case .wasteManagement:  return Tokens.Palette.purpleCard
        case .energy:           return Tokens.Palette.yellowCard
        case .mobility:         return Tokens.Palette.greenCard
        case .actions:          return Tokens.Palette.limeCard
        }
    }

    /// Warna teks untuk pill "+N pts" dan lingkaran centang terisi.
    ///
    /// Dipisah dari `accentColor` karena warna dasar kategori terlalu pucat untuk
    /// teks — di atas pill yang bernuansa sama, tulisannya nyaris hilang.
    ///
    /// Waste dan Energy diukur langsung dari Sketch. Empat lainnya belum ada
    /// desainnya, jadi diperlakukan dengan cara yang sama: versi lebih gelap dan
    /// lebih pekat dari warna dasar. Ganti begitu desainer menentukan nilainya.
    var pillTextColor: Color {
        switch self {
        case .wasteManagement:  return Color(hex: 0xC67AC8)   // dari Sketch
        case .energy:           return Color(hex: 0xC3B944)   // dari Sketch
        case .water:            return Tokens.Palette.blue
        case .foodConsumption:  return Tokens.Palette.orange
        case .mobility:         return Tokens.Palette.greenDark
        case .actions:          return Color(hex: 0x8CA33A)   // perkiraan
        }
    }

    /// Warna pekat untuk aksen selain teks.
    var accentColor: Color {
        switch self {
        case .foodConsumption:  return Tokens.Palette.orange
        case .water:            return Tokens.Palette.blue
        case .wasteManagement:  return Tokens.Palette.purple
        case .energy:           return Tokens.Palette.yellow
        case .mobility:         return Tokens.Palette.green
        case .actions:          return Tokens.Palette.lime
        }
    }

    /// Subjudul di header layar daftar aksi.
    var detailSubtitle: String {
        "Every action you take counts!\nCheck them off as you go"
    }

    /// Urutan kartu di grid, mengikuti Sketch.
    ///
    /// Dipisah dari `allCases` dengan sengaja: urutan deklarasi enum mengikuti
    /// urutan di spec produk, sedangkan urutan tampil adalah keputusan desain.
    /// Mengubah salah satunya tidak boleh diam-diam mengubah yang lain.
    static let displayOrder: [Category] = [
        .energy, .wasteManagement,
        .actions, .water,
        .mobility, .foodConsumption
    ]
}
