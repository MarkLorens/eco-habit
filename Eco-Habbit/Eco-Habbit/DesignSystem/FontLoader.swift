//
//  FontLoader.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : file .ttf di Resources/Fonts/
//  Dipakai : Eco_HabbitApp (dipanggil sekali saat launch)
//

import CoreText
import UIKit

/// Mendaftarkan font bundel saat launch.
///
/// Cara ini dipilih daripada `UIAppFonts` di Info.plist karena project ini pakai
/// synchronized folder — TTF-nya bisa mendarat di subdirektori bundle yang tidak
/// dilihat lookup Info.plist. Mendaftarkan manual membuat `Font.custom` selalu
/// ketemu, dan tidak perlu menyentuh project.pbxproj sama sekali.
enum FontLoader {

    static func registerBundledFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])

        for url in Set(urls) {
            // Font yang sudah terdaftar akan gagal di sini; itu no-op yang diharapkan.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        #if DEBUG
        let missing = [Tokens.Fonts.display, Tokens.Fonts.body]
            .filter { UIFont(name: $0, size: 12) == nil }
        if !missing.isEmpty {
            print("[EcoHabit] Font tidak tersedia, jatuh ke font sistem: \(missing)")
        }
        #endif
    }
}
