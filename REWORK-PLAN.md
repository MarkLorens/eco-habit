# Rework Plan — prototype → PRD 0.6

**Status:** Phases 0–2, 4–7 complete. Build green, 85 tests passing.
**Active phase:** 8 — Local notifications.
**Scope:** reconcile the prototype with the PRD, and hold the file layout the team builds on.

> **Firebase is deferred to Phase 10.** Every feature is built and proven on-device against bundled JSON first. The Firestore schema is a serialisation of the local model, so designing it while the model is still moving means migrating Firestore each time a feature teaches us something. PRD §13 amended in 0.6.

| Phase | Deliverable | State |
|---|---|---|
| 0 | Teardown and scaffold | ✅ done |
| 1 | Vertical slice, fully local | ✅ done |
| 2 | Evaluation loop + time travel + tests | ✅ done |
| 3 | Earth visualisation and stage transitions | ⛔ **blocked on art direction** (PRD §12 Q1) |
| 4 | ML model | ✅ done — **zero-shot, no photos needed** |
| 5 | Camera visual search | ✅ done |
| 6 | Fights: browse, detail, signup, QR — local seeded event | ✅ done |
| 7 | Host mode: create/manage, scanner, attendance | ✅ done |
| **8** | **Local notifications** | **▶ next** |
| 9 | Badges, badge wall, share export | not started |
| 10 | **Firebase**: Auth, Firestore mirror, Rules + emulator tests | not started |
| 11 | Offline hardening, polish, demo seeding | not started |

**Phase 3 is the only thing left that isn't code.** The Earth art pipeline (layered PNG vs. SpriteKit vs. image sequence) is PRD §12's first blocking open question and needs a designer.

**The photo shoot is cancelled.** Phases 4–5 landed as zero-shot CLIP: habits are described in words, not learned from examples, so the ~300 training photographs the plan called the longest calendar item in the project are not needed at all. PRD §12 Q3 is closed.

**Phase 10 is the exhibit-readiness gate, not Phase 11.** Check-in is a cross-user write and cannot be genuinely tested before Firebase exists. The §12.1 demo needs two devices talking to each other, so Firebase must land with runway to spare.

---

## 1. What shipped

### Phase 0 — Teardown ✅

Vouchers, evidence photos, the second currency, and streak multipliers are gone (~1,100 lines). `git grep -i "voucher\|evidence\|rewardPoints\|streakMultiplier"` returns nothing — the exit test passes. Folder layout matches §2.4. `xcuserdata` untracked, one `.gitignore`, bundle ID `com.greenapple.ecohabit`, branches reconciled to `main`, deployment target 18.0.

`GoogleService-Info.plist` is deliberately **not** ignored — PRD §9.6 says the Firebase client config is public by design, and ignoring it just breaks every teammate's first clone.

### Phase 1 — Vertical slice ✅

- `Resources/habits.json` — 50 habits, correct 6-category split (10/8/8/8/8/8), 43 recurring + 7 Foundations, all 16 weekly caps matching their PRD §3.6 rows.
- `PointsEngine` — tiers 5/10/20, 30-point target, **60-point cap enforced** in `dailyTotal`, Foundations excluded, duplicates counted once.
- `VitalityEngine` — the full §2.2 delta table and **five** stage bands (5–20 / 21–40 / 41–60 / 61–85 / 86–100).
- `HabitRepository` — the only writer of a `HabitLog`. Once-per-day, weekly caps per **ISO** week, Foundations once-ever, no retroactive logging, same-day undo.
- `Day.swift` — `YYYY-MM-DD` arithmetic in UTC, with the device timezone read in exactly one place (`Day.today()`).

### Phase 2 — Evaluation loop ✅

- One `EvaluationLoop.evaluate()`. **`lastEvaluatedDate` is the last day *scored*** — a new account arms at yesterday, and today is never scored because today isn't over. Getting this invariant backwards is total: it marks each day evaluated before scoring it, so every day is skipped and Vitality never moves.
- Streak advances on **points ≥ 30**, not on any activity. Displayed as `settled + (today hit target ? 1 : 0)`.
- Shields: 2/month, ceiling 3, max 3 consecutive — the consecutive run is **derived** from `shieldedDates`, because a stored counter drifts the moment a Shield is used non-consecutively.
- 7-day +5 bonus, Fight +10, Shield-zeroes-the-day, in that precedence order.
- `Debug/TimeTravelMenu` drives the real loop.
- **Test target added** (it did not exist — the test files were outside the project and had never compiled). 47 tests, all passing.

### Deviations from the original plan, and why

