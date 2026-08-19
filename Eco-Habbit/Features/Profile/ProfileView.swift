import SwiftUI

private struct HeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}


struct ProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var badgeDetail: Badge?
    @State private var showingBadges = false
    @State private var confirmingDelete = false

    /// Bound so the avatar's long-press menu can push. `settings` — the list that used
    /// to hold every route — is commented out of `body`, which left Debug tools with no
    /// door at all.
    @State private var path = NavigationPath()

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    
    @State private var headerHeight: CGFloat = 0
    private let sheetTail: CGFloat = 56

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    stats
                    badges
                    recap
//                    settings
                }
                .padding(.horizontal, 20)
                // The identity block is an overlay, so it takes up no layout space —
                // without this the stats row starts at the top of the ScrollView and
                // renders behind it.
                .padding(.top, headerHeight)
                .tabContentInsets()
            }
            .background(alignment: .top) {
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 40,
                    bottomTrailingRadius: 40,
                    style: .continuous
                )
                .fill(Tokens.Semantic.profileBg)
                .frame(height: headerHeight + sheetTail)
            }
            .overlay(alignment: .top) {
                identity
                    .padding(.horizontal, Tokens.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        UnevenRoundedRectangle(
                            bottomLeadingRadius: 40,
                            bottomTrailingRadius: 40,
                            style: .continuous
                        )
                        .fill(Tokens.Semantic.profileBg)
                        .ignoresSafeArea(edges: .top)
                    )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: HeaderHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
            }
            .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .favourites: FavouriteCategoriesView()
                case .notifications: NotificationSettingsView()
                case .privacy: PrivacySettingsView()
                case .history: ActivityHistoryView()
                #if DEBUG
                case .debug: TimeTravelMenu()
                #endif
                }
            }
        }
        .modalCard(item: $badgeDetail) { badge in
            BadgeDetailSheet(badge: badge, unlocked: app.isUnlocked(badge)){
                badgeDetail = nil
            }
        }
        .fullScreenCover(isPresented: $showingBadges){
            BadgeDetailView()
        }
    }

    private var identity: some View {
        VStack(alignment: .center, spacing: Tokens.Spacing.xl) {
            Avatar(type: .user, icon: Tokens.Icons.wasteIcon)
                .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Tokens.Palette.white, lineWidth: 5)
                    )
                    // The only route to the account actions. `SignOutFooter` hangs off
                    // `settings`, which is commented out of `body`, so nothing on screen
                    // reached `logOut` and nothing at all reached `deleteAccount` — which
                    // App Review requires for any app with sign-in.
                    //
                    // `contextMenu` IS the long press, so there is no gesture to wire up
                    // and no state to hold for the menu itself.
                    .contextMenu {
                        #if DEBUG
                        // Compiled out of Release entirely. The only way in: the
                        // settings list that used to carry this route is commented
                        // out of `body`.
                        Button { path.append(ProfileRoute.debug) } label: {
                            Label("Debug tools", systemImage: "hammer")
                        }
                        #endif
                        Button { app.logOut() } label: {
                            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Label("Delete account", systemImage: "trash")
                        }
                    }
                    // Long press leaves no visual trace, so VoiceOver has to be told.
                    .accessibilityLabel("Account")
                    .accessibilityHint("Long press for log out and delete account")
            Text(app.userName)
                .textStyle(Tokens.Typography.title2)
                .foregroundStyle(Tokens.Semantic.text)
        }
        .frame(maxWidth: .infinity)
        .alert("Delete account?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await app.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your points, streak, history and badges are permanently deleted from this device and from our servers. This cannot be undone.")
        }
    }

    private var initials: String {
        let parts = app.userName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var stats: some View {
        HStack(alignment: .center, spacing: 10) {
            StatTile(value: "\(app.streakDays)", label: "Day streak", icon: "flame.fill")
            Divider()
                .frame(width: 1)
                .overlay(Tokens.Semantic.statIcon)
            StatTile(value: "\(app.vitality)", label: "Vitality", icon: "smoke.fill")
            Divider()
                .frame(width: 1)
                .overlay(Tokens.Semantic.statIcon)
            StatTile(value: "\(app.unlockedBadgeCount)", label: "Badges", icon: "medal.star.fill")
        }
        .padding([.vertical], Tokens.Spacing.md)
        .background{
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                .fill(Tokens.Palette.white)
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .shadow(
                    color: .black.opacity(0.17),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .padding(.top, Tokens.Spacing.xl)
        
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack{
                Text("Badges")
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
                Spacer()
                NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .forward){
                    showingBadges = true
                }
            }
            LazyVGrid(columns: badgeColumns) {
                ForEach(MockData.badges.filter(app.isUnlocked).prefix(4)) { badge in
                    Button {
                        badgeDetail = badge
                    } label: {
                        Avatar(type: .avatarSmall, icon: badge.icon)
                    }
                }
            }
        }
        .padding(.top, Tokens.Spacing.xxl)
    }

    /// Whether the Activity history row still needs its divider — false in
    /// Release, where it is the last row.
    private var debugRowVisible: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
    
    private var recap: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack{
                Text("Recap")
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
            }
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: Tokens.Spacing.lg){
                    RecapCards(caption: "Your July Recap", icon: Tokens.Icons.actionIcon, background: Tokens.Palette.limeCard)
                    RecapCards(caption: "All Time", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard)
                    RecapCards(caption: "2026", icon: Tokens.Icons.wasteIcon, background: Tokens.Palette.purpleCard)
                    RecapCards(caption: "I'm hiding", icon: Tokens.Icons.mobilityIcon, background: Tokens.Palette.greenCard)
                }
            }
        }
        .padding(.top, Tokens.Spacing.xxl)
    }

    private var settings: some View {
        EHCard(padding: 4) {
            VStack(spacing: 0) {
                NavigationLink(value: ProfileRoute.favourites) {
                    SettingsRow(title: "Favorite categories") {
                        HStack(spacing: 6) {
                            Text("\(app.favouriteCategories.count)")
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                            ChevronRight()
                        }
                    }
                }
                .buttonStyle(PlainPressStyle())

                NavigationLink(value: ProfileRoute.notifications) {
                    SettingsRow(title: "Notifications") {
                        HStack(spacing: 6) {
                            Text(app.notificationsEnabled ? "On" : "Off")
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                            ChevronRight()
                        }
                    }
                }
                .buttonStyle(PlainPressStyle())

                NavigationLink(value: ProfileRoute.privacy) {
                    SettingsRow(title: "Privacy") { ChevronRight() }
                }
                .buttonStyle(PlainPressStyle())

                NavigationLink(value: ProfileRoute.history) {
                    SettingsRow(title: "Activity history", showsDivider: debugRowVisible) {
                        HStack(spacing: 6) {
                            Text("\(app.totalActionsLogged)")
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                            ChevronRight()
                        }
                    }
                }
                .buttonStyle(PlainPressStyle())

                #if DEBUG
                // Compiled out of Release entirely — this is the time-travel and
                // host-verification surface, not a user feature.
                NavigationLink(value: ProfileRoute.debug) {
                    SettingsRow(title: "Debug tools", showsDivider: false) {
                        HStack(spacing: 6) {
                            Text(app.isOrganization ? "Org" : "")
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                            ChevronRight()
                        }
                    }
                }
                .buttonStyle(PlainPressStyle())
                #endif
            }
        }
        .padding(.top, 24)
        .modifier(SignOutFooter())
    }
}

