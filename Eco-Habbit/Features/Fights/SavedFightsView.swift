import SwiftUI

/// The user's private shortlist, plus what they've already been to.
///
/// Saving is a bookmark and nothing more — the organiser is never told, and it
/// does not gate check-in. Past attendance sits underneath because this is the
/// one screen that is entirely about *this user's* relationship to Fights, and
/// splitting it across two places would leave both looking thin.
struct SavedFightsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.x4) {
                section(
                    "Saved",
                    fights: app.savedFights,
                    empty: "Nothing saved yet.",
                    hint: "Tap the bookmark on any Fight to keep it here."
                )

                section(
                    "Attended",
                    fights: app.pastFights,
                    empty: "No Fights attended yet.",
                    hint: "Once you check in, a Fight is kept here permanently."
                )
            }
            .padding(.horizontal, Theme.S.x4)
            .padding(.top, Theme.S.x3)
            .tabContentInsets()
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ title: String, fights: [Fight], empty: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.x2) {
            SectionHeading(text: title)

            if fights.isEmpty {
                VStack(spacing: 6) {
                    Text(empty)
                        .font(Theme.F.body(15, weight: .semibold))
                        .foregroundStyle(Theme.C.text)
                    Text(hint)
                        .font(Theme.F.body(13))
                        .foregroundStyle(Theme.C.neutral600)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.S.x6)
            } else {
                ForEach(fights) { fight in
                    NavigationLink(value: fight) {
                        FightCard(
                            fight: fight,
                            isSaved: app.isSaved(fight),
                            hasAttended: app.hasAttended(fight)
                        )
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }
        }
    }
}
