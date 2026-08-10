//
//  Tokens.swift
//  Eco-Habbit
//
//  Created by Max on 10/08/26.
//

import SwiftUI

enum Tokens {}

// MARK: - Our Base Color
extension Tokens{
    
    enum Palette {
        // MARK: - Shade of Greens
        static let greenDarkest = Color(hex: 0x5E9B62)
        static let green = Color(hex: 0x6FAF73)
        static let greenLight = Color(hex: 0x8ACB88)
        static let greenFaint = Color(hex: 0xDCEFD9)
        static let greenFaintest = Color(hex: 0xEAF6E8)
        
        // MARK: - Black to White
        static let black = Color(hex: 0x2F3A32)
        static let gray = Color(hex: 0x6B766E)
        static let grayLight = Color(hex: 0x9AA59C)
        static let grayMute = Color(hex: 0xF2F5F1)
        static let ink = Color(hex: 0xF2F5F1)
        static let white = Color(hex: 0xFFFFFF)
        
        // MARK: - Specific semantics
        static let bgGradientMiddle = Color(hex: 0xF8FAF7)
        static let bgColor = LinearGradient(
            stops:[
                .init(color: greenFaintest, location: 0.0),
                .init(color: bgGradientMiddle, location: 0.45),
                .init(color: white, location: 0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Typography

extension Tokens {
    
    // Custom TextStyle from our Sketch
    // Remember to use Tokens.Typography.[class] instead of styling your own guys.
    // Any new specific styling please add here before coding into our View
    struct TextStyle {
        let font: Font
        let tracking: CGFloat
        let lineSpacing: CGFloat
        
        init(_ font: Font, tracking: CGFloat = 0, lineSpacing: CGFloat = 0) {
            self.font = font
            self.tracking = tracking
            self.lineSpacing = lineSpacing
        }
    }
    
    enum Typography {
        static let icon = TextStyle(.system(size: 30, weight: .bold))
        static let hero = TextStyle(.system(size: 28, weight: .heavy))
        static let title = TextStyle(.system(size: 20, weight: .bold))
        static let body = TextStyle(.system(size: 16, weight: .semibold))
        static let footnote = TextStyle(.system(size: 12, weight: .regular))
    }
}

// This applies our custom textStyle. Please no touchy
extension View {
    func textStyle(_ style: Tokens.TextStyle) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}


// MARK: - Spacing

extension Tokens {
    
    // Fely rules: 4 multiplier. Add as necessary.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    // Comment out and add down here if you need a more specific ruling
//    enum Layout {
//        static let heading: CGFloat = 20 // example
//    }
}

// MARK: - Radius

extension Tokens {
    
    // This is for border radius
    enum Radius {
        static let basicCards: CGFloat = 10 // Category and activity list cards
        static let pill: CGFloat = 22 // Our Fights Segmented Views
        static let sheet: CGFloat = 60 // White sheet in profile view
    }
}

// MARK: - Icons

extension Tokens {
    
    // Since we're using our own asset and not SF Symbols.
    // Okay, camera is from SF Symbols. Shut up
    enum Icons {
        // MARK: - Tab View Icons
        static let globeTabview = "globe-tabview"
        static let leafTabview = "leaf-tabview"
        static let fistTabview = "fist-tabview"
        static let profileTabView = "profile-tabview"
        static let globeTabViewActive = "globe-tabview-active"
        static let leafTabviewActive = "leaf-tabview-active"
        static let fistTabviewActive = "fist-tabview-active"
        static let profileTabViewActive = "profile-tabview-active"
        
        // MARK: - Rest of assets
        static let lightBulb = "light-bulb"
        static let trash = "trash"
        static let burger = "burger"
        static let smoke = "smoke"
        static let water = "water"
        static let tree = "tree"
        
        // MARK: - Shadow
        static let yellowShadow = "yellow-shadow"
        static let greenShadow = "green-shadow"
        static let orangeShadow = "orange-shadow"
        static let blackShadow = "black-shadow"
        static let blueShadow = "blue-shadow"
        
//        static let dashboardGlobe = "dashboard-globe" placeholder for our 3D asset
    }
}