| Planned | Shipped | Why |
|---|---|---|
| SwiftData models | `PersistedState` `Codable` blob, unchanged from the prototype | Works, and deferring Firebase settled it — see §4.1 |
| `Activity` → `Habit` rename | Done, plus `Activity.swift` split into `Habit` / `Badge` / `Day` / `UIState` | The old file held seven unrelated types and an `import SwiftUI` on its last line |
| 3 test files | 4 — `HabitRepositoryTests` added | The write rules (caps, retroactive, undo) are logic and needed covering |
| `HistoryEntry` persisted | Derived from `logs` | §9.7 forbids storing what can be computed; storing it caused a revert-by-title bug that deleted past days' entries |

---

## 2. Architecture — the living reference

This section is the standing convention, not a one-off task. It does not expire when a phase does.

### 2.1 One file per screen or per type

Not one file per feature, and not one file per function. A view over ~300 lines is a signal to extract subviews, not a rule. Extract when a piece is *reused* or *separately owned* — private helpers used by exactly one screen stay in that screen's file.

### 2.2 Files are free here

`objectVersion = 77` with a `PBXFileSystemSynchronizedRootGroup` means **adding, renaming, moving, or deleting a Swift file does not modify `project.pbxproj`.** The folder on disk *is* the group. Historically that file was the worst merge conflict in iOS teamwork; it is already solved here. Create files on disk — do not drag them into the Xcode navigator the old way.

Adding a *target* still edits `project.pbxproj` (that is why the test target needed a hand-written patch), but that happens roughly never.

### 2.3 Three layers, no god object

| Layer | Rule |
|---|---|
| **Engines** — `PointsEngine`, `VitalityEngine`, `EvaluationLoop` | Pure functions over values. Never import SwiftUI. No I/O. The only code that needs unit tests. |
| **Repositories** — `HabitRepository`, `UserRepository`, `FightRepository` | The only code that reads or writes storage. Every write goes through one (§9.7). |
| **`AppState` / feature view models** | Coordinators. They call repositories; they never touch `state.logs` themselves. |

Enforced by review, and checkable:

```bash
git grep -n '\$0\.logs\|state\.logs\.append\|\.vitality +=' -- Eco-Habbit/App Eco-Habbit/Features   # must be empty
```

### 2.4 Layout

```
Eco-Habbit/
├── App/                  Eco_HabbitApp · RootView · MainTabView · AppState · UIState
├── Core/
│   ├── Models/           Habit · Badge · Day · HabitCategory · Fight · FightSeed · MockData
│   ├── Engine/           PointsEngine · VitalityEngine · EvaluationLoop
│   ├── ML/               HabitClassifier
│   ├── Repositories/     HabitRepository · UserRepository · FightRepository   (+ AuthRepository)
│   └── Persistence/      PersistenceStore                        (+ FirestoreSync)
├── DesignSystem/         Theme · Tokens · Components · Cards · GlobeView · CategoryIconView · FontLoader
├── Features/
│   ├── Auth/             — SignInWithAppleView, Phase 10
│   ├── Earth/            HomeView
│   ├── Habits/           ActivityListView · CategoryDetailView
│   ├── Camera/           VisualSearchView · CameraService
│   ├── Fights/           FightListView · FightDetailView · CheckInQRView
│   │   └── Host/         EventFormView · ManageEventView · ScannerView
│   └── Profile/          ProfileView · SettingsViews
├── Resources/            habits.json · fights.json · habit_vectors.json
│                         mobileclip_s2_image.mlpackage · Fonts/
ml/                       generate_vectors.py · test_vectors.py   (not bundled)
└── Debug/                TimeTravelMenu

Eco-HabbitTests/          VitalityEngine · PointsEngine · HabitRepository · EvaluationLoop · FightRepository
```

Features are **vertical slices** — a feature folder holds its own views and view model together. Organising by layer instead means every feature's work spreads across four folders and every folder has four editors.

### 2.5 No local Swift packages

One target, folder conventions. Package boundaries buy compile-time enforcement in exchange for manifests, `public` on every cross-module symbol, slower incremental builds, and periodic resolution failures. At this team size, folders plus review get the same boundaries for free. Revisit past ~6 people.

### 2.6 Ownership — **still unassigned**

| Area | Owner |
|---|---|
| `Core/` — models, engines, repositories | _fill in_ |
| `DesignSystem/` | _fill in_ |
| `Features/Earth/` + `Features/Habits/` | _fill in_ |
| `Features/Camera/` | _fill in_ |
| `Features/Fights/` + `Host/` | _fill in_ |
| `Resources/habits.json` (content) | _fill in_ |

