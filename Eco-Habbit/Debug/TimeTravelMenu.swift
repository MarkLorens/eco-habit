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
    @State private var draftStreak = 0

    /// The tier boundaries from `PointsConfiguration`, not a hand-typed list —
    /// retuning the tiers retunes these buttons with them.
    private var tierDays: [Int] {
        ([0] + app.config.streakTiers.map(\.minimumStreakDay)).sorted()
    }

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

            Section {
                Stepper(value: $draftStreak, in: 0...500) {
                    LabeledContent("Set streak", value: "\(draftStreak) days")
                }

                // Jump straight to a boundary — the interesting values are the
                // tier edges, and stepping to 60 one tap at a time is nobody's
                // idea of a debug tool.
                HStack(spacing: 6) {
                    ForEach(tierDays, id: \.self) { day in
                        Button("\(day)") { draftStreak = day }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.footnote)

                LabeledContent(
                    "Multiplier at \(draftStreak)",
                    value: "×\(app.config.streakMultiplier(forStreak: draftStreak).formatted(.number.precision(.fractionLength(0...2))))"
                )

                Button("Apply") {
                    Task { await app.debugSetStreak(draftStreak) }
                }
            } header: {
                Text("Streak")
            } footer: {
                Text("Also stamps the last-activity date to now — the streak on screen is derived from that date, so the counter alone would keep displaying 0. Tiers: \(app.config.streakTiers.map { "day \($0.minimumStreakDay) ×\($0.multiplier.formatted(.number.precision(.fractionLength(0...2))))" }.joined(separator: ", ")).")
            }

            Section("Current state") {
                LabeledContent("Points", value: "\(app.currentPoints)")
                LabeledContent("Stage", value: app.earthStage.displayName)
                LabeledContent("To next stage", value: app.pointsToNextStage.map(String.init) ?? "max")
                LabeledContent("Streak (stored)", value: "\(app.userState.currentStreak)")
                LabeledContent("Streak (displayed)", value: "\(app.displayStreak())")
                // What the actions list actually prices with — the streak the
                // NEXT log will reach, which is one ahead on a fresh day.
                LabeledContent("Streak (next log)", value: "\(app.prospectiveStreak())")
                LabeledContent("Multiplier in force",
                               value: "×\(app.streakMultiplier().formatted(.number.precision(.fractionLength(0...2))))")
                LabeledContent("Freeze available", value: app.userState.isStreakFreezeAvailable() ? "yes" : "no")
                LabeledContent("Logged today", value: "\(app.completedTodayIDs.count)")
                LabeledContent("Logs, all time", value: "\(app.history.count)")
                LabeledContent("Badges", value: "\(app.unlockedBadgeCount) / \(app.badges.count)")
            }

            Section {
                ForEach(app.allFights) { fight in
                    LabeledContent {
                        Text(fight.isCheckInOpen() ? "open" : "closed")
                            .foregroundStyle(fight.isCheckInOpen() ? .green : .secondary)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fight.title).lineLimit(1)
                            Text("\(fight.checkInCode) · \(FightFormat.countdown(fight))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Fights — check-in codes")
            } footer: {
                Text("Only a Fight with an open window can be checked into. The seeded set deliberately keeps exactly one open at any time, so scanning any other code is refused — which looks like a broken scanner until you can see this list.")
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
        .onAppear { draftStreak = app.userState.currentStreak }
    }
}
#endif
