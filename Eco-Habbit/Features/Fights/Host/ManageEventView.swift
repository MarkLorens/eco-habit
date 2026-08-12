import SwiftUI

/// PRD §6.5.1 — signup count, attendance count, and the attendee roster.
/// The roster is **host-visible only** (§10); it is never shown to attendees.
struct ManageEventView: View {
    @EnvironmentObject private var app: AppState
    let fight: Fight

    @State private var showingEdit = false
    @State private var showingScanner = false
    @State private var confirmingCancel = false

    /// Read back through `app` so the view follows publish/cancel edits.
    private var current: Fight { app.fight(id: fight.id) ?? fight }
    private var scans: [HostScan] { app.scans(for: current) }

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
        .fullScreenCover(isPresented: $showingScanner) { ScannerView(fight: current) }
        .confirmationDialog(
            "Cancel this Fight?",
            isPresented: $confirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Cancel the Fight", role: .destructive) { Task { await app.cancelHostedFight(current) } }
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

    private var counts: some View {
        HStack(spacing: Theme.S.x3) {
            countTile("\(app.signupCount(for: current))", "Signed up")
            countTile("\(scans.count)", "Checked in")
        }
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
                Button("Publish") { Task { await app.publishFight(current) } }
                    .buttonStyle(PrimaryButtonStyle())
                Text("Nobody can see this until you publish it.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)

            case .published:
                Button("Scan attendees") { showingScanner = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!current.isCheckInOpen())
                if !current.isCheckInOpen() {
                    Text("Scanning opens an hour before the start.")
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.neutral600)
                }

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

            if scans.isEmpty {
                Text("Nobody scanned yet. The roster fills as you scan codes at the venue.")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                EHCard(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                            SettingsRow(
                                title: scan.attendeeLabel,
                                showsDivider: index < scans.count - 1
                            ) {
                                Text(scan.scannedAt.formatted(date: .omitted, time: .shortened))
                                    .font(Theme.F.body(12.5))
                                    .foregroundStyle(Theme.C.neutral600)
                            }
                        }
                    }
                }
            }

            Text("Only you can see this list (§10).")
                .font(Theme.F.body(11.5))
                .foregroundStyle(Theme.C.neutral500)
        }
    }
}
