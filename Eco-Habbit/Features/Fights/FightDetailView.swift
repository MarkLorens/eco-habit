import SwiftUI

/// PRD §6.5 — Fight detail. Join / Cancel, and once joined, the check-in QR.
struct FightDetailView: View {
    @EnvironmentObject private var app: AppState
    let fight: Fight

    @State private var showingQR = false

    private var isSignedUp: Bool { app.isSignedUp(fight) }
    private var hasAttended: Bool { app.hasAttended(fight) }

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
        .sheet(isPresented: $showingQR) {
            if let signup = app.signup(for: fight) {
                CheckInQRView(fight: fight, signup: signup)
            }
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
            HStack(spacing: Theme.S.x3) {
                Text("+\(fight.attendancePoints)")
                    .font(Theme.F.heading(30))
                    .foregroundStyle(Theme.C.accent2_700)
                VStack(alignment: .leading, spacing: 2) {
                    Text("points")
                        .font(Theme.F.body(14.5, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Text("Counts against the same monthly event quota as a claimed event.")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral700)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: Theme.S.x2) {
            // PRD §6.5.1 — host-owned events gain a Manage action here. An
            // organisation can still join someone else's Fight, so this is
            // additive rather than a replacement for the join button.
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
                Label("Attended — +\(fight.attendancePoints) pts credited",
                      systemImage: "checkmark.seal.fill")
                    .font(Theme.F.body(14.5, weight: .bold))
                    .foregroundStyle(Theme.C.accent2_700)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.S.x3)

            } else if isSignedUp {
                Button("Show my check-in code") { showingQR = true }
                    .buttonStyle(PrimaryButtonStyle())

                // Stands in for the host's scanner until Phase 10 (§9.3).
                if fight.isCheckInOpen() {
                    Button("Simulate host scan") { Task { await app.checkIn(to: fight) } }
                        .buttonStyle(SecondaryButtonStyle())
                }

                Button("Cancel signup") { Task { await app.cancelFight(fight) } }
                    .buttonStyle(GhostButtonStyle())

                Text("No penalty for cancelling.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)

            } else {
                Button("Join this Fight") { Task { await app.joinFight(fight) } }
                    .buttonStyle(PrimaryButtonStyle())

                Text("Signing up shares your display name with \(fight.hostName).")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Theme.S.x2)
    }
}
