import SwiftUI

/// Profile, for an organisation.
///
/// A separate screen from `ProfileView` because there is almost nothing in common: an
/// organiser has no streak, no vitality, no badges and no Earth, and showing those as
/// permanent zeroes reads as a broken account rather than a different kind of one.
/// What an organiser has instead is events and the people who turned up to them.
///
/// Deliberately small. The last split in this app left a screen nothing rendered for
/// days, so the less there is here to drift from the rest, the better.
struct OrganisationProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var path = NavigationPath()
    @State private var editingName = false
    @State private var draftName = ""
    @State private var confirmingDelete = false

    /// `nil` until counted — an unknown total and a genuine zero are different things,
    /// and this needs the network to tell them apart.
    @State private var checkIns: Int?

    private var live: Int { app.hostedFights.filter { $0.status == .published }.count }
    private var drafts: Int { app.hostedFights.filter { $0.status == .draft }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    identity
                    stats
                    settings
                }
                .padding(.horizontal, Tokens.Spacing.xl)
                .padding(.top, Tokens.Spacing.xl)
                .tabContentInsets()
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .privacy: PrivacySettingsView()
                #if DEBUG
                case .debug: TimeTravelMenu()
                #endif
                default: EmptyView()
                }
            }
            .task(id: app.hostedFights.count) { await countCheckIns() }
            .refreshable { await countCheckIns() }
            .alert("Organisation name", isPresented: $editingName) {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)
                Button("Save") { app.setOrganisationName(draftName) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Shown as the host on every Fight you publish, including ones already live.")
            }
            .alert("Delete account?", isPresented: $confirmingDelete) {
                Button("Delete", role: .destructive) { Task { await app.deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your organisation and its data are permanently deleted. Published Fights stay visible to anyone who saved them.")
            }
        }
    }

    // MARK: - Identity

    private var identity: some View {
        VStack(alignment: .center, spacing: Tokens.Spacing.md) {
            Avatar(type: .user, icon: Tokens.Icons.mobilityIcon)
                .clipShape(Circle())
                .overlay(Circle().stroke(Tokens.Palette.white, lineWidth: 5))

            Text(app.orgName)
                .textStyle(Tokens.Typography.title2)
                .foregroundStyle(Tokens.Semantic.text)

            Text("Organisation")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - What an organiser actually has

    private var stats: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            tile("\(live)", "Live")
            tile("\(drafts)", "Drafts")
            tile(checkIns.map(String.init) ?? "—", "Check-ins")
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        EHCard {
            VStack(spacing: 2) {
                Text(value)
                    .font(Theme.F.heading(26))
                    .foregroundStyle(Theme.C.text)
                Text(label)
                    .font(Theme.F.body(12, weight: .semibold))
                    .foregroundStyle(Theme.C.neutral600)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// One read per hosted Fight. Fine for the handful an organiser runs, and the only
    /// way to get it — attendance lives in a shared collection, not on the event.
    private func countCheckIns() async {
        var total = 0
        for fight in app.hostedFights {
            total += await app.attendees(for: fight).count
        }
        checkIns = total
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            SectionHeading(text: "Account")

            EHCard(padding: 4) {
                VStack(spacing: 0) {
                    Button {
                        draftName = app.data.orgName
                        editingName = true
                    } label: {
                        SettingsRow(title: "Organisation name") {
                            Text(app.orgName)
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(PlainPressStyle())

                    NavigationLink(value: ProfileRoute.privacy) {
                        SettingsRow(title: "Privacy") { ChevronRight() }
                    }
                    .buttonStyle(PlainPressStyle())

                    #if DEBUG
                    NavigationLink(value: ProfileRoute.debug) {
                        SettingsRow(title: "Debug tools") { ChevronRight() }
                    }
                    .buttonStyle(PlainPressStyle())
                    #endif

                    Button { app.logOut() } label: {
                        SettingsRow(title: "Log out", showsDivider: true) { EmptyView() }
                    }
                    .buttonStyle(PlainPressStyle())

                    Button { confirmingDelete = true } label: {
                        SettingsRow(title: "Delete account", showsDivider: false) { EmptyView() }
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }

            Text("Signed in as \(app.data.email.isEmpty ? (app.userId ?? "—") : app.data.email)")
                .font(Theme.F.body(11.5))
                .foregroundStyle(Theme.C.neutral500)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
