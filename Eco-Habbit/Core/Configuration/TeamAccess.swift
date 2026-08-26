import Foundation

/// The password on the team-only doors: skipping sign-in, and the debug menu.
///
/// **A speed bump, not a secret.** It sits in the binary in plain text and anyone with
/// the `strings` command can read it out. What it has to do is stop a visitor holding
/// the phone at the exhibition from wandering into time travel, and it does that.
///
/// One definition rather than a literal per screen. Two copies of a password drift, and
/// the one that drifts is always the one nobody thought to check.
enum TeamAccess {
    private static let password = "mangrove"

    /// Trimmed and case-folded: this gets typed on a phone, and rejecting `"Mangrove "`
    /// teaches nobody anything.
    static func accepts(_ entered: String) -> Bool {
        entered.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == password
    }
}
