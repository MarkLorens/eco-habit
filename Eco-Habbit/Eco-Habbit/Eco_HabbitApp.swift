//
//  Eco_HabbitApp.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 06/08/26.
//

import SwiftUI

@main
struct Eco_HabbitApp: App {

    // Satu store untuk seluruh app. Dibuat di sini supaya umurnya sepanjang
    // umur app, bukan sepanjang umur satu View.
    @State private var store = AppStore()

    // Font bundel didaftarkan sekali di sini. Tanpa ini Tokens.Typography
    // jatuh ke font sistem dan tampilannya meleset dari Sketch.
    init() {
        FontLoader.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task {
                    // Decay dihitung di sini — saat app dibuka, bukan oleh
                    // proses latar belakang.
                    await store.bootstrap()
                }
        }
    }
}
