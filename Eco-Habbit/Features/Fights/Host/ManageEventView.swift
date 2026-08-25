import SwiftUI

/// PRD §6.5.1 — attendance count and the attendee roster.
/// The roster is **host-visible only** (§10); it is never shown to attendees.
///
/// **The host shows a code; they do not scan one.** This screen used to offer "Scan
/// attendees", which was the earlier design where the organiser scanned each attendee's
/// personal QR. That is a cross-user write — one device crediting another account — and
/// it is exactly what `FightCodeView` and the `/attendance` rules were rewritten to
/// avoid. One code for the whole Fight, and each attendee's own device credits itself.
/// The roster is therefore read from the server rather than built by scanning.
///
/// Reached only from `CustomerFightListView`, and only for an account with
/// `isOrganization` — this is the last screen in the host flow, and the last one that
/// was still drawn in the old `Theme` (cream page, Caprasimo). It now matches
/// `EventFormView` and `FightCodeView`, which is what a host sees either side of it.
struct ManageEventView: View {
    @EnvironmentObject private var app: AppState
    let fight: Fight

    @State private var showingEdit = false
    @State private var showingCode = false
    @State private var confirmingCancel = false
    @State private var attendees: [FightAttendance] = []

    /// Read back through `app` so the view follows publish/cancel edits.
    private var current: Fight { app.fight(id: fight.id) ?? fight }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                statusCard
                counts
                actions
                roster
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.top, Tokens.Spacing.md)
            .tabContentInsets()
        }
        .background(Tokens.Palette.white.ignoresSafeArea())
        .navigationTitle("Manage")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) { EventFormView(editing: current, app: app) }
        .sheet(isPresented: $showingCode) { FightCodeView(fight: current) }
        // Refetched on appearance and after the code sheet closes, which is when the
        // host most wants to know how many came in while it was on screen.
        .task { attendees = await app.attendees(for: current) }
        .refreshable { attendees = await app.attendees(for: current) }
        .onChange(of: showingCode) { _, shown in
            guard !shown else { return }
            Task { attendees = await app.attendees(for: current) }
        }
        .confirmationDialog(
            "Cancel this Fight?",
            isPresented: $confirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Cancel the Fight", role: .destructive) { app.cancelHostedFight(current) }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It stays visible to anyone signed up, marked cancelled. This cannot be undone.")
        }
    }

    // MARK: - Sections

    private var statusCard: some View {
        card {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                HStack {
                    statusTag
                    Spacer()
                    if current.isCheckInOpen() {
                        Text("Check-in open")
                            .textStyle(Tokens.Typography.pointsTag)
                            .foregroundStyle(Tokens.Palette.greenDark)
                    }
                }

                Text(current.title.isEmpty ? "Untitled Fight" : current.title)
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
                    .fixedSize(horizontal: false, vertical: true)

                Label(current.dateRange, systemImage: "calendar")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                Label(current.locationName, systemImage: "mappin.and.ellipse")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
        }
    }

    private var statusTag: some View {
        Text(statusLabel)
            .textStyle(Tokens.Typography.pointsTag)
            .foregroundStyle(statusForeground)
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(Capsule().fill(statusBackground))
    }

    private var statusLabel: String {
        switch current.status {
        case .draft: "Draft — not public"
        case .published: "Published"
        case .cancelled: "Cancelled"
        }
    }

    private var statusForeground: Color {
        switch current.status {
        case .draft: Tokens.Semantic.footnote
        case .published: Tokens.Palette.greenDark
        case .cancelled: Tokens.Palette.orange
        }
    }

    private var statusBackground: Color {
        switch current.status {
        case .draft: Tokens.Semantic.statIcon.opacity(0.2)
        case .published: Tokens.Palette.greenCard
        case .cancelled: Tokens.Palette.orangeCard
        }
    }

    /// One number, not two. "Signed up" went with the signup flow — an attendee now
    /// saves a Fight privately, and a host is deliberately never told who.
    private var counts: some View {
        card {
            VStack(spacing: Tokens.Spacing.xxs) {
                Text("\(attendees.count)")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Semantic.text)
                Text("Checked in")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            switch current.status {
            case .draft:
                // Awaited: publishing is the one action whose point is that other
                // people see it, so it reports success only once the upload lands.
                filledButton("Publish") { Task { await app.publishFight(current) } }
                note("Nobody can see this until you publish it.")

            case .published:
                // Not disabled outside the window. A host setting up an hour early, or
                // checking their own event looks right, has every reason to open this —
                // and the code is theirs. Attendees are still refused by `checkIn`
                // until the window opens, which is where that rule belongs.
                filledButton("Show QR code") { showingCode = true }
                note(current.isCheckInOpen()
                     ? "Hold this up at the venue. Attendees scan it with their own camera, or type the code."
                     : "Check-in opens an hour before the start — attendees can't log it before then.")

            case .cancelled:
                Label("This Fight is cancelled.", systemImage: "xmark.circle")
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Palette.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Tokens.Spacing.sm)
            }

            if current.status != .cancelled {
                outlinedButton("Edit details") { showingEdit = true }
                Button("Cancel this Fight") { confirmingCancel = true }
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Palette.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("Attendees")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Semantic.text)

            if attendees.isEmpty {
                note("Nobody yet. The list fills as people scan your code.")
            } else {
                card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(attendees.enumerated()), id: \.element.userId) { index, record in
                            attendeeRow(record, showsDivider: index < attendees.count - 1)
                        }
                    }
                }
            }

            // Not an oversight. The rules keep `/users` private to its owner, so a host
            // can see that somebody arrived and when, and nothing else about them.
            note("Only you can see this (§10). Attendees are counted, not named.")
        }
    }

    private func attendeeRow(_ record: FightAttendance, showsDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Checked in")
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                Spacer(minLength: Tokens.Spacing.md)
                Text(record.checkedInAt.formatted(date: .omitted, time: .shortened))
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
            .padding(.horizontal, Tokens.Spacing.lg)
            .padding(.vertical, Tokens.Spacing.md)

            if showsDivider {
                Rectangle()
                    .fill(Tokens.Semantic.statIcon.opacity(0.3))
                    .frame(height: 1)
                    .padding(.leading, Tokens.Spacing.lg)
            }
        }
    }

    // MARK: - Pieces

    /// The same pale rounded panel `EventFormView` puts its form on.
    private func card<Content: View>(
        padding: CGFloat = Tokens.Spacing.lg,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                    .fill(Tokens.Semantic.buttonTintDefault)
            )
    }

    /// The dark rounded rectangle the hi-fi uses for "Done" and "See QR Code".
    private func filledButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.ourFightQR)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Tokens.Semantic.text)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func outlinedButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Tokens.Semantic.statIcon.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .textStyle(Tokens.Typography.footnote)
            .foregroundStyle(Tokens.Semantic.footnote)
            .fixedSize(horizontal: false, vertical: true)
    }
}
