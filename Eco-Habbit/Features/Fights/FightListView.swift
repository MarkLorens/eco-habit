import SwiftUI

/// One page of Fights. Chronological; no map, no distance filter in v1.
///
/// Deliberately flat — this replaced a Browse/Mine/Hosting segmented control.
/// Two of those three segments were nearly always empty, so the first thing a
/// new user saw was a tab bar guarding two blank screens. Saved moved to a
/// toolbar button and hosting to a row that only organisers see.
struct FightListView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingCreate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.S.x3) {
                    if app.isOrganization { hostingStrip }
                    subtitle
                    list
                }
                .padding(.top, Theme.S.x3)
                .tabContentInsets()
            }
            .background(Tokens.Palette.white.ignoresSafeArea())
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
                emptyState("No upcoming Fights.", "New ones appear here as partners post them.")
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

    /// Sits under the large navigation title, matching the mockup.
    private var subtitle: some View {
        Text("Take action together for a greener tomorrow")
            .font(.system(size: 12))
            .foregroundStyle(Tokens.Semantic.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.S.x4)
    }

    /// Hosted drafts appear alongside the public list for their own organiser,
    /// so a half-written Fight is somewhere they can find it again.
    private var filtered: [Fight] {
        var fights = app.upcomingFights
        let drafts = app.hostedFights.filter { $0.status == .draft }
        fights.insert(contentsOf: drafts, at: 0)
        return fights
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

#Preview {
    FightListView()
        .environmentObject(AppState(store: InMemoryKeyValueStore()))
}
