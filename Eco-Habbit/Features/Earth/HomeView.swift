import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingStageInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                globe
                dailyProgress
                nextFight
                suggestions
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

    /// PRD §6.1 — shown only when signed up for something upcoming.
    @ViewBuilder
    private var nextFight: some View {
        if let fight = app.nextFight {
            Button {
                app.selectedTab = .ourFights
            } label: {
                EHCard(background: AnyShapeStyle(Theme.C.accent2_100)) {
                    HStack(spacing: Theme.S.x3) {
                        Image(systemName: fight.type.symbol)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.C.accent2_700)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.6)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fight.isCheckInOpen() ? "CHECK-IN OPEN" : "YOUR NEXT FIGHT")
                                .font(Theme.F.body(10.5, weight: .bold))
                                .foregroundStyle(Theme.C.accent2_700)
                            Text(fight.title)
                                .font(Theme.F.body(14.5, weight: .bold))
                                .foregroundStyle(Theme.C.text)
                                .lineLimit(1)
                            Text(FightFormat.countdown(fight))
                                .font(Theme.F.body(12.5))
                                .foregroundStyle(Theme.C.neutral700)
                        }

                        Spacer()
                        ChevronRight()
                    }
                }
            }
            .buttonStyle(PlainPressStyle())
            .padding(.top, 16)
        }
    }

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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

    private var dailyProgress: some View {
        EHCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(Theme.F.body(14, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Spacer()
                    Text("\(app.dailyPoints) / \(PointsEngine.dailyTarget) pts")
                        .font(Theme.F.body(13))
                        .foregroundStyle(Theme.C.neutral600)
                }
                EHProgressBar(value: app.dailyProgress)
            }
        }
        .padding(.top, 22)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(text: "Suggested today")

            if app.suggestedHabits.isEmpty {
                EHCard(padding: 16) {
                    Text("Everything on today's list is done. See you tomorrow.")
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral700)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(app.suggestedHabits) { habit in
                            MissionCard(habit: habit)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.top, 24)
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

    private static var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 0..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

private struct MissionCard: View {
    @EnvironmentObject private var app: AppState
    let habit: Habit

    var body: some View {
        Button {
            app.logAndToast(habit, source: .checklist)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
//                CategoryIconView(glyph: habit.category.icon, size: 22, color: Theme.C.accent600)

                Text(habit.name)
                    .font(Theme.F.body(13.5, weight: .bold))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack {
                    EHTag(text: "+\(habit.basePoints) pts", style: .accent)
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

private struct EarthStageSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Earth")
                    .font(Theme.F.heading(26))
                    .foregroundStyle(Theme.C.text)

                Text("Log daily habits to earn points and heal the globe. Reach 30 points in a day for a Vitality boost.")
                    .font(Theme.F.body(14))
                    .foregroundStyle(Theme.C.neutral700)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    ForEach(VitalityStage.allCases) { stage in
                        let reached = app.vitality >= stage.range.lowerBound
                        HStack(spacing: 12) {
                            Circle()
                                .fill(reached ? Theme.C.accent2_500 : Theme.C.neutral300)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stage \(stage.rawValue + 1) · \(stage.name)")
                                    .font(Theme.F.body(14.5, weight: .bold))
                                    .foregroundStyle(reached ? Theme.C.text : Theme.C.neutral600)
                                Text(stage.blurb)
                                    .font(Theme.F.body(12.5))
                                    .foregroundStyle(Theme.C.neutral600)
                            }

                            Spacer()

                            Text("\(stage.range.lowerBound)")
                                .font(Theme.F.body(13, weight: .semibold))
                                .foregroundStyle(Theme.C.neutral600)
                        }
                        .padding(.vertical, 8)

                        if stage != .flourishing {
                            Rectangle().fill(Theme.C.neutral200).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 20)

                Button("Close") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 24)
            }
            .padding(24)
        }
        .background(Theme.C.bg)
    }
}

#if DEBUG
#Preview {
    MainTabView().environmentObject(AppState.preview)
}
#endif
