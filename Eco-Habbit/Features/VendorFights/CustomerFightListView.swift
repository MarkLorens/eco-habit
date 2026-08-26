//
//  CustomerFightListView.swift
//  Eco-Habbit
//
//  Created by Tio Dwi Ardhana on 18/08/26.
//
//  The Fights tab. One screen, two audiences.
//
//  A person browses: the header heart filters to loved events, and a card offers
//  check-in. An **organisation only ever sees its own events** — create, edit,
//  publish, show the code. No browse list and no heart, because an organiser is here
//  to run events, not to attend them.
//
//  Still one view rather than two. The difference is which list it draws, and a
//  second file would be a second thing to keep in step — the last split left a
//  vendor screen that nothing rendered for days.
//

import Foundation
import SwiftUI

struct CustomerFightListView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.openURL) private var openURL

    @State private var showingLovedOnly = false
    @State private var showingCreate = false
    @State private var editing: Fight?
    @State private var showingCode: Fight?
    @State private var enabling: Fight?
    @State private var path = NavigationPath()

    /// Distinct from pushing a `Fight`, which would mean the attendee-facing screen.
    struct HostRoute: Hashable { let fight: Fight }

    private var fights: [Fight] {
        showingLovedOnly ? app.favouriteFights : app.browsableFights
    }

    /// An organisation gets the hosting list and nothing else.
    private var isHosting: Bool { app.isOrganization }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    header

                    if isHosting { hosted } else { browsing }
                }
                .tabContentInsets()
            }
            .background(Tokens.Palette.white)
            // Published Fights come from the shared collection, so an organiser at the
            // next table shows up by the time somebody looks.
            .task { await app.refreshFights() }
            .refreshable { await app.refreshFights() }
            .sheet(isPresented: $showingCreate) { EventFormView(app: app) }
            .sheet(item: $editing) { EventFormView(editing: $0, app: app) }
            .sheet(item: $showingCode) { FightCodeView(fight: $0) }
            .navigationDestination(for: HostRoute.self) { ManageEventView(fight: $0.fight) }
            // Asks whether to go and change it, rather than offering to enable here.
            // "Enable" on this alert would have published the event from a screen that
            // never showed its contents — and a draft is usually a draft because
            // something in it is still blank.
            .alert("Event is disabled", isPresented: Binding(
                get: { enabling != nil },
                set: { if !$0 { enabling = nil } }
            )) {
                Button("Cancel", role: .cancel) { enabling = nil }
                Button("Edit") {
                    editing = enabling
                    enabling = nil
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Nobody else can see it yet. Edit to change the status?")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            HStack {
                Text("Our Fights")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Semantic.text)

                Spacer()

                if isHosting {
                    NavigateButton(background: Tokens.Semantic.buttonTintDefault,
                                   buttonAction: .plus) { showingCreate = true }
                } else {
                    LoveButton(isLoved: showingLovedOnly) {
                        withAnimation(.snappy(duration: 0.2)) { showingLovedOnly.toggle() }
                    }
                }
            }

            Text(isHosting
                 ? "Publish an event and show its code at the venue"
                 : "Take action together for a greener tomorrow")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .padding(.horizontal, Tokens.Spacing.xxl)
    }

    // MARK: - Browsing — everyone

    @ViewBuilder
    private var browsing: some View {
        if fights.isEmpty {
            // An empty list is a normal state now that the bundled seeds are gone, so
            // it matters whether we have actually looked. Saying "none published" while
            // the fetch is still in flight is a lie that lasts about a second and makes
            // the tab look broken on every launch.
            note(showingLovedOnly
                 ? "Nothing saved yet. Tap the heart on an event to keep it here."
                 : app.hasLoadedRemoteFights
                   ? "No Fights published yet. Check back — organisers add them as they go."
                   : "Looking for Fights…")
        } else {
            ForEach(fights) { fight in
                CustomerFightWrapper(
                    title: fight.title,
                    caption: fight.summary,
                    category: fight.category.accent,
                    date: fight.cardDate,
                    location: fight.locationName,
                    picture: fight.cardPicture,
                    photo: fight.photo,
                    isLoved: app.isFavourite(fight),
                    onLove: { app.toggleFavourite(fight) },
                    icon: fight.category.icon,
                    host: fight.hostName,
                    // Hidden once they have checked in — there is nothing left to do,
                    // and offering it again invites an attempt the server would refuse.
                    // A host of this event gets the code instead.
                    actionTitle: actionTitle(for: fight),
                    actionBackground: fight.category.accent,
                    actionForeground: fight.category.accentForeground,
                    secondaryTitle: checkInTitle(for: fight),
                    onAction: { act(on: fight) },
                    onSecondary: { app.openCamera(for: .scanFight) }
                )
            }
            .padding(.horizontal, Tokens.Spacing.xl)
        }
    }

    /// **"More info", not check-in.** A card is where somebody decides whether to go,
    /// and what they want then is the organiser's page — Instagram, a WhatsApp group, a
    /// signup form. Checking in happens at the venue, from the scan button.
    ///
    /// Shown even with no link. Hiding it meant the button vanished from every Fight,
    /// because `link` is new and nothing has one yet — and a card that sometimes has a
    /// button and sometimes does not reads as broken rather than as informative.
    private func actionTitle(for fight: Fight) -> String? {
        app.isHost(of: fight) ? "Show QR Code" : "More info"
    }

    /// The right-hand button. `nil` once they have checked in — there is nothing left to
    /// do — and `nil` for a host, who shows a code rather than scanning one.
    private func checkInTitle(for fight: Fight) -> String? {
        if app.isHost(of: fight) { return nil }
        return app.hasAttended(fight) ? nil : "Scan QR"
    }

    private func act(on fight: Fight) {
        if app.isHost(of: fight) {
            path.append(HostRoute(fight: fight))   // manage it, code included
        } else if let url = fight.infoURL {
            openURL(url)
        } else {
            // Says what happened rather than nothing. The organiser has not linked
            // anywhere, so the card is genuinely everything there is to read.
            app.toast = Toast(kind: .info,
                              message: "That's everything the organiser shared about this one.")
        }
    }

    // MARK: - Hosting — organisations only

    /// The events this account hosts.
    ///
    /// A Fight that is not enabled is **dimmed rather than hidden or labelled**, as in
    /// the hi-fi: the host still needs to reach it to finish and switch it on, and
    /// greying it says "nobody else can see this" without spending a row on a tag the
    /// card has no slot for.
    @ViewBuilder
    private var hosted: some View {
        if app.hostedFights.isEmpty {
            note("You haven't created a Fight yet. Use + to draft one — it stays private until you enable it.")
        } else {
            ForEach(app.hostedFights) { fight in
                OurFightExpandable(
                    fight: fight,
                    onEdit: { editing = fight },
                    onShowCode: { showingCode = fight },
                    // A disabled Fight does not expand. Tapping it asks the one
                    // question worth asking about a draft — do you want it live —
                    // rather than showing a card whose only button is unusable.
                    onDisabledTap: { enabling = fight }
                )
            }
            .padding(.horizontal, Tokens.Spacing.xl)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(Tokens.Typography.footnote)
            .foregroundStyle(Tokens.Semantic.footnote)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Tokens.Spacing.xxl)
    }
}

