import Foundation

/// Artwork for a badge, kept out of `Core/Models/Badge.swift` for the same reason
/// `Category+Presentation` exists: the model imports Foundation only, and an
/// asset name is presentation.
///
/// Mark's badge art is `b1`–`b6`. On `main` those were assigned per badge by hand
/// across thirteen badges, with one image used twice. This branch has twenty-one,
/// so they are mapped by **type** instead — six types, six images, and badges that
/// are earned the same way look alike. Adding a badge needs no new art and no
/// decision; adding a *type* is the only thing that would.
extension Badge {

    var icon: String {
        switch type {
        case .streak:            return "b1"
        case .categoryMilestone: return "b2"
        case .evidence:          return "b3"
        case .event:             return "b4"
        case .points:            return "b5"
        case .fightReward:       return "b6"
        }
    }
}
