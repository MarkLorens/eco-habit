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

    @State private var showingLovedOnly = false
    @State private var showingCreate = false
    @State private var checkingInTo: Fight?
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
            .sheet(item: $checkingInTo) { CheckInCodeSheet(fight: $0) }
            .sheet(isPresented: $showingCreate) { EventFormView(app: app) }
            .navigationDestination(for: HostRoute.self) { ManageEventView(fight: $0.fight) }
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
            note(showingLovedOnly
                 ? "Nothing saved yet. Tap the heart on an event to keep it here."
                 : "No Fights published yet. Check back — organisers add them as they go.")
        } else {
            ForEach(fights) { fight in
                CustomerFightWrapper(
                    title: fight.title,
                    caption: fight.summary,
                    category: fight.type.tint,
                    date: fight.cardDate,
                    location: fight.locationName,
                    picture: fight.cardPicture,
                    isLoved: app.isFavourite(fight),
                    onLove: { app.toggleFavourite(fight) },
                    host: fight.hostName,
                    // Hidden once they have checked in — there is nothing left to do,
                    // and offering it again invites an attempt the server would refuse.
                    // A host of this event gets the code instead.
                    actionTitle: actionTitle(for: fight),
                    onAction: { act(on: fight) }
                )
            }
            .padding(.horizontal, Tokens.Spacing.xl)
        }
    }

    private func actionTitle(for fight: Fight) -> String? {
        if app.isHost(of: fight) { return "Show QR Code" }
        return app.hasAttended(fight) ? nil : "Scan or check in"
    }

    private func act(on fight: Fight) {
        if app.isHost(of: fight) {
            path.append(HostRoute(fight: fight))   // manage it, code included
        } else {
            checkingInTo = fight
        }
    }

    // MARK: - Hosting — organisations only

    /// The events this account hosts.
    ///
    /// `OurFightListCard` rather than the expandable wrapper: a host needs publish,
    /// edit, cancel, the check-in code and the roster, and none of that fits on a card.
    /// Draft / Live / Cancelled goes on the date line — the first thing a host reads,
    /// and the only slot the card has.
    @ViewBuilder
    private var hosted: some View {
        if app.hostedFights.isEmpty {
            note("You haven't created a Fight yet. Use + to draft one — it stays private until you publish.")
        } else {
            ForEach(app.hostedFights) { fight in
                OurFightListCard(
                    title: fight.title.isEmpty ? "Untitled Fight" : fight.title,
                    caption: fight.summary,
                    category: fight.type.tint,
                    date: "\(statusWord(fight)) • \(fight.cardDate)",
                    location: fight.locationName,
                    picture: fight.cardPicture,
                    onExpand: { path.append(HostRoute(fight: fight)) }
                )
            }
            .padding(.horizontal, Tokens.Spacing.xl)
        }
    }

    private func statusWord(_ fight: Fight) -> String {
        switch fight.status {
        case .draft: "Draft"
        case .published: "Live"
        case .cancelled: "Cancelled"
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

// MARK: - Check-in

/// Type the organiser's code, or open the camera and scan it.
///
/// Both routes end at the same `checkIn(to:code:)`, which verifies the code against the
/// Fight, refuses a second check-in and refuses one outside the window. Typing exists
/// because a booth is exactly where a camera fails — bad light, a cracked lens, someone
/// who denied the permission prompt on their first launch.
private struct CheckInCodeSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let fight: Fight

    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.S.x4) {
                Text("Ask the organiser for the code, or scan the QR they're showing.")
                    .font(Theme.F.body(14))
                    .foregroundStyle(Theme.C.neutral700)

                TextField("Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(Theme.F.heading(22))
                    .focused($focused)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.C.bg)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.C.divider))
                    )
                    .onSubmit(submit)

                Button("Check In", action: submit)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)

                // Both halves of the flow in one sheet. Offering "scan or type" as a
                // dialog *before* this would mean presenting a sheet from a dismissing
                // dialog, which SwiftUI drops often enough to matter at a booth.
                Button("Scan the QR code instead") {
                    dismiss()
                    app.isCameraPresented = true
                }
                .buttonStyle(GhostButtonStyle())

                Spacer()
            }
            .padding(Theme.S.x4)
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle(fight.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func submit() {
        // `checkIn` raises its own toast for every outcome — wrong code, window shut,
        // already checked in — so this only has to decide whether to get out of the way.
        if case .checkedIn = app.checkIn(to: fight, code: code) { dismiss() }
    }
}
