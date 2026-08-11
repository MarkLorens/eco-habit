import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var badgeDetail: Badge?

    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identity
                    stats
                    badges
                    settings
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .tabContentInsets()
            }
            .background(Theme.C.bg)
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
        .tint(Theme.C.accent)
        .sheet(item: $badgeDetail) { badge in
            BadgeDetailSheet(badge: badge, unlocked: app.isUnlocked(badge))
                .presentationDetents([.height(340)])
        }
    }

    private var identity: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.C.accent300, Theme.C.accent2_300],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Text(initials)
                        .font(Theme.F.heading(20))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(app.userName)
                    .font(Theme.F.heading(19))
                    .foregroundStyle(Theme.C.text)
                EHTag(text: "Level \(app.level) · \(app.levelTitle)", style: .accent)
            }

            Spacer()
        }
    }

    private var initials: String {
        let parts = app.userName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(app.vitality)", label: "Vitality")
            StatTile(value: "\(app.streakDays)", label: "Day streak")
            StatTile(value: "\(app.unlockedBadgeCount)", label: "Badges")
        }
        .padding(.top, 18)
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Badges")

            LazyVGrid(columns: badgeColumns, spacing: 14) {
                ForEach(MockData.badges) { badge in
                    let unlocked = app.isUnlocked(badge)
                    Button {
                        badgeDetail = badge
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        unlocked
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [Theme.C.accent500, Theme.C.accent2_500],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(Theme.C.neutral200)
                                    )
                                    .frame(width: 52, height: 52)

                                Image(systemName: unlocked ? "star.fill" : "lock.fill")
                                    .font(.system(size: unlocked ? 20 : 16, weight: .semibold))
                                    .foregroundStyle(unlocked ? .white : Theme.C.neutral500)
                            }

                            Text(badge.name)
                                .font(Theme.F.body(10.5))
                                .foregroundStyle(Theme.C.neutral700)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(height: 26, alignment: .top)
                        }
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }
        }
        .padding(.top, 24)
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

    var body: some View {
        EHCard(padding: 12) {
            VStack(spacing: 2) {
                Text(value)
                    .font(Theme.F.heading(18))
                    .foregroundStyle(Theme.C.text)
                    .contentTransition(.numericText())
                Text(label)
                    .font(Theme.F.body(11))
                    .foregroundStyle(Theme.C.neutral600)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

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
