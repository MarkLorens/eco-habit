import SwiftUI

/// One page of Fights. Chronological; no map, no distance filter in v1.
///
/// Deliberately flat — this replaced a Browse/Mine/Hosting segmented control.
/// Two of those three segments were nearly always empty, so the first thing a
/// new user saw was a tab bar guarding two blank screens. Saved moved to a
/// toolbar button and hosting to a row that only organisers see.
struct FightListView: View {
    @EnvironmentObject private var app: AppState
    @State private var typeFilter: FightType?
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.S.x3) {
                    if app.isOrganization { hostingStrip }
                    typeFilterStrip
                    list
                }
                .padding(.top, Theme.S.x3)
                .tabContentInsets()
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle("Our Fights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: SavedRoute()) {
                        Image(systemName: app.savedFights.isEmpty ? "bookmark" : "bookmark.fill")
                    }
                    .accessibilityLabel("Saved Fights")
                }
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
            .navigationDestination(for: SavedRoute.self) { _ in SavedFightsView() }
            .navigationDestination(for: HostRoute.self) { route in
                ManageEventView(fight: route.fight)
            }
        }
    }

    /// Distinct from pushing a `Fight`, which goes to the attendee-facing detail.
    struct HostRoute: Hashable { let fight: Fight }
    struct SavedRoute: Hashable {}

    // MARK: - Hosting

    /// A single row rather than a segment: hosting is a minority activity, and
    /// giving it a third of the top of the screen made it look like the point.
    private var hostingStrip: some View {
        EHCard {
            HStack(spacing: Theme.S.x3) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.C.accent700)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.C.accent100))
                VStack(alignment: .leading, spacing: 1) {
                    Text("You host Fights")
                        .font(Theme.F.body(14, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Text(app.hostedFights.isEmpty
                         ? "Use + to draft your first one."
                         : "\(app.hostedFights.count) created — open one to manage it.")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .padding(.horizontal, Theme.S.x4)
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: Theme.S.x3) {
            let fights = filtered
            if fights.isEmpty {
                emptyState("No Fights of that type yet.", "Try another filter.")
            } else {
                ForEach(fights) { fight in
                    NavigationLink(value: fight) {
                        FightCard(
                            fight: fight,
                            isSaved: app.isSaved(fight),
                            hasAttended: app.hasAttended(fight),
                            hostStatus: app.isHost(of: fight) ? fight.status : nil
                        )
                    }
                    .buttonStyle(PlainPressStyle())
                }
                .padding(.horizontal, Theme.S.x4)
            }
        }
    }

    /// Hosted drafts appear alongside the public list for their own organiser,
    /// so a half-written Fight is somewhere they can find it again.
    private var filtered: [Fight] {
        var fights = app.upcomingFights
        let drafts = app.hostedFights.filter { $0.status == .draft }
        fights.insert(contentsOf: drafts, at: 0)
        guard let typeFilter else { return fights }
        return fights.filter { $0.type == typeFilter }
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
    var isSaved = false
    var hasAttended = false
    /// Set only for the organiser of this Fight, so a draft is obviously not public yet.
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
                        } else if isSaved {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.C.accent600)
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
