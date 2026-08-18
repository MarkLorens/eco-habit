import SwiftUI

/// The organiser's view of their own Fight: publish it, show the check-in code
/// at the venue, edit or cancel it.
struct ManageEventView: View {
    @EnvironmentObject private var app: AppState
    let fight: Fight

    @State private var showingEdit = false
    @State private var showingCode = false
    @State private var confirmingCancel = false

    /// Read back through `app` so the view follows publish/cancel edits.
    private var current: Fight { app.fight(id: fight.id) ?? fight }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.x4) {
                statusCard
                codeCard
                headcount
                actions
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
        .confirmationDialog(
            "Cancel this Fight?",
            isPresented: $confirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Cancel the Fight", role: .destructive) { Task { await app.cancelHostedFight(current) } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It stays visible to anyone who saved it, marked cancelled. This cannot be undone.")
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

    /// The code, inline, so the organiser can read it out without opening
    /// anything. The full-screen version is for holding up to a queue.
    @ViewBuilder
    private var codeCard: some View {
        if current.status == .published {
            EHCard {
                VStack(alignment: .leading, spacing: Theme.S.x2) {
                    Text("Check-in code")
                        .font(Theme.F.body(11.5, weight: .semibold))
                        .foregroundStyle(Theme.C.neutral600)
                        .textCase(.uppercase)

                    HStack(spacing: Theme.S.x3) {
                        Text(current.checkInCode)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Theme.C.text)
                            .textSelection(.enabled)
                        Spacer()
                        Button("Show") { showingCode = true }
                            .font(Theme.F.body(14, weight: .bold))
                            .foregroundStyle(Theme.C.accent700)
                    }

                    Text("Attendees scan or type this. Everyone uses the same code.")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// **This device only.** One phone cannot see another's attendance without a
    /// server, so this counts the organiser's own check-in and nothing else. It
    /// becomes a real headcount when attendance is a Firestore query — labelled
    /// honestly until then rather than implying a roster that doesn't exist.
    private var headcount: some View {
        EHCard {
            HStack(spacing: Theme.S.x3) {
                Text("\(app.checkInCount(for: current))")
                    .font(Theme.F.heading(28))
                    .foregroundStyle(Theme.C.text)
                VStack(alignment: .leading, spacing: 2) {
                    Text("checked in on this device")
                        .font(Theme.F.body(13.5, weight: .semibold))
                        .foregroundStyle(Theme.C.text)
                    Text("A live headcount across everyone's phones needs the shared database — not wired up yet.")
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
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
                Button("Show the code") { showingCode = true }
                    .buttonStyle(PrimaryButtonStyle())
                if !current.isCheckInOpen() {
                    Text("Attendees can't check in until an hour before the start.")
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.neutral600)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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

}
