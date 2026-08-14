//
//  NavigateButton.swift
//  Eco-Habbit
//
//  Created by Max on 12/08/26.
//
import SwiftUI

enum ButtonAction {
    case back
    case forward
    case close
    case share
    
    var action: String {
        switch self {
        case .back: "chevron.left"
        case .forward: "chevron.right"
        case .close: "xmark"
        case .share: "square.and.arrow.up"
        }
    }
}

struct NavigateBadge: View {
    let background: Color
    let buttonAction: ButtonAction
    
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
            Image(systemName: buttonAction.action)
                .textStyle(Tokens.Typography.title)
            
        }
    }
}

struct NavigateButton: View {
    let background: Color
    let buttonAction: ButtonAction
    let action: () -> Void
    
    init(background: Color, buttonAction: ButtonAction, action: @escaping () -> Void) {
        self.background = background
        self.buttonAction = buttonAction
        self.action = action
    }
    var body: some View {
        Button(action: action) {
            NavigateBadge(background: background, buttonAction: buttonAction)
        }
        .buttonStyle(.plain)
    }
}

#Preview{
    NavigateButton(background: Tokens.Palette.yellowCard, buttonAction: .close) {
        print("Tapped!")
    }
}