// MARK: - The host's card

/// Collapsed row, expanding in place to the detail card — the organiser's half of the
/// hi-fi.
///
/// Its own view rather than a branch inside the list so the expanded/collapsed flag
/// belongs to one row. Held here rather than in `ExpandableFightWrapper`, which keeps
/// its inputs in `@State` and so shows the first row's data for every row once a list
/// re-renders.
private struct OurFightExpandable: View {
    let fight: Fight
    let onEdit: () -> Void
    let onShowCode: () -> Void
    let onDisabledTap: () -> Void

    @State private var isExpanded = false

    private var isLive: Bool { fight.status == .published }

    var body: some View {
        card
            // Dimmed **in its own colour**, not greyed. Opacity scales a hue toward the
            // white page rather than desaturating it, so a disabled Fight still reads
            // as its category — which is the only thing distinguishing one washed-out
            // row from another.
            .opacity(isLive ? 1 : 0.45)
            .overlay {
                if !isLive {
                    RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                        .fill(fight.category.accent.opacity(0.12))
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var card: some View {
        if isExpanded {
            OurFightDetailCard(
                title: fight.title.isEmpty ? "Untitled Fight" : fight.title,
                caption: fight.summary,
                category: fight.category.accent,
                date: fight.cardDate,
                location: fight.locationName,
                picture: fight.cardPicture,
                    photo: fight.photo,
                host: fight.hostName,
                // The code is the point of the expanded card for a host. Before the
                // event it is still worth seeing — it is theirs, and checking it looks
                // right is not something to be locked out of.
                actionTitle: "See QR Code",
                onAction: onShowCode,
                onEdit: onEdit,
                onCollapse: { withAnimation(.snappy(duration: 0.2)) { isExpanded = false } }
            )
        } else {
            OurFightListCard(
                title: fight.title.isEmpty ? "Untitled Fight" : fight.title,
                caption: fight.summary,
                category: fight.category.accent,
                date: fight.cardDate,
                location: fight.locationName,
                picture: fight.cardPicture,
                    photo: fight.photo,
                icon: fight.category.icon,
                onExpand: expand
            )
            // The whole row, not just the chevron. A card that looks tappable and only
            // responds on one 30pt arrow reads as broken.
            .contentShape(Rectangle())
            .onTapGesture(perform: expand)
        }
    }

    private func expand() {
        guard isLive else { onDisabledTap(); return }
        withAnimation(.snappy(duration: 0.2)) { isExpanded = true }
    }
}

