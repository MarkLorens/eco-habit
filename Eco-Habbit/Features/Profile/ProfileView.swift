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

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    
    @State private var headerHeight: CGFloat = 0
    private let sheetTail: CGFloat = 56

    var body: some View {
        NavigationStack {
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
        .sheet(item: $badgeDetail) { badge in
            BadgeDetailSheet(badge: badge, unlocked: app.isUnlocked(badge))
                .presentationDetents([.height(340)])
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
            Text(app.userName)
                .textStyle(Tokens.Typography.title2)
                .foregroundStyle(Tokens.Semantic.text)
        }
        .frame(maxWidth: .infinity)
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
                NavigateButton(background: Tokens.Semantic.buttonTintDefault, direction: .right){
                    print("tapped")
                }
            }
            LazyVGrid(columns: badgeColumns) {
                ForEach(MockData.badges.prefix(4)) { badge in
                    Button {
                        badgeDetail = badge
                    } label: {
                        Avatar(type: .avatarSmall, icon: Tokens.Icons.energyIcon)
                    }
                    .buttonStyle(PlainPressStyle())
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
                    recapCards(caption: "Your July Recap", icon: Tokens.Icons.actionIcon, background: Tokens.Palette.limeCard)
                    recapCards(caption: "All Time", icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard)
                    recapCards(caption: "2026", icon: Tokens.Icons.wasteIcon, background: Tokens.Palette.purpleCard)
                    recapCards(caption: "I'm hiding", icon: Tokens.Icons.mobilityIcon, background: Tokens.Palette.greenCard)
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

private struct recapCards: View {
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
                    Text("Points, streak, history and settings on this device are deleted. The account starts over at Vitality \(VitalityEngine.startingVitality).")
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

/// Everything at zero: all-locked badge grid, "0" stat tiles, no favourites,
/// notifications off, empty history count.
#Preview("Fresh account") {
    ProfileView()
        .environmentObject(AppState(data: .preview(
            vitality: VitalityEngine.startingVitality,
            streak: 0,
            longestStreak: 0,
            actions: 0,
            favourites: [],
            notifications: false
        )))
}

/// Clears every unlockable threshold — 100 actions, 30-day streak, 86 Vitality,
/// 3 Foundations — and pushes the stat tiles to three digits.
#Preview("Everything unlocked") {
    ProfileView()
        .environmentObject(AppState(data: .preview(
            vitality: 92,
            streak: 34,
            longestStreak: 41,
            actions: 120,
            favourites: Set(HabitCategory.allCases)
        )))
}

/// The badge grid is four fixed columns with a 26pt two-line label, so it is the
/// first thing to break at large type. The long name also stresses `initials`.
#Preview("Long name · large type") {
    ProfileView()
        .environmentObject(AppState(data: .preview(
            name: "Anandamayi Wirawan-Kusumaningrum"
        )))
        .environment(\.dynamicTypeSize, .accessibility1)
}
#endif

private struct BadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let badge: Badge
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        unlocked
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Theme.C.accent500, Theme.C.accent2_500],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Theme.C.neutral200)
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: unlocked ? "star.fill" : "lock.fill")
                    .font(.system(size: unlocked ? 28 : 22, weight: .semibold))
                    .foregroundStyle(unlocked ? .white : Theme.C.neutral500)
            }
            .padding(.top, 28)

            Text(badge.name)
                .font(Theme.F.heading(19))
                .foregroundStyle(Theme.C.text)

            EHTag(text: badge.tier, style: .neutral, fontSize: 12)

            Text(badge.detail)
                .font(Theme.F.body(13.5))
                .foregroundStyle(Theme.C.neutral700)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(unlocked ? "Unlocked" : "Still locked")
                .font(Theme.F.body(12, weight: .semibold))
                .foregroundStyle(unlocked ? Theme.C.accent2_700 : Theme.C.neutral600)

            Spacer()

            Button("Close") { dismiss() }
                .buttonStyle(SecondaryButtonStyle(height: 44))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.C.bg)
    }
}
