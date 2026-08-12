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
        case .home: return "Home"
        case .actions: return "Actions"
        case .ourFights: return "Our Fights"
//        case .camera: return "Camera"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .actions: return "leaf.fill"
//        case .camera: return "camera.fill"
        case .ourFights: return "trophy.fill"
        case .profile: return "person.fill"
        }
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab
    var onCapture: () -> Void = {}
    @Namespace private var pill
    
    // Separate first two and last two because Camera button isn't actually a tab item
    // I think?
    private var tabs: [AppTab] { Array(AppTab.allCases) }
    private var leadingTabs: ArraySlice<AppTab> { tabs.prefix(tabs.count / 2) }
    private var trailingTabs: ArraySlice<AppTab> { tabs.dropFirst(tabs.count / 2) }
    
    var body: some View{
        HStack(spacing: 0){
            ForEach(leadingTabs) { tabButton($0) }
            captureButton
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
            .frame(maxWidth: .infinity)
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
    
    // MARK: - This is the camera
    private var captureButton: some View {
        Button(action: onCapture){
            Image(systemName: "camera.fill")
                .textStyle(Tokens.Typography.icon)
                .foregroundStyle(Tokens.Semantic.tabviewBackground)
                .background {
                    Circle()
                        .fill(Tokens.Palette.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y:4)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Capture")
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
