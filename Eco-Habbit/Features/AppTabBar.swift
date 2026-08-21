//
//  AppTabBar.swift
//  Eco-Habbit
//
//  Created by Max on 11/08/26.
//

import SwiftUI

// MARK: - Tab enum

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case actions
//    case camera
    case ourFights
    case profile
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .home: return "My Earth"
        case .actions: return "Practices"
        case .ourFights: return "Our Fights"
//        case .camera: return "Camera"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "globe.americas.fill"
        case .actions: return "leaf.fill"
//        case .camera: return "camera.fill"
        case .ourFights: return "shield.fill"
        case .profile: return "person.fill"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab

    /// Which tabs to draw. Defaults to all of them, so the preview and any existing
    /// caller are unchanged — an organisation passes a shorter list, because it has no
    /// habits to log and no dashboard to look at.
    var tabs: [AppTab] = AppTab.allCases

    /// The camera logs habits, so it goes with them.
    var showsCapture = true

    /// Whether the bar spans the screen or hugs its contents.
    ///
    /// Four tabs plus the camera fill the width and want equal columns. Two tabs do not
    /// — stretched across a phone they sit marooned at the far edges with a lake of
    /// black between them. The hi-fi shows a small pill in the middle, which is what
    /// hugging gives, since `MainTabView` centres the bar anyway.
    var fillsWidth = true

    var onCapture: () -> Void = {}
    @Namespace private var pill

    // Separate first two and last two because Camera button isn't actually a tab item
    // I think?
    private var leadingTabs: ArraySlice<AppTab> { tabs.prefix(tabs.count / 2) }
    private var trailingTabs: ArraySlice<AppTab> { tabs.dropFirst(tabs.count / 2) }

    var body: some View{
        HStack(spacing: 0){
            ForEach(leadingTabs) { tabButton($0) }
            ForEach(trailingTabs) { tabButton($0) }
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .padding(.horizontal, Tokens.Spacing.md)
        .background {
            Capsule(style: .continuous)
                .fill(Tokens.Semantic.tabviewBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 8)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        // Hugging is the default for an `HStack`; the width only comes from the tab
        // buttons expanding, so this stops them.
        .fixedSize(horizontal: !fillsWidth, vertical: false)
    }
    
    // MARK: - Building the tabs
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = tab == selection
        
        return Button {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.1)){
                selection = tab
            }
        } label: {
            VStack(spacing: 4){
                Image(systemName: tab.icon)
                    .textStyle(Tokens.Typography.title)
                Text(tab.title)
                    .textStyle(Tokens.Typography.tabview)
            }
            .foregroundStyle(
                isSelected
                ? Tokens.Palette.white
                : Tokens.Palette.white.opacity(0.55)
            )
            // Equal columns when the bar fills the screen; intrinsic width when it is a
            // pill, so the two items sit together rather than at opposite edges.
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.horizontal, fillsWidth ? 0 : Tokens.Spacing.lg)
            .padding(.vertical, Tokens.Spacing.sm)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Tokens.Semantic.tabviewActive)
                        .matchedGeometryEffect(id: "activePill", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// `AppTabView` removed — MainTabView is the real container and drives this bar
// with `app.selectedTab`. The preview below exercises the bar on its own, which
// is what you want when working on the bar itself.
#Preview {
    @Previewable @State var selection: AppTab = .home

    ZStack(alignment: .bottom) {
        Tokens.Palette.limeCard.ignoresSafeArea()
        AppTabBar(selection: $selection)
    }
}
