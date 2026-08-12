//
//  MainTabBar.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 12/08/26.
//
//  Butuh   : Tokens
//  Dipakai : RootView
//

import SwiftUI

/// Tab yang tersedia. Slot kamera di tengah bukan tab — dia tombol aksi,
/// jadi tidak ikut jadi case di sini.
enum MainTab: String, CaseIterable, Identifiable {
    case home
    case practices
    case ourFights
    case profile

    var id: String { rawValue }

    /// Sketch menulis tab kedua sebagai "Practices" di satu layar dan "Actions"
    /// di layar lain. Dipilih "Practices" karena "Actions" sudah dipakai sebagai
    /// nama salah satu dari 6 kategori.
    var title: String {
        switch self {
        case .home:      return "Home"
        case .practices: return "Practices"
        case .ourFights: return "Our Fights"
        case .profile:   return "Profile"
        }
    }

    /// Home dan Our Fights pakai SF Symbols karena asset `globe-tabview` dan
    /// `fist-tabview` yang ada di repo tidak cocok dengan rumah dan piala di Sketch.
    /// Practices dan Profile tetap memakai asset tim.
    var icon: TabIcon {
        switch self {
        case .home:      return .symbol("house.fill")
        case .practices: return .asset(Tokens.Icons.leafTabview)
        case .ourFights: return .symbol("trophy.fill")
        case .profile:   return .asset(Tokens.Icons.profileTabView)
        }
    }

    var activeIcon: TabIcon {
        switch self {
        case .home:      return .symbol("house.fill")
        case .practices: return .asset(Tokens.Icons.leafTabviewActive)
        case .ourFights: return .symbol("trophy.fill")
        case .profile:   return .asset(Tokens.Icons.profileTabViewActive)
        }
    }
}

/// Ikon tab bisa datang dari dua sumber, jadi jenisnya dibuat eksplisit
/// ketimbang menebak dari nama string.
enum TabIcon {
    case asset(String)
    case symbol(String)
}

struct MainTabBar: View {

    @Binding var selection: MainTab
    var onCameraTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.practices)
            cameraButton
            tabButton(.ourFights)
            tabButton(.profile)
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.sm)
        .background(
            Capsule().fill(Tokens.Semantic.tabviewBackground)
        )
        .padding(.horizontal, Tokens.Spacing.lg)
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selection == tab

        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                iconView(isSelected ? tab.activeIcon : tab.icon, isSelected: isSelected)
                    .frame(width: 22, height: 22)

                Text(tab.title)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Palette.white.opacity(isSelected ? 1 : 0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(isSelected ? Tokens.Semantic.tabviewActive : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconView(_ icon: TabIcon, isSelected: Bool) -> some View {
        switch icon {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()

        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.Palette.white.opacity(isSelected ? 1 : 0.6))
        }
    }

    /// Tombol kamera mengambang di tengah. Ukurannya melebihi tinggi bar,
    /// jadi dibiarkan meluap ke atas seperti di Sketch.
    private var cameraButton: some View {
        Button(action: onCameraTap) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.white)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)

                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Tokens.Semantic.text)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @State var selection: MainTab = .practices

    VStack {
        Spacer()
        MainTabBar(selection: $selection)
    }
    .background(Tokens.Palette.greenFaint)
}
