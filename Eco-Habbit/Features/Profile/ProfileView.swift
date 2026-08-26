import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var badgeDetail: Badge?
    @State private var showingBadges = false
    @State private var confirmingDelete = false
    @State private var confirmingReset = false
    @State private var editingName = false
    @State private var draftName = ""

    /// Bound so the avatar's long-press menu can push. The settings list that used to
    /// hold every route is gone, so the menu is the only door to Debug tools.
    @State private var path = NavigationPath()

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    /// How far the green sheet reaches past the bottom of the identity, so the stats
    /// card lands on it rather than under it.
    private let sheetTail: CGFloat = 56
    /// And how far it reaches the other way. Enough to cover the status bar at rest and
    /// still be there at the top of a rubber-band overscroll, where a shape that stopped
    /// at the identity would tear open a white gap.
    private let sheetReach: CGFloat = 600

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                // The identity is the first thing in the scroll, not an overlay over it.
                // Pinned, it stayed put while the stats slid underneath and vanished
                // behind the name; in here the whole sheet travels with the content.
                VStack(alignment: .leading, spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 0) {
                        stats
                        badges
                        recap
                    }
                    // Only the content below is inset — the sheet has to reach both
                    // edges of the screen.
                    .padding(.horizontal, 20)
                }
                .tabContentInsets()
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .recap(let period): RecapView(period: period)
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

    /// The identity on the green sheet it sits on.
    ///
    /// The sheet is drawn as the identity's own background rather than as a layer
    /// behind the scroll view, which is what lets it scroll away: no measuring, and no
    /// height to keep in step with whatever the avatar and the name happen to add up
    /// to. It is stretched past its host at both ends by negative padding — a
    /// background is measured against what it backs and reports nothing back, so
    /// growing it moves nothing.
    private var header: some View {
        identity
            .padding(.horizontal, Tokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                UnevenRoundedRectangle(
                    bottomLeadingRadius: 40,
                    bottomTrailingRadius: 40,
                    style: .continuous
                )
                .fill(Tokens.Semantic.profileBg)
                .padding(.top, -sheetReach)
                .padding(.bottom, -sheetTail)
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
                    // The only route to the account actions, `deleteAccount` included —
                    // App Review requires that for any app with sign-in.
                    //
                    // `contextMenu` IS the long press, so there is no gesture to wire up
                    // and no state to hold for the menu itself.
                    .contextMenu {
                        #if DEBUG
                        // Compiled out of Release entirely — this is the time-travel
                        // and host-verification surface, not a user feature.
                        Button { path.append(ProfileRoute.debug) } label: {
                            Label("Debug tools", systemImage: "hammer")
                        }
                        #endif
                        Button {
                            draftName = app.data.userName
                            editingName = true
                        } label: {
                            Label("Edit name", systemImage: "pencil")
                        }
                        Button { app.logOut() } label: {
                            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        // Came off `SignOutFooter`, which hung from the settings list
                        // and went with it. Distinct from "Delete account": this starts
                        // the Earth over, it does not end the account.
                        Button(role: .destructive) { confirmingReset = true } label: {
                            Label("Reset local data", systemImage: "arrow.counterclockwise")
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
        .alert("Your name", isPresented: $editingName) {
            TextField("Name", text: $draftName)
                .textInputAutocapitalization(.words)
            Button("Save") { app.setUserName(draftName) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is the name shown on your profile and on any Fight you host.")
        }
        .alert("Delete account?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { Task { await app.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your points, streak, history and badges are permanently deleted from this device and from our servers. This cannot be undone.")
        }
        .alert("Reset local data?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { app.resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Points, streak, history and settings on this device are deleted. The Earth starts over from the beginning.")
        }
    }

    private var stats: some View {
        HStack(alignment: .center, spacing: 10) {
            StatTile(value: "\(app.streakDays)", label: "Day streak", icon: "flame.fill")
            Divider()
                .frame(width: 1)
                .overlay(Tokens.Semantic.statIcon)
            StatTile(value: "\(app.currentPoints)", label: "Points", icon: "leaf.fill")
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
    
    private var unlockedBadges: [Badge] {
        MockData.badges.filter(app.isUnlocked)
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
            if unlockedBadges.isEmpty {
                LazyVGrid(columns: badgeColumns) {
                    ForEach(MockData.badges.prefix(4)) { badge in
                        Button {
                            badgeDetail = badge
                        } label: {
                            LockedAvatar(type: .avatarSmall, icon: badge.icon)
                        }
                    }
                }
            } else {
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
        }
        .padding(.top, Tokens.Spacing.xxl)
    }

    /// Read from `app.today` rather than `Date()`, so the debug time-travel menu
    /// moves the recap cards along with everything else.
    private var thisMonth: RecapPeriod { .month(of: app.today) }
    private var thisYear: RecapPeriod { .year(of: app.today) }

    private var recap: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
            HStack{
                Text("Recap")
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
            }
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: Tokens.Spacing.lg){
                    // Captions come from the period rather than being written out:
                    // a card headed "July" that opens August's numbers is worse than
                    // no card, and the month rolls over on its own.
                    NavigationLink(value: ProfileRoute.recap(thisMonth)) {
                        RecapCards(caption: "Your \(thisMonth.shortTitle) Recap", icon: Tokens.Icons.badge1, background: Tokens.Palette.limeCard)
                    }
                    .buttonStyle(PlainPressStyle())
                    NavigationLink(value: ProfileRoute.recap(.allTime)) {
                        RecapCards(caption: RecapPeriod.allTime.title, icon: Tokens.Icons.energyIcon, background: Tokens.Palette.yellowCard)
                    }
                    .buttonStyle(PlainPressStyle())
                    NavigationLink(value: ProfileRoute.recap(thisYear)) {
                        RecapCards(caption: thisYear.title, icon: Tokens.Icons.wasteIcon, background: Tokens.Palette.purpleCard)
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }
        }
        .padding(.top, Tokens.Spacing.xxl)
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
        HStack(spacing: Tokens.Spacing.md){
            Text(caption)
                .minimumScaleFactor(0.8)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Semantic.text)
            Spacer()
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
        }
        .frame(width: 130, height: 148, alignment: .bottom)
        .padding([.horizontal], Tokens.Spacing.md)
        .padding([.vertical], Tokens.Spacing.lg)
        .background{
            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                .fill(background)
        }
    }
}
enum ProfileRoute: Hashable {
    case recap(RecapPeriod)
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
            // `unlocked` was carried by every call site but never rendered, so a
            // locked badge opened looking earned. Grey art behind a lock keeps
            // the name and detail below reading as a requirement, not a reward.
            if unlocked {
                Avatar(type: .avatarBig, icon: badge.icon)
            } else {
                LockedAvatar(type: .avatarBig, icon: badge.icon)
            }
 
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
            Tokens.Palette.white
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
