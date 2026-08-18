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
            VStack(alignment: .leading, spacing: Theme.S.x4) {
                statusCard
                counts
                actions
                roster
            }
            .padding(.horizontal, Theme.S.x4)
            .padding(.top, Theme.S.x3)
            .tabContentInsets()
        }
        .background(Theme.C.bg.ignoresSafeArea())
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
        EHCard {
            VStack(alignment: .leading, spacing: Theme.S.x2) {
                HStack {
                    EHTag(text: statusLabel, style: statusStyle)
                    Spacer()
                    if current.isCheckInOpen() {
                        Text("Check-in open")
                            .font(Theme.F.body(11.5, weight: .bold))
                            .foregroundStyle(Theme.C.accent2_700)
                    }
                }

                Text(current.title.isEmpty ? "Untitled Fight" : current.title)
                    .font(Theme.F.heading(20))
                    .foregroundStyle(Theme.C.text)
                    .fixedSize(horizontal: false, vertical: true)

                Label(FightFormat.when(current), systemImage: "calendar")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral700)
                Label(current.locationName, systemImage: "mappin.and.ellipse")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral700)
            }
        }
    }

    private var statusLabel: String {
        switch current.status {
        case .draft: "Draft — not public"
        case .published: "Published"
        case .cancelled: "Cancelled"
        }
    }

    private var statusStyle: TagStyle {
        switch current.status {
        case .draft: .neutral
        case .published: .accent2
        case .cancelled: .accent
        }
    }

    /// One number, not two. "Signed up" went with the signup flow — an attendee now
    /// saves a Fight privately, and a host is deliberately never told who.
    private var counts: some View {
        countTile("\(attendees.count)", "Checked in")
    }

    private func countTile(_ value: String, _ label: String) -> some View {
        EHCard {
            VStack(spacing: 2) {
                Text(value)
                    .font(Theme.F.heading(28))
                    .foregroundStyle(Theme.C.text)
                Text(label)
                    .font(Theme.F.body(12, weight: .semibold))
                    .foregroundStyle(Theme.C.neutral600)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Theme.S.x2) {
            switch current.status {
            case .draft:
                // Awaited: publishing is the one action whose point is that other
                // people see it, so it reports success only once the upload lands.
                Button("Publish") { Task { await app.publishFight(current) } }
                    .buttonStyle(PrimaryButtonStyle())
                Text("Nobody can see this until you publish it.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)

            case .published:
                Button("Show QR code") { showingCode = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!current.isCheckInOpen())
                Text(current.isCheckInOpen()
                     ? "Hold this up at the venue. Attendees scan it with their own camera, or type the code."
                     : "Check-in opens an hour before the start.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
                    .fixedSize(horizontal: false, vertical: true)

            case .cancelled:
                Label("This Fight is cancelled.", systemImage: "xmark.circle")
                    .font(Theme.F.body(14, weight: .semibold))
                    .foregroundStyle(Theme.C.accent600)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.S.x2)
            }

            if current.status != .cancelled {
                Button("Edit details") { showingEdit = true }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Cancel this Fight") { confirmingCancel = true }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: Theme.S.x2) {
            SectionHeading(text: "Attendees")

            if attendees.isEmpty {
                Text("Nobody yet. The list fills as people scan your code.")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                EHCard(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(attendees.enumerated()), id: \.element.userId) { index, record in
                            SettingsRow(
                                title: "Checked in",
                                showsDivider: index < attendees.count - 1
                            ) {
                                Text(record.checkedInAt.formatted(date: .omitted, time: .shortened))
                                    .font(Theme.F.body(12.5))
                                    .foregroundStyle(Theme.C.neutral600)
                            }
                        }
                    }
                }
            }

            // Not an oversight. The rules keep `/users` private to its owner, so a host
            // can see that somebody arrived and when, and nothing else about them.
            Text("Only you can see this (§10). Attendees are counted, not named.")
                .font(Theme.F.body(11.5))
                .foregroundStyle(Theme.C.neutral500)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