Three files everyone eventually touches — `MainTabView`, `Theme`, `habits.json` — keep boring, and announce edits.

### 2.7 Branching

`main` protected, short-lived `feature/<area>-<thing>` branches, PR + one review, rebase over merge.

---

## 3. Phase 6 — Fights, local ✅

**Goal:** the whole Fight loop working on one phone against a bundled seed — browse, detail, sign up, cancel, show a check-in QR, and have attendance move Vitality by +10. No network.

### 3.1 Shipped

1. ✅ **`Fight` model + `FightType`** (PRD §4.2 — eight types, their own taxonomy, deliberately not mapped to habit categories).
2. ✅ **`Resources/fights.json`** — the fictional Bali organisations from §8, with events in the near future, clearly labelled demo data. Same reasoning as `habits.json`: content is data, not a Swift array.
3. ✅ **`FightRepository`** — sign up, cancel, generate the per-`(user, event)` check-in token, record attendance. The only writer of a signup or an attendance record.
4. ✅ **Wire attendance into Vitality.** The hook already exists: `PersistedState.fightAttendedDates` is read by `EvaluationLoop` and the +10 branch is already tested. Attendance writes a date; the loop does the rest.
5. ✅ **UI** — Fights tab: chronological browse with type filter, detail with Join/Cancel, My Fights (Upcoming / Past), and the full-screen QR with boosted brightness.
6. ✅ **Tests** — 16 of them: signup/cancel idempotency, the check-in window (−1h / +3h), one check-in per attendee per event, and that a Fight day's delta replaces rather than stacks.

Two decisions worth knowing about:

- **Seed events are stored as offsets from launch, not absolute dates.** Absolute dates go stale — a week after writing them the whole list is in the past and the demo shows an empty screen. `f1` is offset −1h / 10h long, so there is *always* one Fight with an open check-in window. A test asserts this, because §12.1's booth demo dead-ends without it.
- **Check-in never touches Vitality directly.** It records a date; `EvaluationLoop` applies the +10 when it scores that day. That is the same split §9.3 uses for Firestore — the attendance record is the truth, Vitality is derived from it — so Phase 10 changes where the record lives, not what the number means.

**What cannot be proven yet:** the scan is same-device simulated ("Simulate host scan" in the detail view). Check-in is a cross-user write (§9.3) and only becomes real in Phase 10. The *flow* is exercised; the *security model* is not.

### 3.2 Deferred: the Firestore schema mapping (Phase 10)

Recorded now because the local model is being shaped to serialise cleanly into it later.

`PersistedState` serialises to §9.12 nearly one-to-one:

```
/users/{uid}                    ← everything in PersistedState except `logs`
    displayName, createdAt, timezone, isOrganization,
    vitality, shieldsAvailable, shieldedDates, lastShieldGrantMonth,
    currentStreak, longestStreak, lastEvaluatedDate, lastActiveDay

/users/{uid}/habitLogs/{habitId}_{localDate}     ← one document per log
    habitId, loggedAt, localDate, source

/habits/{habitId}               ← seeded from Resources/habits.json, client-read-only
```

**Key the log document ID on `{habitId}_{localDate}`.** The composite ID makes once-per-day a *structural* guarantee the rules enforce for free — a duplicate is a write to an existing document, which rules reject. Same trick §9.3 uses for `/attendance`. It removes the need to trust the client's own dedup check.

`habitLogs` is authoritative. Daily totals stay a sum over `localDate`; nothing summable is cached (§9.7). Vitality remains client-authoritative and documented as such (§9.6).

### 3.3 Deferred: Security Rules (Phase 10)

Rules run on Google's servers, not on the device. A modified client cannot bypass them any more than it could bypass a REST API we wrote. This file deserves more care than configuration usually gets.

Must hold before launch:
- Users read and write only their own documents.
- `habitLogs` immutable after creation; deletion permitted **same-day only**.
- `isOrganization` is **not** user-writable under any circumstances.
- `/habits` is client-read-only.
- Event documents creatable only by `isOrganization == true` accounts, editable only by the owning host.
- Attendance: host-only creation, no self-check-in, event ownership verified, immutable after write.
- **Firebase Storage is not enabled.** No rules surface, no photo access to secure.

**Rules must have tests** — `@firebase/rules-unit-testing` against the emulator. A rules bug fails *silently*: no exception, no log, just a permission that shouldn't exist. That makes it more dangerous than a server bug, which at least throws.

These are JavaScript, run under the emulator, and live outside the Xcode project:

