import SwiftUI

/// PRD §6.5 — Browse and My Fights. Chronological; no map, no distance filter in v1.
struct FightListView: View {
    @EnvironmentObject private var app: AppState
    @State private var scope: Scope = .browse
    @State private var typeFilter: FightType?
    @State private var showingCreate = false

    enum Scope: Hashable { case browse, mine, hosting }

    /// PRD §6.5.1 — host mode is *additive*. A verified organisation sees the
    /// same Browse and My Fights as everyone else, because an organisation is
    /// still a user who attends other people's events, plus one extra segment.
    private var scopes: [(value: Scope, label: String)] {
        var options: [(Scope, String)] = [(.browse, "Browse"), (.mine, "Mine")]
        if app.isOrganization { options.append((.hosting, "Hosting")) }
        return options
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.S.x4) {
                    EHSegmented(options: scopes, selection: $scope)
                        .padding(.horizontal, Theme.S.x4)

                    switch scope {
                    case .browse: browse
                    case .mine: mine
                    case .hosting: hosting
                    }
                }
                .padding(.top, Theme.S.x3)
                .tabContentInsets()
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle("Fights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if app.isOrganization {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingCreate = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Create a Fight")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) { EventFormView(app: app) }
            .navigationDestination(for: Fight.self) { FightDetailView(fight: $0) }
            .navigationDestination(for: HostRoute.self) { route in
                ManageEventView(fight: route.fight)
            }
        }
    }

    /// Distinct from pushing a `Fight`, which goes to the attendee-facing detail.
    struct HostRoute: Hashable { let fight: Fight }

    // MARK: - Hosting

    private var hosting: some View {
        VStack(alignment: .leading, spacing: Theme.S.x3) {
            if app.hostedFights.isEmpty {
                emptyState("You haven't created a Fight yet.",
                           "Use + to draft one. It stays private until you publish.")
            } else {
                ForEach(app.hostedFights) { fight in
                    NavigationLink(value: HostRoute(fight: fight)) {
                        FightCard(fight: fight, hostStatus: fight.status)
                    }
                    .buttonStyle(PlainPressStyle())
                }
                .padding(.horizontal, Theme.S.x4)
            }
        }
    }

    // MARK: - Browse

    private var browse: some View {
        VStack(spacing: Theme.S.x3) {
            typeFilterStrip

            let fights = filtered
            if fights.isEmpty {
                emptyState("No Fights of that type yet.", "Try another filter.")
            } else {
                ForEach(fights) { fight in
                    NavigationLink(value: fight) {
                        FightCard(fight: fight, isSignedUp: app.isSignedUp(fight))
                    }
                    .buttonStyle(PlainPressStyle())
                }
                .padding(.horizontal, Theme.S.x4)
            }
        }
    }

    private var filtered: [Fight] {
        guard let typeFilter else { return app.upcomingFights }
        return app.upcomingFights.filter { $0.type == typeFilter }
    }

    private var typeFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.S.x2) {
                filterChip(label: "All", isOn: typeFilter == nil) { typeFilter = nil }
                ForEach(FightType.allCases) { type in
                    filterChip(label: type.shortName, isOn: typeFilter == type) {
                        typeFilter = typeFilter == type ? nil : type
                    }
                }
            }
            .padding(.horizontal, Theme.S.x4)
        }
    }

    private func filterChip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.F.body(13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Theme.C.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isOn ? Theme.C.accent500 : .clear)
                        .overlay(Capsule().stroke(isOn ? .clear : Theme.C.divider, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - My Fights

    private var mine: some View {
        VStack(alignment: .leading, spacing: Theme.S.x4) {
            section("Upcoming", fights: app.myUpcomingFights,
                    empty: "Nothing booked yet.", hint: "Join a Fight from Browse.")
            section("Past", fights: app.pastFights,
                    empty: "No Fights attended yet.", hint: "Attended Fights are kept here permanently.")
        }
        .padding(.horizontal, Theme.S.x4)
    }

    @ViewBuilder
    private func section(_ title: String, fights: [Fight], empty: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.x2) {
            SectionHeading(text: title)
            if fights.isEmpty {
                emptyState(empty, hint).padding(.horizontal, -Theme.S.x4)
            } else {
                ForEach(fights) { fight in
                    NavigationLink(value: fight) {
                        FightCard(fight: fight, isSignedUp: app.isSignedUp(fight),
                                  hasAttended: app.hasAttended(fight))
                    }
                    .buttonStyle(PlainPressStyle())
                }
            }
        }
    }

    private func emptyState(_ title: String, _ hint: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.F.body(15, weight: .semibold)).foregroundStyle(Theme.C.text)
            Text(hint).font(Theme.F.body(13)).foregroundStyle(Theme.C.neutral600)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.S.x6)
        .padding(.horizontal, Theme.S.x4)
    }
}

// MARK: - Card

struct FightCard: View {
    let fight: Fight
    var isSignedUp = false
    var hasAttended = false
    /// Set on the Hosting list so a draft is obviously not public yet.
    var hostStatus: Fight.Status?

    var body: some View {
        EHCard {
            VStack(alignment: .leading, spacing: Theme.S.x2) {
                HStack(spacing: Theme.S.x2) {
                    Image(systemName: fight.type.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.C.accent2_700)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.C.accent2_100))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(fight.type.name)
                            .font(Theme.F.body(11.5, weight: .semibold))
                            .foregroundStyle(Theme.C.neutral600)
                        Text(fight.hostName)
                            .font(Theme.F.body(13, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                    }

                    Spacer()

                    switch hostStatus {
                    case .draft: EHTag(text: "Draft", style: .neutral)
                    case .cancelled: EHTag(text: "Cancelled", style: .accent)
                    case .published: EHTag(text: "Live", style: .accent2)
                    case nil:
                        if hasAttended {
                            EHTag(text: "Attended", style: .accent2)
                        } else if isSignedUp {
                            EHTag(text: "Joined", style: .outline)
                        }
                    }
                }

                Text(fight.title)
                    .font(Theme.F.heading(17))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Label(FightFormat.when(fight), systemImage: "calendar")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral700)

                Label(fight.locationName, systemImage: "mappin.and.ellipse")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .lineLimit(1)

                HStack {
                    EHTag(text: "+\(fight.attendancePoints) pts", style: .accent)
                    Spacer()
                    if fight.isCheckInOpen() {
                        Text("Check-in open")
                            .font(Theme.F.body(11.5, weight: .bold))
                            .foregroundStyle(Theme.C.accent2_700)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

/// Date formatting shared by the card, the detail screen and the dashboard.
enum FightFormat {
    static func when(_ fight: Fight) -> String {
        let day = fight.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let from = fight.startsAt.formatted(date: .omitted, time: .shortened)
        let to = fight.endsAt.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(from)–\(to)"
    }

    static func countdown(_ fight: Fight, from now: Date = Date()) -> String {
        let seconds = fight.startsAt.timeIntervalSince(now)
        if seconds < 0 { return "Happening now" }
        let hours = Int(seconds / 3600)
        if hours < 1 { return "Starts in \(max(1, Int(seconds / 60))) min" }
        if hours < 24 { return "Starts in \(hours)h" }
        return "In \(hours / 24) day\(hours / 24 == 1 ? "" : "s")"
    }
}
