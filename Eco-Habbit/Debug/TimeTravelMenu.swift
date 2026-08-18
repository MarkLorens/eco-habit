import SwiftUI

// The whole file is DEBUG-only. It calls `debugEvaluate` and
// `debugSetOrganization`, which do not exist in Release — and it should not
// ship regardless: this is the surface that fakes time and grants host
// verification.
#if DEBUG

/// PRD §13 Phase 2 — validate the evaluation loop against missed days, timezone
/// rollover, Shield and streak breaks without waiting real calendar days.
struct TimeTravelMenu: View {
    @EnvironmentObject private var app: AppState
    @State private var targetDate = Date()

    /// No `NavigationStack` here. This screen is *pushed* into the one Profile
    /// already owns, and nesting a second stack inside a `navigationDestination`
    /// renders blank and pops straight back out.
    var body: some View {
        Form {
            Section("Advance evaluation date") {
                DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                Button("Advance to date") { advance() }
                Text("Runs the real loop with this date as \"today\". Days before it are scored; the target day itself is not.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current state") {
                LabeledContent("Last scored", value: app.data.lastEvaluatedDate ?? "never")
                LabeledContent("Vitality", value: "\(app.vitality) · \(app.stage.name)")
                LabeledContent("Settled streak", value: "\(app.data.streakDays)")
                LabeledContent("Displayed streak", value: "\(app.displayStreak)")
                LabeledContent("Today's points", value: "\(app.dailyPoints) / \(PointsEngine.dailyTarget)")
                LabeledContent("Shields", value: "\(app.shieldsAvailable)")
                LabeledContent("Shielded today", value: app.isTodayShielded ? "yes" : "no")
                LabeledContent("Logs", value: "\(app.data.logs.count)")
            }

            Section("Shield") {
                Button("Shield today") { app.activateShield() }
                    .disabled(app.shieldsAvailable == 0 || app.isTodayShielded)
            }

            Section {
                Toggle("Verified organisation", isOn: Binding(
                    get: { app.isOrganization },
                    set: { app.debugSetOrganization($0) }
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

    private func advance() {
        app.debugEvaluate(asOf: Day.today(targetDate))
    }
}
#endif
