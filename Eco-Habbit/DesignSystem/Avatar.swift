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
    
    var size: CGFloat{
        switch self{
        case .user:
            100
        case .avatarBig:
            100
        case .avatarSmall:
            75
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

#Preview {
    VStack{
        Avatar(type: .user, icon: Tokens.Icons.wasteIcon)
        Avatar(type: .avatarBig, icon: Tokens.Icons.energyIcon)
        Avatar(type: .avatarSmall, icon: Tokens.Icons.mobilityIcon)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Tokens.Palette.limeCard)
    .ignoresSafeArea()
}