private struct RecapCards: View {
    private let caption: String
    private let icon: String
    private let background: Color
    
    init(caption: String, icon: String, background: Color) {
        self.caption = caption
        self.icon = icon
        self.background = background
    }
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.xxl){
            Text(caption)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
            Image(icon)
                .resizable()
                .scaledToFit()
        }
        .frame(maxWidth: 127, maxHeight: 148, alignment: .bottom)
        .padding([.horizontal], Tokens.Spacing.md)
        .padding([.vertical], Tokens.Spacing.lg)
        .background{
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                .fill(background)
        }
    }
}
private struct SignOutFooter: ViewModifier {
    @EnvironmentObject private var app: AppState
    @State private var confirmingReset = false

    func body(content: Content) -> some View {
        VStack(spacing: 10) {
            content

            Button("Log out") { app.logOut() }
                .buttonStyle(SecondaryButtonStyle(height: 46))
                .padding(.top, 14)

            Button("Reset local data") { confirmingReset = true }
                .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                .alert("Reset local data?", isPresented: $confirmingReset) {
                    Button("Reset", role: .destructive) { app.resetEverything() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Points, streak, history and settings on this device are deleted. The Earth starts over from the beginning.")
                }
        }
    }
}

enum ProfileRoute: Hashable {
    case favourites, notifications, privacy, history
    #if DEBUG
    case debug
    #endif
}

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
                .foregroundStyle(Tokens.Semantic.statIcon)
            Text(value)
                .textStyle(Tokens.Typography.hero)
            Text(label)
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
            }
            .frame(maxWidth: .infinity)
        }
}

#if DEBUG
// ProfileView owns its own NavigationStack, so these don't add one.

#Preview("Profile") {
    ProfileView()
        .environmentObject(AppState(data: .preview()))
}
#endif

struct BadgeDetailSheet: View {
    let badge: Badge
    let unlocked: Bool
    let onClose: () -> Void
 
    var body: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Avatar(type: .avatarBig, icon: badge.icon)
 
            Text(badge.name)
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)
                .multilineTextAlignment(.center)
 
            Text(badge.detail)
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Spacing.xl)
        .overlay(alignment: .topTrailing){
            NavigateButton(background: Tokens.Semantic.buttonTintDefault, buttonAction: .close) { onClose() }
        }
        .padding(Tokens.Spacing.lg)
    }
}

#if DEBUG
#Preview("Badge · unlocked") {
    BadgeDetailSheet(badge: MockData.badges[0], unlocked: true) { print("tapped") }
        .frame(height: 340)
}

#Preview("Badge · locked") {
    BadgeDetailSheet(badge: MockData.badges[0], unlocked: false) { print("tapped") }
        .frame(height: 340)
}

#Preview("Badge · longest copy") {
    let longest = MockData.badges.max { $0.detail.count < $1.detail.count } ?? MockData.badges[0]
    BadgeDetailSheet(badge: longest, unlocked: true) { print("tapped") }
        .frame(height: 340)
}

#Preview("Badge · longest · large type") {
    let longest = MockData.badges.max { $0.detail.count < $1.detail.count } ?? MockData.badges[0]
    BadgeDetailSheet(badge: longest, unlocked: false) { print("tapped") }
        .frame(height: 340)
        .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Badge · in a sheet") {
    struct Harness: View {
        @State private var badge: Badge? = MockData.badges.first
        var body: some View {
            Theme.C.bg
                .ignoresSafeArea()
                .sheet(item: $badge) { badge in
                    BadgeDetailSheet(badge: badge, unlocked: true) { print("tapped") }
                        .presentationDetents([.height(340)])
                }
        }
    }
    return Harness()
}
#endif
