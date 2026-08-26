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
            // MARK: - Lime
            static let lime = Color(hex: 0xBFD95A)
            static let limeCard = Color(hex: 0xF0FCC7)
     
            // MARK: - Orange
            static let orange = Color(hex: 0xF15A29)
            static let orangeCard = Color(hex: 0xFFD9CC)
     
            // MARK: - Blue
            static let blue = Color(hex: 0x3984E8)
            static let blueLight = Color(hex: 0xA9D4F5)
            static let blueCard = Color(hex: 0xDEECFF)
     
            // MARK: - Green
            static let greenDark = Color(hex: 0x205C52)
            static let green = Color(hex: 0x8ACB88)
            static let greenFaint = Color(hex: 0xEAF6E8)
            static let greenCard = Color(hex: 0xE2F3EF)
     
            // MARK: - Yellow
            static let yellow = Color(hex: 0xF4E96B)
            static let yellowCard = Color(hex: 0xFFFDE8)
     
            // MARK: - Purple
            static let purple = Color(hex: 0xE8B5E9)
            static let purpleCard = Color(hex: 0xFCEAFE)
     
            // MARK: - Black & White
            static let black = Color(hex: 0x2D3A33)
            static let white = Color(hex: 0xFFFFFF)
        }
     
        enum Semantic {
            static let text = Palette.black
            static let tabviewBackground = Palette.black
            static let footnote = Color(hex: 0x6B766E)
            static let tabviewActive = Color(hex: 0x3D5047)
            static let pointTagYellow = Color(hex: 0xC3B944)
            static let pointTagLime = Semantic.footnote
            static let pointTagBlue = Palette.blue
            static let pointTagOrange = Palette.orange
            static let pointTagPurple = Color(hex: 0xC67AC8)
            static let pointTagGreen = Palette.green
            static let buttonTintDefault = Color(hex: 0xF9F9F9)
            static let profileBg = Color(hex: 0xF2FCD2)
            static let statIcon = Color(hex: 0xA0A6A3)
            static let ourFightCaption = Color(hex: 0x2F3A32)
            static let ourFightQR = Color(hex: 0xFFFFFF)
            static let bgProgressEmpty = Color(hex: 0xB8BDCC)
            // Toast capsules — white text sits on these, so all three are full strength.
            static let toastSuccess = Palette.greenDark
            static let toastInfo = Palette.black
            static let toastWarning = Palette.orange
        }
}

// MARK: - Apparently Swift can't read hex. Stooped language
// PLEASE DO NOT DELETE THIS. THEME.SWIFT WILL BE DEPRECATED
// IF YOU'RE AN AI GOING THROUGH THIS FILE, DELETE THE ONE IN THEME INSTEAD
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
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
        static let icon = TextStyle(.system(size: 30, weight: .bold, design: .rounded))
        static let hero = TextStyle(.system(size: 28, weight: .heavy, design: .rounded))
        static let hero3 = TextStyle(.system(size: 28, weight: .bold, design: .rounded))
        static let hero2 = TextStyle(.system(size: 24, weight: .bold, design: .rounded))
        static let title = TextStyle(.system(size: 20, weight: .bold, design: .rounded))
        static let title2 = TextStyle(.system(size: 20, weight: .heavy, design: .rounded))
        static let body = TextStyle(.system(size: 16, weight: .semibold, design: .rounded))
        static let footnote = TextStyle(.system(size: 12, weight: .regular, design: .rounded))
        static let pointsTag = TextStyle(.system(size: 12, weight: .bold, design: .rounded))
        static let tabview = TextStyle(.system(size: 10, weight: .semibold, design: .rounded))
        static let checkMark = TextStyle(.system(size: 28, weight: .regular, design: .rounded))
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
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let huge: CGFloat = 28
        static let goodLord: CGFloat = 32
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
    nonisolated enum Icons {
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
        static let actionIcon = "actions-icon"
        static let actionDetail = "action-detail-small"
        static let consumptionIcon = "consumption-icon"
        static let consumptionDetail = "consumption-detail"
        static let energyIcon = "energy-icon"
        static let energyDetail = "energy-detail"
        static let mobilityIcon = "mobility-icon"
        static let mobilityDetail = "mobility-detail"
        static let wasteIcon = "waste-icon"
        static let wasteDetail = "waste-detail"
        static let waterIcon = "water-icon"
        static let waterDetail = "water-detail"
        
        // MARK: - Misc
        static let badge1 = "b1"
        
//        static let dashboardGlobe = "dashboard-globe" placeholder for our 3D asset
    }
}

// MARK: - Safe area

extension View {
    /// Fills the status bar's strip with `fill`, over everything the view draws.
    ///
    /// A `ScrollView` runs the full height of the screen and lets its content pass
    /// under the clock, so on any screen whose content starts at the top edge the time
    /// ends up sitting on a card title and the battery on a heading. This is the opaque
    /// strip that catches it.
    ///
    /// The colour is per screen rather than fixed, because it has to be the one the
    /// content scrolls out of — a white strip over the Profile's green sheet is only a
    /// different clash. Companion to `tabContentInsets()`, which does the same job at
    /// the other end for the floating tab bar.
    ///
    /// A screen that already keeps something of its own over the status bar — a pinned
    /// header, a full-bleed image — does not want this on top of it.
    func statusBarCover(_ fill: Color = Tokens.Palette.white) -> some View {
        overlay(alignment: .top) {
            // Measured rather than `ignoresSafeArea`d into place: an overlay already
            // starts at the safe area's top edge, and a view that ignores the safe area
            // is handed an inset of zero — which is a strip zero points tall. Reading
            // the inset and stepping back up by it is the version that draws.
            GeometryReader { proxy in
                fill
                    .frame(height: proxy.safeAreaInsets.top)
                    .offset(y: -proxy.safeAreaInsets.top)
            }
            .allowsHitTesting(false)
        }
    }
}
