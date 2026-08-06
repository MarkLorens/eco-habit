//
//  Eco_HabbitApp.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 06/08/26.
//

import SwiftUI

@main
struct Eco_HabbitApp: App {
    @StateObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FontLoader.registerBundledFonts()
        #if DEBUG
        _appState = StateObject(wrappedValue: AppState.fromLaunchArguments() ?? AppState())
        #else
        _appState = StateObject(wrappedValue: AppState())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    // A streak can go stale and Earth Points can decay while the app
                    // is backgrounded, so re-evaluate on every return to foreground.
                    if phase == .active { appState.refreshForToday() }
                }
        }
    }
}
