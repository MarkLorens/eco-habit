import SwiftUI

/// Hardy's Fights screen, wired to real data.
///
/// His original listed `ForEach(0..<6)` of one hardcoded event — a layout
/// scaffold, never connected. The header, spacing, type and card treatment below
/// are unchanged; what is new is that the cards come from `app.upcomingFights`
/// and the buttons do something.
///
/// Two placeholders in his version needed a decision rather than a value:
///
/// - **"See QR Code"** meant different things depending on who is looking. The
///   organiser needs to *show* the code; everybody else needs to *enter* it.
///   That is the direction the check-in flow settled on — one code per Fight,
///   published by the host — so the button reads and does whichever applies.
/// - **The `+` button** was unconditional, but only verified organisations can
///   create a Fight. It stays visible for everyone so the header is unchanged,
///   and says so when tapped rather than disappearing.
struct OurFightListView: View {
    @EnvironmentObject private var app: AppState

    @State private var showingCreate = false
    @State private var checkingInTo: Fight?
    @State private var showingCodeFor: Fight?

    /// Drafts appear alongside for their own organiser, so a half-written Fight
    /// is somewhere they can find it again.
    private var fights: [Fight] {
        app.hostedFights.filter { $0.status == .draft } + app.upcomingFights
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    header

                    if fights.isEmpty {
                        empty
                    } else {
                        ForEach(fights) { fight in
                            ExpandableFightWrapper(
                                title: fight.title.isEmpty ? "Untitled Fight" : fight.title,
                                caption: fight.summary,
                                category: fight.type.tint,
                                date: fight.cardDate,
                                location: fight.locationName,
                                picture: fight.cardPicture,
                                status: false,
                                organiser: fight.hostName,
                                actionTitle: actionTitle(for: fight),
                                onAction: { act(on: fight) }
                            )
                        }
                        .padding(.horizontal, Tokens.Spacing.xl)
                    }
                }
                .tabContentInsets()
            }
            .background(Tokens.Palette.white)
            .sheet(isPresented: $showingCreate) { EventFormView(app: app) }
            .sheet(item: $checkingInTo) { CheckInSheet(fight: $0) }
            .sheet(item: $showingCodeFor) { FightCodeView(fight: $0) }
        }
    }

    // MARK: - Header (Hardy's, unchanged)

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack {
                Text("Our Fights")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Semantic.text)

                Spacer()

                NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .plus) {
                    if app.isOrganization {
                        showingCreate = true
                    } else {
                        app.toast = Toast(kind: .info,
                                          message: "Only verified organisations can create a Fight.")
                    }
                }
            }

            Text("Take action together for a greener tomorrow")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .padding(.horizontal, Tokens.Spacing.xxl)
    }

    private var empty: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Text("No Fights coming up")
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
            Text("Check back soon, or ask an organiser to publish one.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.xxl)
        .padding(.horizontal, Tokens.Spacing.xxl)
    }

    // MARK: - What the button does

    /// The single button on Hardy's card carries whatever this Fight needs next.
    ///
    /// A draft was the gap: an organiser could create a Fight and show its code,
    /// but nothing in this screen reached Publish — so the code was live-looking
    /// and permanently un-checkable-into.
    private func actionTitle(for fight: Fight) -> String {
        if app.hasAttended(fight) { return "Checked in" }
        guard app.isHost(of: fight) else { return "See QR Code" }
        return fight.status == .draft ? "Publish" : "Show QR Code"
    }

    private func act(on fight: Fight) {
        if app.hasAttended(fight) { return }
        guard app.isHost(of: fight) else {
            checkingInTo = fight
            return
        }
        if fight.status == .draft {
            Task { await app.publishFight(fight) }
        } else {
            showingCodeFor = fight
        }
    }
}

#if DEBUG
#Preview {
    OurFightListView()
        .environmentObject(AppState.preview)
}
#endif
