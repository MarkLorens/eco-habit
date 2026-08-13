//
//  NavigateButton.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

enum NavigateDirection {
    case left
    case right
    
    var chevron: String {
        switch self {
        case .left: "chevron.left"
        case .right: "chevron.right"
        }
    }
}

struct NavigateBadge: View {
    let background: Color
    let direction: NavigateDirection
    
    var body: some View {
        ZStack{
            Circle()
                .frame(width: 36, height: 36)
                .foregroundStyle(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
            Ellipse()
                .frame(width: 36, height: 30)
                .rotationEffect(.degrees(135))
                .foregroundStyle(background).opacity(1)
                .shadow(color: background.opacity(0.8), radius: 2, x: 0, y: 1)
                .shadow(color: background.opacity(0.4), radius: 10, x: 0, y: 6)
            Image(systemName: direction.chevron)
                .textStyle(Tokens.Typography.title)
            
        }
    }
}

struct NavigateButton: View {
    let background: Color
    let direction: NavigateDirection
    let action: () -> Void
    
    init(background: Color, direction: NavigateDirection, action: @escaping () -> Void) {
        self.background = background
        self.direction = direction
        self.action = action
    }
    var body: some View {
        Button(action: action) {
            NavigateBadge(background: background, direction: direction)
        }
        .buttonStyle(.plain)
    }
}

#Preview{
    NavigateButton(background: Tokens.Palette.yellowCard, direction: .left) {
        print("Tapped!")
    }
}
