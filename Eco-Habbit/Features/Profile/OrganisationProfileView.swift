import SwiftUI

/// Profile, for an organisation.
///
/// A separate screen from `ProfileView` because there is almost nothing in common: an
/// organiser has no streak, no vitality, no badges and no Earth, and showing those as
/// permanent zeroes reads as a broken account rather than a different kind of one. What
/// an organiser has instead is events and the people who turned up to them.
///
/// **Drawn in `Tokens`, not `Theme`.** Two design systems live in this app — `Theme` is
/// the older one — and mixing them inside a screen is what made this look like it came
/// from a different app than Our Fights, which is the only other place an organiser
/// ever is. Same hero title, same footnote subtitle, same white ground, same rounded
/// cards.
struct OrganisationProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var path = NavigationPath()
    @State private var editingName = false
    @State private var draftName = ""
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xl) {
                    header
                    identity
                    settings
                }
                .padding(.horizontal, Tokens.Spacing.xl)
                .tabContentInsets()
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .statusBarCover()
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                #if DEBUG
                case .debug: TimeTravelMenu()
                #endif
                default: EmptyView()
                }
            }
            .alert("Organization name", isPresented: $editingName) {
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
                Text("Your organization and its data are permanently deleted. Published Fights stay visible to anyone who saved them.")
            }
        }
    }

    // MARK: - Header, matching Our Fights

    /// Same inset as Our Fights (`xxl`) rather than the page's `xl`, so the two hero
    /// titles line up when you switch tabs instead of shifting a few points sideways.
    private var header: some View {
        Text("Profile")
            .textStyle(Tokens.Typography.hero)
            .foregroundStyle(Tokens.Semantic.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Spacing.xxl - Tokens.Spacing.xl)
            .padding(.top, Tokens.Spacing.md)
    }

    private var identity: some View {
        VStack(alignment: .center, spacing: Tokens.Spacing.md) {
            Avatar(type: .user, icon: Tokens.Icons.mobilityIcon)
                .clipShape(Circle())
                .overlay(Circle().stroke(Tokens.Palette.white, lineWidth: 5))

            Text(app.orgName)
                .textStyle(Tokens.Typography.title2)
                .foregroundStyle(Tokens.Semantic.text)

            Text("Organization")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(Tokens.Semantic.profileBg)
        )
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(spacing: 0) {
            row("Organization name") {
                draftName = app.data.orgName
                editingName = true
            } trailing: {
                Text(app.orgName)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .lineLimit(1)
            }

            #if DEBUG
            navRow("Debug tools", to: .debug)
            #endif

            row("Log out") { app.logOut() } trailing: { EmptyView() }
            row("Delete account", showsDivider: false) { confirmingDelete = true } trailing: {
                EmptyView()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                .fill(Tokens.Semantic.buttonTintDefault)
        )
    }

    private func navRow(_ title: String, to route: ProfileRoute) -> some View {
        NavigationLink(value: route) {
            rowBody(title, showsDivider: true) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Semantic.statIcon)
            }
        }
        .buttonStyle(.plain)
    }

    private func row<Trailing: View>(_ title: String,
                                     showsDivider: Bool = true,
                                     action: @escaping () -> Void,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        Button(action: action) {
            rowBody(title, showsDivider: showsDivider, trailing: trailing)
        }
        .buttonStyle(.plain)
    }

    private func rowBody<Trailing: View>(_ title: String,
                                         showsDivider: Bool,
                                         @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                Spacer(minLength: Tokens.Spacing.md)
                trailing()
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
        .contentShape(Rectangle())
    }
}
