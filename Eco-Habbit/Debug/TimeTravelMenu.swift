import SwiftUI

// DEBUG-only. This fakes time and grants host verification; it must never ship.
#if DEBUG

/// Validates decay, streaks and the monthly quotas without waiting real days.
///
/// Time travel works because `DecayService` is applied by `bootstrap(now:)` and
/// takes its reference date as a parameter — there is no background job to
/// out-manoeuvre. Passing a future date is exactly what happens when a user
/// leaves the app closed for a week.
struct TimeTravelMenu: View {
    @EnvironmentObject private var app: AppState
    @State private var targetDate = Date()

    /// No `NavigationStack` — this screen is pushed into the one Profile owns,
    /// and nesting a second stack renders blank and pops straight back out.
    var body: some View {
        Form {
            Section("Re-open the app as if it were…") {
                DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                Button("Bootstrap as of this date") {
                    Task { await app.bootstrap(now: targetDate) }
                }
                Text("Runs the real decay pass with this date as \"now\". Grace is \(app.config.decayGracePeriodDays) days, then \(Int(app.config.decayRatePerDay * 100))% a day, floored at \(app.config.decayPointsFloor) points.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current state") {
                LabeledContent("Points", value: "\(app.currentPoints)")
                LabeledContent("Stage", value: app.earthStage.displayName)
                LabeledContent("To next stage", value: app.pointsToNextStage.map(String.init) ?? "max")
                LabeledContent("Streak (stored)", value: "\(app.userState.currentStreak)")
                LabeledContent("Streak (displayed)", value: "\(app.displayStreak())")
                LabeledContent("Freeze available", value: app.userState.isStreakFreezeAvailable() ? "yes" : "no")
                LabeledContent("Logged today", value: "\(app.completedTodayIDs.count)")
                LabeledContent("Logs, all time", value: "\(app.history.count)")
                LabeledContent("Badges", value: "\(app.unlockedBadgeCount) / \(app.badges.count)")
            }

            Section("Monthly event quota") {
                LabeledContent("Used", value: "\(app.userState.effectiveMonthlyEventPoints()) / \(app.config.monthlyEventPointsCap)")
                LabeledContent("Attended", value: "\(app.userState.attendedEventIDs.count)")
            }

            if let decay = app.lastDecay, decay.didDecay {
                Section("Last decay") {
                    LabeledContent("Points lost", value: "\(decay.pointsBefore - decay.pointsAfter)")
                    LabeledContent("Hit points floor", value: decay.limitedByPointsFloor ? "yes" : "no")
                    LabeledContent("Hit stage floor", value: decay.limitedByStageFloor ? "yes" : "no")
                }
            }

            Section {
                Toggle("Verified organisation", isOn: Binding(
                    get: { app.isOrganization },
                    set: { on in Task { await app.setOrganization(on) } }
                ))
                if app.isOrganization {
                    LabeledContent("Hosting", value: "\(app.hostedFights.count) events")
                }
            } header: {
                Text("Host mode")
            } footer: {
                Text("PRD §4.3: verification is a person flipping a flag. This is the flag. It lives here rather than in Settings because it must never be user-writable.")
            }
        }
        .navigationTitle("Time Travel")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
