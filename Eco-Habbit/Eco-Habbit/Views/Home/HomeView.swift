import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingStageInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if app.showsInactivityWarning {
                    InactivityBanner(days: app.daysSinceLastAction)
                        .padding(.top, 18)
                }

                globe
                weeklyProgress
                suggestions
                regionalMission
                logButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Theme.C.bg)
        .sheet(isPresented: $showingStageInfo) {
            EarthStageSheet()
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Self.greeting), \(app.firstName)")
                .font(Theme.F.heading(21))
                .foregroundStyle(Theme.C.text)

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.C.accent500)

                Text(app.streakDays == 0 ? "No streak yet" : "\(app.streakDays)-day streak")
                    .font(Theme.F.body(13.5, weight: .semibold))
                    .foregroundStyle(Theme.C.neutral700)

                if app.streakMultiplier > 1 {
                    EHTag(text: "×\(PointsEngine.multiplierLabel(app.streakMultiplier)) pts", style: .accent2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Globe

    private var globe: some View {
        VStack(spacing: 10) {
            GlobeView(health: app.globeHealth, size: 210)

            Button {
                showingStageInfo = true
            } label: {
                HStack(spacing: 6) {
                    Text("\(app.stage.name) · \(Int(app.globeHealth))% — drag to explore")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.C.neutral500)
                }
            }
            .buttonStyle(PlainPressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    // MARK: Weekly progress

    private var weeklyProgress: some View {
        EHCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("This week")
                        .font(Theme.F.body(14, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Spacer()
                    Text("\(app.pointsThisWeek) / \(AppState.weeklyGoal) pts")
                        .font(Theme.F.body(13))
                        .foregroundStyle(Theme.C.neutral600)
                }
                EHProgressBar(value: app.weeklyProgress)
            }
        }
        .padding(.top, 22)
    }

    // MARK: Suggested missions

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Suggested missions")

            if app.suggestedMissions.isEmpty {
                EHCard(padding: 16) {
                    Text("Everything on today's list is done. That's a full sweep — see you tomorrow.")
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral700)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(app.suggestedMissions) { activity in
                            MissionCard(activity: activity)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.top, 24)
    }

    // MARK: Regional mission

    @ViewBuilder
    private var regionalMission: some View {
        if let mission = app.activeRegionalMission {
            RegionalMissionBanner(mission: mission)
                .padding(.top, 20)
        }
    }

    private var logButton: some View {
        Button {
            app.isCameraPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                Text("Log an action")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.top, 20)
    }

    // MARK: Helpers

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

// MARK: - Mission card

private struct MissionCard: View {
    @EnvironmentObject private var app: AppState
    let activity: Activity

    var body: some View {
        Button {
            switch app.logActivity(activity, source: .checklist) {
            case .awarded(let award):
                app.toast = Toast(kind: .success, message: "\(award.activity.name) · +\(award.points) pts")
            case .alreadyDoneToday:
                app.toast = Toast(kind: .info, message: "Already logged today.")
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                CategoryIconView(glyph: activity.category.glyph, size: 22, color: Theme.C.accent600)

                Text(activity.name)
                    .font(Theme.F.body(13.5, weight: .bold))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    EHTag(
                        text: "+\(PointsEngine.preview(basePoints: activity.basePoints, streakDays: app.streakDays)) pts",
                        style: .accent
                    )
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.C.accent500)
                }
            }
            .padding(14)
            .frame(width: 158, height: 148, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Theme.R.card).fill(Theme.C.surface))
            .elevation(Theme.E.sm)
        }
        .buttonStyle(PlainPressStyle())
    }
}

// MARK: - Regional mission banner

private struct RegionalMissionBanner: View {
    @EnvironmentObject private var app: AppState
    let mission: RegionalMission

    var body: some View {
        EHCard(
            padding: 16,
            background: AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.C.accent2_200, Theme.C.accent100],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("REGIONAL MISSION · \(mission.region.uppercased())")
                    .font(Theme.F.body(10, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.C.accent700)

                Text(mission.title)
                    .font(Theme.F.heading(17))
                    .foregroundStyle(Theme.C.text)

                Text("\(mission.date.formatted(.dateTime.weekday(.abbreviated).month().day())) · \(mission.locationName)")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral700)

                HStack(spacing: 10) {
                    if app.hasJoined(mission) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("You're going")
                        }
                        .font(Theme.F.body(13, weight: .bold))
                        .foregroundStyle(Theme.C.accent2_700)
                        .padding(.top, 4)
                    } else {
                        Button("Join") { app.join(mission) }
                            .buttonStyle(SecondaryButtonStyle(height: 38, fontSize: 14, expands: false))
                            .padding(.top, 4)
                    }
                    Spacer()
                    EHTag(text: "+\(mission.points) pts", style: .outline)
                }
            }
        }
        .washed()
    }
}

// MARK: - Inactivity warning

private struct InactivityBanner: View {
    let days: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.C.accent600)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(days) days without an action")
                    .font(Theme.F.body(14, weight: .bold))
                    .foregroundStyle(Theme.C.text)
                Text("Your Earth starts losing points after a full inactive week. One small action resets it.")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.R.lg)
                .fill(Theme.C.accent100)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.R.lg)
                        .stroke(Theme.C.accent300, lineWidth: 1)
                )
        )
    }
}

// MARK: - Earth stage explainer

private struct EarthStageSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Earth")
                    .font(Theme.F.heading(26))
                    .foregroundStyle(Theme.C.text)

                Text("Earth Points heal the globe. They're never spendable — that's what Reward Points are for.")
                    .font(Theme.F.body(14))
                    .foregroundStyle(Theme.C.neutral700)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(EarthStage.allCases) { stage in
                        let reached = app.earthPoints >= stage.threshold
                        HStack(spacing: 12) {
                            Circle()
                                .fill(reached ? Theme.C.accent2_500 : Theme.C.neutral300)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stage \(stage.rawValue) · \(stage.name)")
                                    .font(Theme.F.body(14.5, weight: .bold))
                                    .foregroundStyle(reached ? Theme.C.text : Theme.C.neutral600)
                                Text(stage.blurb)
                                    .font(Theme.F.body(12.5))
                                    .foregroundStyle(Theme.C.neutral600)
                            }

                            Spacer()

                            Text("\(stage.threshold)")
                                .font(Theme.F.body(13, weight: .semibold))
                                .foregroundStyle(Theme.C.neutral600)
                        }
                        .padding(.vertical, 8)

                        if stage != .thriving {
                            Rectangle().fill(Theme.C.neutral200).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 20)

                if let next = app.stage.next {
                    EHCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(next.threshold - app.earthPoints) pts to \(next.name)")
                                .font(Theme.F.body(14, weight: .bold))
                                .foregroundStyle(Theme.C.text)
                            EHProgressBar(value: app.stageProgress, tint: Theme.C.accent2_500)
                        }
                    }
                    .padding(.top, 20)
                }

                Button("Close") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 24)
            }
            .padding(24)
        }
        .background(Theme.C.bg)
    }
}

// `AppState.preview` is DEBUG-only, and this project keeps ENABLE_PREVIEWS on for Release.
#if DEBUG
#Preview {
    MainTabView().environmentObject(AppState.preview)
}
#endif
