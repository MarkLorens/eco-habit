import SwiftUI

/// Our Fights — one list of published events, drawn with the design-system cards.
///
/// **There is no signup.** Browse / Mine / Upcoming / Past are gone with it. The flow
/// is: a host publishes an event, everyone can see it, anyone can save it, and on the
/// day the host shows a code that attendees scan or type. Saving is a private bookmark
/// — the host is never told who saved, so it promises nothing and needs no server to
/// authorise. Attendance is decided by presenting the code, not by having said yes
/// beforehand.
///
/// **The cards are `OurFightListCard` and `OurFightDetailCard`.** Hardy's
/// `ExpandableFightWrapper` composes the same two, but it holds every input in
/// `@State`, which in a list means a row keeps the first fight's data when the list
/// re-renders — and, more decisively, it cannot pass through the host name, the
/// check-in action or the save button, because adding those to it would mean editing
/// it. The expand/collapse state lives here instead and that file is untouched.
struct FightListView: View {
    @EnvironmentObject private var app: AppState

    @State private var showingSavedOnly = false
    @State private var expandedFightId: String?
    @State private var showingCreate = false
    @State private var hostingCode: Fight?
    @State private var enteringCodeFor: Fight?

    /// Hosting stays its own segment and keeps the old card: a draft has to be
    /// visibly not-live, and the design-system cards have no slot for a status tag.
    @State private var showingHosting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.S.x3) {
                    if app.isOrganization { hostingSwitch }

                    if showingHosting {
                        hosting
                    } else {
                        filterStrip
                        list
                    }
                }
                .padding(.top, Theme.S.x3)
                .tabContentInsets()
            }
            .background(Theme.C.bg.ignoresSafeArea())
            // Pulled on appearance rather than once at launch: an organiser publishing
            // on the next table over should show up by the time somebody looks.
            .task { await app.refreshFights() }
            .refreshable { await app.refreshFights() }
            .navigationTitle("Our Fights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Visible on both segments. Hiding it behind "Hosting" meant an
                // organisation landing on the list had no route to creating anything
                // and no hint that one existed.
                if app.isOrganization {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // Land where the draft will appear, or it looks like
                            // nothing happened.
                            showingHosting = true
                            showingCreate = true
                        } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Create a Fight")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) { EventFormView(app: app) }
            .sheet(item: $hostingCode) { FightCodeView(fight: $0) }
            .sheet(item: $enteringCodeFor) { CheckInCodeSheet(fight: $0) }
            .navigationDestination(for: HostRoute.self) { ManageEventView(fight: $0.fight) }
        }
    }

    /// Distinct from the attendee list, which expands in place rather than pushing.
    struct HostRoute: Hashable { let fight: Fight }

    // MARK: - Attendee list

    private var shown: [Fight] {
        showingSavedOnly ? app.favouriteFights : app.browsableFights
    }

    @ViewBuilder
    private var list: some View {
        if shown.isEmpty {
            emptyState(showingSavedOnly ? "Nothing saved yet." : "No Fights published yet.",
                       showingSavedOnly ? "Tap the bookmark on a Fight to keep it here."
                                        : "Check back — organisers add them as they go.")
        } else {
            VStack(spacing: Theme.S.x3) {
                ForEach(shown) { fight in
                    card(for: fight)
                }
            }
            .padding(.horizontal, Theme.S.x4)
        }
    }

    @ViewBuilder
    private func card(for fight: Fight) -> some View {
        if expandedFightId == fight.id {
            OurFightDetailCard(
                title: fight.title,
                caption: fight.summary,
                category: fight.category.accent,
                date: fight.cardDate,
                location: fight.locationName,
                picture: fight.cardPicture,
                    photo: fight.photo,
                host: fight.hostName,
                actionTitle: actionTitle(for: fight),
                isFavourite: app.isFavourite(fight),
                // A host does not save their own event, so the bookmark is theirs to
                // not have. `nil` removes the control rather than disabling it.
                onToggleFavourite: app.isHost(of: fight) ? nil : { app.toggleFavourite(fight) },
                onAction: { act(on: fight) },
                onCollapse: { withAnimation(.snappy(duration: 0.2)) { expandedFightId = nil } }
            )
        } else {
            OurFightListCard(
                title: fight.title,
                caption: fight.summary,
                category: fight.category.accent,
                date: fight.cardDate,
                location: fight.locationName,
                picture: fight.cardPicture,
                    photo: fight.photo,
                onExpand: { withAnimation(.snappy(duration: 0.2)) { expandedFightId = fight.id } }
            )
        }
    }

    /// What the card's one button offers, which depends entirely on who is looking and
    /// whether the event is happening. `nil` hides it.
    private func actionTitle(for fight: Fight) -> String? {
        if app.hasAttended(fight) { return nil }
        guard fight.isCheckInOpen() else { return nil }
        return app.isHost(of: fight) ? "Show QR Code" : "Check In"
    }

    private func act(on fight: Fight) {
        if app.isHost(of: fight) {
            hostingCode = fight          // the organiser's code, for attendees to scan
        } else {
            enteringCodeFor = fight      // scan with the camera, or type it
        }
    }

    private var filterStrip: some View {
        HStack(spacing: Theme.S.x2) {
            chip(label: "All", isOn: !showingSavedOnly) { showingSavedOnly = false }
            chip(label: "Saved", isOn: showingSavedOnly) { showingSavedOnly = true }
            Spacer()
        }
        .padding(.horizontal, Theme.S.x4)
    }

    private var hostingSwitch: some View {
        HStack(spacing: Theme.S.x2) {
            chip(label: "Fights", isOn: !showingHosting) { showingHosting = false }
            chip(label: "Hosting", isOn: showingHosting) { showingHosting = true }
            Spacer()
        }
        .padding(.horizontal, Theme.S.x4)
    }

    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.F.body(13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Theme.C.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isOn ? Theme.C.accent500 : .clear)
                        .overlay(Capsule().stroke(isOn ? .clear : Theme.C.divider, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hosting

    private var hosting: some View {
        VStack(alignment: .leading, spacing: Theme.S.x3) {
            if app.hostedFights.isEmpty {
                emptyState("You haven't created a Fight yet.",
                           "Use + to draft one. It stays private until you publish.")
            } else {
                ForEach(app.hostedFights) { fight in
                    NavigationLink(value: HostRoute(fight: fight)) {
                        FightCard(fight: fight, hostStatus: fight.status)
                    }
                    .buttonStyle(PlainPressStyle())
                }
                .padding(.horizontal, Theme.S.x4)
            }
        }
    }

    private func emptyState(_ title: String, _ hint: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.F.body(15, weight: .semibold)).foregroundStyle(Theme.C.text)
            Text(hint).font(Theme.F.body(13)).foregroundStyle(Theme.C.neutral600)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.S.x6)
        .padding(.horizontal, Theme.S.x4)
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

// MARK: - Card

/// Kept for the Hosting list, which needs a Draft / Live / Cancelled tag that the
/// design-system cards have no slot for.
struct FightCard: View {
    let fight: Fight
    var isSignedUp = false
    var hasAttended = false
    /// Set on the Hosting list so a draft is obviously not public yet.
    var hostStatus: Fight.Status?

    var body: some View {
        EHCard {
            VStack(alignment: .leading, spacing: Theme.S.x2) {
                HStack(spacing: Theme.S.x2) {
                    Image(fight.category.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.C.accent2_700)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.C.accent2_100))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(fight.category.title)
                            .font(Theme.F.body(11.5, weight: .semibold))
                            .foregroundStyle(Theme.C.neutral600)
                        Text(fight.hostName)
                            .font(Theme.F.body(13, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                    }

                    Spacer()

                    switch hostStatus {
                    case .draft: EHTag(text: "Draft", style: .neutral)
                    case .cancelled: EHTag(text: "Cancelled", style: .accent)
                    case .published: EHTag(text: "Live", style: .accent2)
                    case nil:
                        if hasAttended {
                            EHTag(text: "Attended", style: .accent2)
                        } else if isSignedUp {
                            EHTag(text: "Joined", style: .outline)
                        }
                    }
                }

                Text(fight.title)
                    .font(Theme.F.heading(17))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Label(FightFormat.when(fight), systemImage: "calendar")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral700)

                Label(fight.locationName, systemImage: "mappin.and.ellipse")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .lineLimit(1)

                HStack {
                    EHTag(text: "+\(fight.attendancePoints) pts", style: .accent)
                    Spacer()
                    if fight.isCheckInOpen() {
                        Text("Check-in open")
                            .font(Theme.F.body(11.5, weight: .bold))
                            .foregroundStyle(Theme.C.accent2_700)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

/// Date formatting shared by the card, the detail screen and the dashboard.
enum FightFormat {
    static func when(_ fight: Fight) -> String {
        let day = fight.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let from = fight.startsAt.formatted(date: .omitted, time: .shortened)
        let to = fight.endsAt.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(from)–\(to)"
    }

    static func countdown(_ fight: Fight, from now: Date = Date()) -> String {
        let seconds = fight.startsAt.timeIntervalSince(now)
        if seconds < 0 { return "Happening now" }
        let hours = Int(seconds / 3600)
        if hours < 1 { return "Starts in \(max(1, Int(seconds / 60))) min" }
        if hours < 24 { return "Starts in \(hours)h" }
        return "In \(hours / 24) day\(hours / 24 == 1 ? "" : "s")"
    }
}
