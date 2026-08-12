import SwiftUI

// `AppTab` lives in Features/AppTabBar.swift — it is Max's, and it belongs next
// to the bar that renders it.

/// Set when points land, so a view can play the reward animation once.
struct Award: Identifiable, Equatable {
    let id = UUID()
    let activity: Activity
    /// Final points after the evidence, streak and priority multipliers.
    let points: Int
}

struct Toast: Identifiable, Equatable {
    enum Kind {
        case success, info, warning

        var tint: Color {
            switch self {
            case .success: return Theme.C.accent2_600
            case .info: return Theme.C.neutral800
            case .warning: return Theme.C.accent600
            }
        }

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let message: String
}
