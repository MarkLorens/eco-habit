import SwiftUI

/// Fight detail: what it is, what it pays, and the one way in — the organiser's
/// check-in code.
///
/// Saving is a private bookmark, not an RSVP: it never gates check-in, so someone
/// who walks past a beach cleanup and joins on the spot is not blocked by having
/// failed to plan.
struct FightDetailView: View {
    @EnvironmentObject private var app: AppState
    let fight: Fight

    @State private var showingCheckIn = false

    private var isSaved: Bool { app.isSaved(fight) }
    private var hasAttended: Bool { app.hasAttended(fight) }
    private var badge: Badge? { app.rewardBadge(for: fight) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.x4) {
                header
                facts
                if !fight.preparationNotes.isEmpty { preparation }
                reward
                actions
            }
            .padding(.horizontal, Theme.S.x4)
            .padding(.top, Theme.S.x3)
            .tabContentInsets()
        }
        .background(Theme.C.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await app.toggleSaved(fight) }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save this Fight")
            }
        }
        .sheet(isPresented: $showingCheckIn) {
            CheckInSheet(fight: fight)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.S.x2) {
            HStack(spacing: Theme.S.x2) {
                Image(systemName: fight.type.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.C.accent2_700)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.C.accent2_100))

                VStack(alignment: .leading, spacing: 1) {
                    Text(fight.type.name)
                        .font(Theme.F.body(12, weight: .semibold))
                        .foregroundStyle(Theme.C.neutral600)
                    Text(fight.hostName)
                        .font(Theme.F.body(14, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                }
                Spacer()
                if fight.isDemo { EHTag(text: "Demo", style: .neutral) }
            }

            Text(fight.title)
                .font(Theme.F.heading(24))
                .foregroundStyle(Theme.C.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(fight.summary)
                .font(Theme.F.body(14.5))
                .foregroundStyle(Theme.C.neutral700)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var facts: some View {
        EHCard {
            VStack(alignment: .leading, spacing: Theme.S.x3) {
                fact("calendar", "When", FightFormat.when(fight), note: FightFormat.countdown(fight))
                Divider().overlay(Theme.C.divider)
                fact("mappin.and.ellipse", "Where", fight.locationName, note: fight.address)

                // §6.5: address tappable → opens Maps.
                if let url = mapsURL {
                    Link(destination: url) {
                        Label("Open in Maps", systemImage: "arrow.up.right.square")
                            .font(Theme.F.body(13.5, weight: .semibold))
                            .foregroundStyle(Theme.C.accent700)
                    }
                }
            }
        }
    }

    private func fact(_ symbol: String, _ label: String, _ value: String, note: String? = nil) -> some View {
        HStack(alignment: .top, spacing: Theme.S.x2) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Theme.C.neutral600)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Theme.F.body(11.5, weight: .semibold))
                    .foregroundStyle(Theme.C.neutral600)
                Text(value)
                    .font(Theme.F.body(14.5, weight: .semibold))
                    .foregroundStyle(Theme.C.text)
                if let note {
                    Text(note)
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
    }

    private var mapsURL: URL? {
        let query = "\(fight.locationName), \(fight.address)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "http://maps.apple.com/?q=\(query)")
    }

    private var preparation: some View {
        VStack(alignment: .leading, spacing: Theme.S.x2) {
            SectionHeading(text: "What to bring")
            VStack(alignment: .leading, spacing: Theme.S.x2) {
                ForEach(Array(fight.preparationNotes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: Theme.S.x2) {
                        Circle()
                            .fill(Theme.C.accent2_500)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(note)
                            .font(Theme.F.body(14))
                            .foregroundStyle(Theme.C.neutral800)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var reward: some View {
        EHCard(background: AnyShapeStyle(Theme.C.accent2_100)) {
            VStack(alignment: .leading, spacing: Theme.S.x3) {
                HStack(spacing: Theme.S.x3) {
                    Text("+\(fight.attendancePoints)")
                        .font(Theme.F.heading(30))
                        .foregroundStyle(Theme.C.accent2_700)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("points")
                            .font(Theme.F.body(14.5, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        Text("Counts against the monthly event quota, like every Fight.")
                            .font(Theme.F.body(12.5))
                            .foregroundStyle(Theme.C.neutral700)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                if let badge {
                    Divider().overlay(Theme.C.accent2_300)
                    HStack(spacing: Theme.S.x3) {
                        Image(systemName: "rosette")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.C.accent2_700)
                            .frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.name)
                                .font(Theme.F.body(14.5, weight: .bold))
                                .foregroundStyle(Theme.C.text)
                            Text(badge.description)
                                .font(Theme.F.body(12.5))
                                .foregroundStyle(Theme.C.neutral700)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Theme.S.x2) {
            // Host mode is *additive*: an organisation is still a user who
            // attends other people's Fights, so Manage sits above the normal
            // check-in rather than replacing it.
            if app.isHost(of: fight) {
                NavigationLink(value: FightListView.HostRoute(fight: fight)) {
                    Text("Manage this Fight")
                        .font(Theme.F.heading(17))
                        .foregroundStyle(Theme.C.bg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Theme.C.accent))
                }
                .buttonStyle(PlainPressStyle())
            }

            if hasAttended {
                Label("Attended — points credited", systemImage: "checkmark.seal.fill")
                    .font(Theme.F.body(14.5, weight: .bold))
                    .foregroundStyle(Theme.C.accent2_700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.S.x3)

            } else if fight.status == .cancelled {
                Label("The organiser cancelled this Fight.", systemImage: "xmark.circle")
                    .font(Theme.F.body(14, weight: .semibold))
                    .foregroundStyle(Theme.C.accent600)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.S.x3)

            } else {
                Button("Check in") { showingCheckIn = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!fight.isCheckInOpen())

                Text(fight.isCheckInOpen()
                     ? "Scan or type the code the organiser gives you at the venue."
                     : "Check-in opens an hour before the start.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button(isSaved ? "Remove from saved" : "Save for later") {
                    Task { await app.toggleSaved(fight) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.top, Theme.S.x2)
    }
}

// MARK: - Check-in

/// Two ways in, one validation path: scanning fills the same field typing does.
///
/// Typing is not a fallback for a broken camera — it is the faster option when
/// twenty people are queuing at a beach and one phone is holding the QR.
/// Shared with `OurFightListView`, which reaches check-in from its card
/// rather than from a pushed detail screen.
struct CheckInSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let fight: Fight

    @State private var code = ""
    @State private var showingScanner = false
    @FocusState private var isFocused: Bool

    private var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.S.x4) {
                Text("Ask the organiser for this Fight's code.")
                    .font(Theme.F.body(14.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showingScanner = true
                } label: {
                    Label("Scan the code", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: Theme.S.x2) {
                    line
                    Text("or")
                        .font(Theme.F.body(12, weight: .semibold))
                        .foregroundStyle(Theme.C.neutral600)
                    line
                }

                TextField("ABC123", text: $code)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { submit() }
                    .padding(.vertical, Theme.S.x3)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.R.md).fill(Theme.C.surface)
                    )

                Button("Check in") { submit() }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!canSubmit)

                Spacer()
            }
            .padding(.horizontal, Theme.S.x4)
            .padding(.top, Theme.S.x4)
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                CheckInScannerView(fight: fight)
            }
            // The scanner dismisses itself on success; follow it out so the user
            // isn't left staring at a code field for something already done.
            .onChange(of: app.hasAttended(fight)) { _, attended in
                if attended { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var line: some View {
        Rectangle().fill(Theme.C.divider).frame(height: 1)
    }

    private func submit() {
        isFocused = false
        Task {
            let result = await app.checkIn(to: fight, code: code)
            if case .checkedIn = result { dismiss() } else { code = "" }
        }
    }
}
