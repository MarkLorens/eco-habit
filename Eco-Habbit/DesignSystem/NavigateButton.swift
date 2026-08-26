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
    case down
    case edit
    case close
    case share
    case love
    case plus
    case camera
    
    var action: String {
        switch self {
        case .back: "chevron.left"
        case .forward: "chevron.right"
        case .down: "chevron.down"
        case .edit: "square.and.pencil"
        case .close: "xmark"
        case .share: "square.and.arrow.up"
        case .love: "heart.fill"
        case .plus: "plus"
        case .camera: "camera.viewfinder"
        }
    }
}

struct NavigateBadge: View {
    let background: Color
    let buttonAction: ButtonAction
    var size: CGFloat = 36
    
    private var ellipseHeight: CGFloat { size * 30/36 }
    private var imageMultiplier: CGFloat { size-36 }
    
    var body: some View {
        ZStack{
            Circle()
                .frame(width: size, height: size)
                .foregroundStyle(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
            Ellipse()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(135))
                .foregroundStyle(background).opacity(1)
                .shadow(color: background.opacity(0.8), radius: 2, x: 0, y: 1)
                .shadow(color: background.opacity(0.4), radius: 10, x: 0, y: 6)
            Image(systemName: buttonAction.action)
                .font(.system(size: 20 + imageMultiplier, weight: .bold, design: .rounded))
        }
    }
}

struct NavigateButton: View {
    let background: Color
    let buttonAction: ButtonAction
    var size: CGFloat = 36
    let action: () -> Void
    
    init(background: Color, buttonAction: ButtonAction, size: CGFloat = 36, action: @escaping () -> Void) {
        self.background = background
        self.buttonAction = buttonAction
        self.size = size
        self.action = action
    }
    var body: some View {
        Button(action: action) {
            NavigateBadge(background: background, buttonAction: buttonAction, size: size)
        }
        .buttonStyle(.plain)
    }
}

#Preview{
    NavigateButton(background: Tokens.Palette.yellowCard, buttonAction: .edit) {
        print("edit!")
    }
}