```
firebase/
├── firestore.rules
├── firestore.indexes.json
└── tests/            @firebase/rules-unit-testing specs
```

### 3.4 Phase 6 exit test ✅

Browse the seeded list, open a Fight, join it, see it in My Fights with a QR, simulate the scan, and watch Vitality jump +10 for that day — then force-quit, reopen, and find it all still there.

*(The Phase 10 exit test, for later: Sign in with Apple on two simulators against the same account, a habit logged on one appears on the other, and the rules suite passes its negative cases — writing another user's log, writing `isOrganization`, editing `/habits`, deleting a previous day's log.)*

---

## 4. Decisions needed now

### 4.1 SwiftData — settled by the deferral ✅

Deferring Firebase resolves this. The `Codable` blob stays through Phase 9; PRD §9.10 amended in 0.6.

Revisit at Phase 10 only if someone can name a query the blob can't serve. The standing argument against adopting it: Firestore's offline persistence *is* the sync queue (§9.11), so SwiftData would make a third copy of the same data — SwiftData, the Firestore cache, and the server — two of which need reconciliation logic nobody has written.

### 4.2 Still open

| # | Question | Recommendation |
|---|---|---|
| 1 | **Habit content** — `impactStatement` / `impactSource` empty for all 50. §3.5 makes the citation **mandatory** | Assign a non-developer owner this week. Most likely thing to be unfinished at exhibit. |
| 2 | Folder ownership (§2.6) — all six | Assign before Phase 3 merges |
| 3 | Product name — keep `Eco-Habbit` (typo) or rename to `Terra` | Rename now if ever. Cost rises every phase. |
| 4 | 7-day bonus: recurring every 7th day, or once ever? | Shipped as recurring; `ponytail:` comment in `VitalityEngine` marks the one-line flip |
| 5 | Admin dashboard, or just the Firebase console for the exhibit (§8) | Console. Verification is one boolean. |

---

## 5. Tests

85 passing, 8 files. `xcodebuild -scheme Eco-Habbit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

| Suite | Guards |
|---|---|
| `VitalityEngineTests` | The §2.2 delta table incl. Shield/Fight/7-day precedence; the [5,100] clamp; all five stage bands tile the range with no gap |
| `PointsEngineTests` | Tier sums, the 60 cap, Foundations excluded, duplicates counted once, and that the bundled catalogue actually decodes |
| `HabitRepositoryTests` | Once-per-day, ISO weekly caps and their rollover, Foundations once-ever, no retroactive logging, same-day undo |
| `EvaluationLoopTests` | **Idempotency** — one catch-up pass equals day-by-day; five runs equal one. Nine days offline. Backward clock. Shield preserves without extending. Timezone stability. |
| `HostModeTests` | Draft → publish → cancel (cancelling never deletes), that an edit can't change status, token round-trip, and the scanner: duplicates, wrong event, closed window, and that a scan does **not** award the attendee Vitality |
| `HabitVectorsTests` | That every shipped vector names a real catalogue habit, is 512-dim and unit length, and that none points at a Foundation — the drift that would otherwise fail silently |
| `FightRepositoryTests` | Signup idempotency and re-issued tokens, the −1h/+3h window at its boundaries, one check-in per attendee, attendance credits +10 through the loop rather than directly, and that the seed always has an open window |

No UI tests, no snapshot tests, no mocking framework. The engines are pure functions over values, which is the entire reason they were separated out.

**Phase 3 adds** the rules emulator suite (§3.3) — JavaScript, separate runner, same standing.

---

## Appendix — the original gap analysis

Kept as a record of why the rework happened. All of it is now resolved.

The prototype was a complete, well-built app for **PRD 0.1**, and 0.2 / 0.3 / 0.5 each removed a pillar it stood on: vouchers (0.2), the second currency (0.3), evidence photos (0.5). About 40% survived — the design system, `GlobeView` (already 0–100, which is exactly Vitality), the onboarding shell, the AVFoundation plumbing, and the debug launch hooks.

Inverted rather than merely missing: points reset daily instead of accumulating; Vitality became the persisted value instead of a function of lifetime points; the streak moved into a derived daily loop instead of a counter incremented on log; the camera became a search box instead of an evidence validator.

Two bugs worth remembering, because both were invisible rather than loud:
- `try?` around the catalogue decode turned a one-character JSON mismatch into an app with **zero habits and no error anywhere**. It now traps.
- The evaluation loop marked each day evaluated *before* scoring it, so on normal daily use no day was ever scored. The tests that existed asserted the buggy behaviour, and were outside the Xcode project, so they had never run.
