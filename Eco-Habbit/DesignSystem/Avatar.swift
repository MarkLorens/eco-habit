//
//  Avatar.swift
//  Eco-Habbit
//
//  Created by Max on 13/08/26.
//

import SwiftUI

enum avatarType{
    case user
    case avatarBig
    case avatarSmall
    case avatarOurFight
    
    var size: CGFloat{
        switch self{
        case .avatarSmall:
            75
        case .avatarOurFight:
            38
        default:
            100
        }
    }
    
    var background: Color{
        switch self{
        case .user:
            Tokens.Palette.purpleCard
        default:
            Tokens.Palette.limeCard
        }
        
    }
}

struct Avatar: View {
    private let type: avatarType
    private let icon: String
    
    init(type: avatarType, icon: String) {
        self.type = type
        self.icon = icon
    }
    
    var body: some View{
        ZStack (alignment: .center){
            Circle()
                .fill(type.background)
                .frame(width: type.size, height: type.size)
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: type.size - 15, alignment: .center)
        }
    }
}

/// The locked counterpart of `Avatar`: the badge art drained of colour behind a
/// lock, so a locked badge still reads as *which* badge it is rather than as an
/// anonymous grey disc.
struct LockedAvatar: View {
    private let type: avatarType
    private let icon: String

    init(type: avatarType, icon: String) {
        self.type = type
        self.icon = icon
    }

    var body: some View{
        ZStack (alignment: .center){
            Circle()
                .fill(Tokens.Semantic.statIcon)
                .frame(width: type.size, height: type.size)
            Image(icon)
                .resizable()
                .scaledToFit()
                .grayscale(1.0)
                .frame(width: type.size * 0.75, height: type.size * 0.75)
            Image(systemName: "lock.fill")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)
        }
    }
}

struct AvatarIcon: View {
    private let type: avatarType
    private let icon: String
    
    init(type: avatarType, icon: String) {
        self.type = type
        self.icon = icon
    }
    
    var body: some View{
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: type.size - 15, alignment: .center)
    }
}

#Preview {
    VStack{
        Avatar(type: .user, icon: Tokens.Icons.wasteIcon)
        Avatar(type: .avatarBig, icon: Tokens.Icons.energyIcon)
        LockedAvatar(type: .avatarBig, icon: Tokens.Icons.energyIcon)
        AvatarIcon(type: .avatarOurFight, icon: Tokens.Icons.mobilityIcon)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
//    .background(Tokens.Palette.limeCard)
    .ignoresSafeArea()
}
