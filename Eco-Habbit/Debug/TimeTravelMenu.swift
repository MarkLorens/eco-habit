import SwiftUI

// **Ships in Release, behind `TeamAccess`.** It used to be `#if DEBUG`, which put it
// out of reach in TestFlight — and TestFlight is where it is needed most: the people
// running a demo phone at the exhibition are the ones who cannot rebuild it themselves.
//
// A password is a weaker gate than the compiler, so what is behind it matters. Nothing
// here reaches another account: time travel and the resets act on this device's own
// state, and "Verified organization" is a local override the security rules ignore, so
// it unlocks the host screens without granting any host permission.

/// PRD §13 Phase 2 — validate the evaluation loop against missed days, timezone
/// rollover, Shield and streak breaks without waiting real calendar days.
struct TimeTravelMenu: View {
    @EnvironmentObject private var app: AppState
    @State private var targetDate = Date()
    @State private var resetting = false
    @State private var confirmingReset = false

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

            // First section on purpose. "Signed in but nothing saves" is invisible
            // otherwise — every Firestore call swallows its error so that a sync
            // problem can never interrupt logging.
            Section("Firebase") {
                LabeledContent("Sync", value: app.syncStatus.label)
                LabeledContent("Account", value: app.userId ?? "signed out")
                if let detail = app.syncStatus.detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                Button("Retry sync") { app.retrySyncIfNeeded() }
            }

            Section("Exhibition") {
                Button("Reset account data", role: .destructive) { resetting = true }
                Text("Back to a new visitor: points, streak, badges, history, photos, onboarding and check-ins, cleared on this device and on the server. Fights this account HOSTS are kept, and so is its name — other phones are reading those.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Evidence photos") {
                NavigationLink {
                    EvidenceBrowserView()
                } label: {
                    LabeledContent("Saved photos", value: "\(app.savedEvidence.count)")
                }
                LabeledContent("On disk", value: ByteCountFormatter.string(
                    fromByteCount: Int64(app.savedEvidenceBytes), countStyle: .file))
                Text("Kept on this device only, named after the log they belong to ({habitId}_{date}). Not uploaded — that decision has a billing plan attached.")
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
                Toggle("Verified organization", isOn: Binding(
                    get: { app.isOrganization },
                    set: { app.debugSetOrganization($0) }
                ))
                // The two sources, separately, because "I set it and nothing happened"
                // is impossible to diagnose when they are collapsed into one row.
                LabeledContent("Server says", value: app.data.isOrganization ? "yes" : "no")
                LabeledContent("Host screens", value: app.isOrganization ? "shown" : "hidden")
                if app.isOrganization {
                    LabeledContent("Hosting", value: "\(app.hostedFights.count) events")
                }
            } header: {
                Text("Host mode")
            } footer: {
                Text("PRD §4.3: verification is a person flipping a flag. This is the flag. It lives here rather than in Settings because it must never be user-writable.\n\nThe toggle is LOCAL — it unlocks the host screens and survives relaunch, but the security rules read \"Server says\", so publishing a Fight needs isOrganization set to true on /users/{uid} in the Firebase console, then a relaunch.")
            }

            // Last on purpose. It came off the avatar's long-press menu, where it sat one
            // tap away from "Delete account" — the bottom of a debug screen is far enough
            // from anything reached by accident.
            Section {
                Button("Reset local data", role: .destructive) { confirmingReset = true }
            } footer: {
                Text("This device only — the server copy is untouched, so signing in again pulls it all back. \"Reset account data\" above is the one that clears both.")
            }
        }
        .navigationTitle("Time Travel")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset this account?", isPresented: $resetting) {
            Button("Reset", role: .destructive) { Task { await app.debugResetAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears everything this account earned, here and on the server. Fights it hosts are not touched. This cannot be undone.")
        }
        .alert("Reset local data?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { app.resetEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Points, streak, history and settings on this device are deleted. The Earth starts over from the beginning.")
        }
    }

    private func advance() {
        app.debugEvaluate(asOf: Day.today(targetDate))
    }
}
