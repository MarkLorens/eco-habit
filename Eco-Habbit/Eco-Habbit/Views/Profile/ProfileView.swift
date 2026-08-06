import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var app: AppState

    @State private var badgeDetail: Badge?
    @State private var photoViewer: EvidencePhoto?
    @State private var showingWrap = false

    private let photoColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    private let badgeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    identity
                    stats
                    wrapBanner
                    wallOfFame
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
                }
            }
        }
        .tint(Theme.C.accent)
        .sheet(item: $badgeDetail) { badge in
            BadgeDetailSheet(badge: badge, unlocked: app.isUnlocked(badge))
                .presentationDetents([.height(340)])
        }
        .fullScreenCover(item: $photoViewer) { photo in
            EvidenceViewer(photo: photo)
        }
        .fullScreenCover(isPresented: $showingWrap) {
            MonthlyWrapView()
        }
    }

    // MARK: Identity

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

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 10) {
            StatTile(value: app.earthPoints.formatted(), label: "Earth points")
            StatTile(value: "\(app.streakDays)", label: "Day streak")
            StatTile(value: "\(app.unlockedBadgeCount)", label: "Badges")
        }
        .padding(.top, 18)
    }

    // MARK: Monthly wrap

    private var wrapBanner: some View {
        Button {
            showingWrap = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Wrap")
                    .font(Theme.F.body(12))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Your \(Date().formatted(.dateTime.month(.wide))) Wrap is ready")
                    .font(Theme.F.heading(18))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Theme.R.lg)
                    .fill(
                        LinearGradient(
                            colors: [Theme.C.accent600, Theme.C.accent2_600],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(PlainPressStyle())
        .padding(.top, 18)
    }

    // MARK: Wall of Fame

    private var wallOfFame: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeading(text: "Wall of Fame — this month")
                if !app.evidenceThisMonth.isEmpty {
                    Text("\(app.evidenceThisMonth.count)")
                        .font(Theme.F.body(13, weight: .semibold))
                        .foregroundStyle(Theme.C.neutral600)
                }
            }

            if app.evidenceThisMonth.isEmpty {
                EHCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No evidence photos yet")
                            .font(Theme.F.body(14, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        Text("Attach a photo to an activity — or snap one from the camera tab — and it lands here. Photos also earn a \(Int(PointsEngine.evidenceBonusRate * 100))% bonus.")
                            .font(Theme.F.body(13))
                            .foregroundStyle(Theme.C.neutral700)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                LazyVGrid(columns: photoColumns, spacing: 8) {
                    ForEach(app.evidenceThisMonth) { photo in
                        Button {
                            photoViewer = photo
                        } label: {
                            EvidenceThumbnail(photo: photo)
                        }
                        .buttonStyle(PlainPressStyle())
                    }
                }
            }
        }
        .padding(.top, 24)
    }

    // MARK: Badges

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

    // MARK: Settings

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
                    SettingsRow(title: "Activity history", showsDivider: false) {
                        HStack(spacing: 6) {
                            Text("\(app.totalActionsLogged)")
                                .font(Theme.F.body(13))
                                .foregroundStyle(Theme.C.neutral600)
                            ChevronRight()
                        }
                    }
                }
                .buttonStyle(PlainPressStyle())
            }
        }
        .padding(.top, 24)
        .modifier(SignOutFooter())
    }
}

/// The sign-out / reset pair, kept out of the settings card so it reads as an exit.
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
                    Text("Points, streak, history and every evidence photo on this device are deleted. Onboarding runs again from scratch.")
                }
        }
    }
}

enum ProfileRoute: Hashable {
    case favourites, notifications, privacy, history
}

// MARK: - Small pieces

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

struct EvidenceThumbnail: View {
    let photo: EvidencePhoto
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Theme.C.neutral200)
                ProgressView().tint(Theme.C.neutral500)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            if let category = photo.category {
                CategoryIconView(glyph: category.glyph, size: 12, color: .white)
                    .padding(5)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .padding(6)
            }
        }
        .task {
            guard image == nil else { return }
            let loaded = await Task.detached { PhotoStore.load(photo) }.value
            image = loaded
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

private struct EvidenceViewer: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let photo: EvidencePhoto
    @State private var image: UIImage?
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                } else {
                    ProgressView().tint(.white)
                }

                VStack(spacing: 4) {
                    if let activity = MockData.activitiesById[photo.activityId] {
                        Text(activity.name)
                            .font(Theme.F.body(15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(photo.capturedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        confirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(Theme.F.body(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Close")
                            .font(Theme.F.body(13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            image = await Task.detached { PhotoStore.load(photo) }.value
        }
        .alert("Delete this photo?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                app.deleteEvidence(photo)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo is removed from this device. The points it earned stay yours.")
        }
    }
}
