import SwiftUI

/// The two names the camera's reward overlay asks a category for.
///
/// Tio's branch has a `Category+Presentation` carrying `mascotName` and
/// `accentColor`; main's `HabitCategory` carries `icon`, `iconDetail`, `tint` and
/// `background`. Rather than edit his camera code to speak main's vocabulary,
/// main's vocabulary answers to his names here — one small file instead of
/// scattered renames through a 700-line view.
extension HabitCategory {

    /// The artwork the award animation flings at the user.
    ///
    /// Tio's branch has six painted mascots for this. **They are not in main's
    /// asset catalogue**, so this points at the category's detail artwork, which
    /// is the largest image main actually ships. Swap this one line the day the
    /// mascots land — nothing else needs to know.
    var mascotName: String { iconDetail }

    /// The colour the reward burst is tinted with.
    var accentColor: Color { tint }
}
