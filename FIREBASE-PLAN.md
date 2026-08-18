# Firebase — accounts, sync, and shared Fights

Plan of record. Written against `main` @ `3ff043b`.

---

## Why

`main` now carries the full economy — friction catalogue, points pricing, day-gap
streak, six Earth stages wired to Mark's globe art, decay, badge award records, the
distractor classifier and QR check-in. All of it is **local**: one JSON blob, one
device, one implicit user.

The exhibition needs visitors to install the app on **their own phones**. That means
real accounts, and it means one visitor's phone must see a Fight another visitor's
phone created. That is the entire reason for this work.

### Two findings that make this smaller than expected

**The sign-in screen already exists.** `RootView.swift:39` has a private
`SignInPlaceholder` with a "Sign In with Apple" button that calls `app.logIn()` and
flips a bool:

```swift
private struct SignInPlaceholder: View {
    var body: some View {
        VStack(spacing: 24) {
            GlobeView()
            Text("Eco-Habbit")
            Button("Sign In with Apple") { app.logIn() }   // ← placeholder
        }
    }
}
```

The gate (`if app.isLoggedIn`, `RootView:11`) and the log-out button
(`ProfileView:302`) are already there. **Filling this in is the only view change in
the entire plan.**

**No entry-point restructure.** An earlier draft warned that `AppState` is constructed
before auth can resolve. That was true of the `Vincent` branch. `main` gates on a flag
inside `PersistedState` instead, so `Eco_HabbitApp` needs one line and nothing else.

### The actual work

**`main` has no concept of a user.** `AppState` has no `userId`, and `PersistenceStore`
writes to one fixed filename:

```swift
private static let fileName = "ecohabit-state.json"     // PersistenceStore.swift:157
```

Every Firestore path needs a uid. Threading one through the data layer is the real
task, and it touches **zero screens**.

### Decisions already taken

- **New accounts start genuinely empty.** No seeded demo state — a new account is new.
- **Full scope**, through shared Fights.

---

## Stage 0 — Console and SDK
**branch `firebase-setup` · ~45 min · changes no behaviour**

1. Firebase console → new project. Disable Google Analytics.
2. Add iOS app, bundle id **`Ardhana.Eco-Habbit`**.
   > Verified in `project.pbxproj`. **Not** `com.greenapple.ecohabit` — an earlier draft
   > had that wrong, and registering the wrong bundle id means auth silently never works.
3. Firestore → Create database → region **`asia-southeast1`** (Singapore, closest to
   Bali). **The region can never be changed.** Start in production mode; Stage 2 writes
   the real rules.
4. Download `GoogleService-Info.plist` → `Eco-Habbit/` → **commit it**. It holds no
   secret; the rules file is the enforcement layer. The target uses a synchronized file
   group, so dropping it in the folder *is* the "add to Xcode" step.
5. SPM: `https://github.com/firebase/firebase-ios-sdk`. Add **only** `FirebaseAuth` and
   `FirebaseFirestore`. Every extra product is launch time and binary size forever.
6. `FirebaseApp.configure()` as the **first** line of `Eco_HabbitApp.init()`.

**Done when:** app launches, no console error, Firebase shows the app registered.

---

## Stage 1 — Identity
**branch `firebase-auth` · ~1 day**

Two separable halves. Do 1a first — it is the one with risk.

### 1a · Thread a `userId` through the data layer  *(no views)*

Files: `App/AppState.swift`, `Core/Persistence/PersistenceStore.swift`

- `PersistenceStore.load/save/wipe` take a `userId`; the file becomes
  `ecohabit-state-{uid}.json`. Today's single fixed filename means two accounts on one
  device silently overwrite each other. Keep the old filename readable once, as a
  migration for the existing local account.
- `AppState.init(data:)` → `init(userId:data:)`, storing `userId`. Every Firestore path
  in Stages 3–5 is built from it.
- `logIn()` / `logOut()` (`AppState:475`) carry the uid rather than only flipping a bool.

### 1b · Sign in with Apple  *(the one view change)*

- **Apple Developer** → Identifiers → `Ardhana.Eco-Habbit` → tick **Sign in with Apple**.
- **Xcode** → Signing & Capabilities → **+ Sign in with Apple**. Creates
  `Eco-Habbit.entitlements` — commit it. Teams in the project: `3745VLZ7XR` (app),
  `BYX72AR3JC` (tests).
- **Firebase** → Authentication → Sign-in method → enable **Apple**. Nothing to fill in
  for a native iOS app; the Services ID / key setup in most tutorials is for web.
- Replace the body of `SignInPlaceholder` with a real `SignInWithAppleButton`. **Keep
  its layout** — globe, title, button — so the screen looks the same.

**The nonce is what goes wrong.** Apple receives the SHA-256 **hash**; Firebase receives
the **raw** string. Swap them and Firebase rejects the credential with an error that
never mentions nonces.

**Apple returns the user's name exactly once** — on the first ever sign-in for that
Apple ID, and `nil` forever after, including across reinstalls. Every booth visitor is
a first-ever sign-in, so write `fullName` into `PersistedState.userName` **in the same
function that signs in**, not on a later screen they might not reach.

> To re-test your own first-run: Settings → your Apple ID → Sign in with Apple → the
> app → Stop Using.

**Done when:** sign-in works and the console shows the user; force-quit and relaunch
goes straight in with **no flash** of the sign-in screen; log out returns to the
placeholder; a first-ever sign-in puts a real name in Profile.

---

## Stage 2 — Security rules
**branch `firebase-rules` · ~half day · no app code, no SDK needed**

`firebase/firestore.rules` exists **only on the `Vincent` branch** — it was never
merged. Bring it across, then **rewrite it**.

It describes a data model that no longer exists (`/events`, `/signups`,
`vitalityHistory`), and its `/attendance` rule requires *the host* to check an attendee
in, explicitly forbidding self-check-in:

```
&& request.resource.data.userId != request.auth.uid    // "no self-check-in"
```

That is the exact inverse of the shipped QR flow. Deployed as-is, **every check-in
fails.**

### Collection map

| Local | Firestore | Document id |
|---|---|---|
| `PersistedState` (scalars) | `/users/{uid}` | uid |
| `HabitLog` | `/users/{uid}/logs/{id}` | `{habitId}_{localDate}` |
| `EarnedBadge` | `/users/{uid}/badges/{id}` | `badgeId` |
| `Fight` | `/fights/{fightId}` | fightId |
| `FightAttendance` | `/attendance/{id}` | `{fightId}_{uid}` |

**Composite ids are load-bearing.** Once-per-day and one-check-in-per-person become
*structural* — a duplicate is a write to an existing document, which `create`-only rules
reject. No unique constraint, no race.

**Attendance is a self-write**: the attendee's own device credits its own account. That
is the inversion the whole QR design rests on, and it is what lets this work with no
server.

### Test in the Rules Playground before deploying

| Simulate | Expect |
|---|---|
| self check-in, published fight, right code | **allow** ← the one that was inverted |
| same again, document exists | deny — no double credit |
| checking somebody else in | deny |
| log id not matching its payload | deny |
| reading another user's document | deny |
| setting own `isOrganization` to true | deny |

```bash
npm i -g firebase-tools && firebase login
firebase init firestore        # point at firebase/firestore.rules
firebase deploy --only firestore:rules
```

---

## Stage 3 — User document
**branch `firebase-userstate` · ~2–3 hr**

### The blob has to be split

`PersistedState` is one `Codable` struct containing `logs`, `earnedBadges`,
`fightAttendance` and `hostedFights` **inline**. Written to Firestore whole it is a
single document that grows without bound, hits the **1 MB document limit**, and cannot
be queried.

Split at the repository boundary, keeping `PersistedState` as the in-memory shape so
nothing above it changes:

- `/users/{uid}` — everything scalar: points, streak, shields, settings, decay
  bookkeeping, `announcedGlobeStage`, `announcedBadgeIds`.
- `logs` and `earnedBadges` → subcollections in Stage 4.

Add `Core/Repositories/FirebaseUserStateRepository.swift` **behind a flag** in
`AppState.init`, so the local store stays runnable and `tools/run-checks.sh` keeps
passing against it.

Use `setData(merge: true)`. A whole-document replace loses whichever of two devices
wrote last, and merge is what lets a field be added later without a migration.

### Account deletion

**App Review requires it** for any app with sign-in. `resetEverything()` already wipes
locally; it must also delete the Firestore documents and call
`Auth.auth().currentUser?.delete()`, catching `requiresRecentLogin` on an old session.

**Done when:** sign in on a clean device creates `/users/{uid}`; logging an action
updates the console; **delete the app, reinstall, sign in, and the points come back.**

---

## Stage 4 — Logs and badges
**branch `firebase-logs-badges` · ~3 hr**

Mechanical once Stage 3 works.

- `save(_ log:)` uses `setData` on `{habitId}_{localDate}`, **not** `addDocument` — the
  id *is* the dedup.
- `fetchMostRecentLog` (equality on `habitId` + order by `loggedAt`) **needs a composite
  index**. Firestore's error contains a link that creates it — click it once, then commit
  the regenerated `firebase/firestore.indexes.json`. **Do this now, not at the booth.**
- Badges: document id is the `badgeId`, so create-only rules preserve the original
  `earnedAt` for free.

---

## Stage 5 — Fights become shared
**branch `firebase-fights` · ~1–2 days · the demo-visible one**

One phone hosts, another sees it and scans in.

`Fight`, `FightAttendance` and `hostedFights` currently live *inside* `PersistedState`,
and `FightRepository` is a namespace of pure functions over it rather than a data-access
boundary. That has to change.

1. **Add `FightRepositoryProtocol`** — `fetchUpcoming()`, `fetchHosted(hostId:)`,
   `save(_:)`, `checkIn(to:code:userId:)`, `attendance(for:)`. All `async throws`,
   matching the existing style.
2. **Write the local implementation first**, backed by `PersistedState` exactly as
   today, and confirm `tools/QRCheck.swift` still passes **unchanged**. That is the proof
   the protocol did not change behaviour.
3. **Then** the Firebase implementation.
4. Store `startsAt` / `endsAt` as Firestore `Timestamp`, not strings.
5. `savedFightIds` **stays local** — a private shortlist nobody else reads.
6. **Seed the demo Fights once**, from the console or a script. `MockData.fights`
   materialises from `fights.json` on every launch; against a shared collection that is
   one duplicate set *per visitor*. This will bite if skipped.
7. Add a snapshot listener on `/fights` **only** — the one place two devices genuinely
   must agree, and what makes the demo feel live.

**Done when, with two phones and two Apple IDs:**
- A publishes a Fight → **B sees it appear without touching anything**
- B scans A's QR → checked in, points credited on B
- B scans again → refused, no second credit
- A draft on A stays invisible to B

---

## Files this touches

```
views        RootView.swift  (SignInPlaceholder only)      ← the sole view change
entry        App/Eco_HabbitApp.swift                       one line
data layer   App/AppState.swift
             Core/Persistence/PersistenceStore.swift
             Core/Repositories/{Habit,Fight,User}Repository.swift
new          Core/Repositories/Firebase*Repository.swift
             Core/Models/FightRepositoryProtocol.swift
config       firebase/firestore.rules        (bring from Vincent, then rewrite)
             firebase/firestore.indexes.json
             Eco-Habbit/GoogleService-Info.plist
             Eco-Habbit.entitlements
```

**Nothing in `DesignSystem/`, `Features/Habits/`, `Features/Profile/`,
`Features/Earth/` or `Features/Camera/` changes.**

---

## Verification

Run after **every** stage:

```bash
xcodebuild -project Eco-Habbit.xcodeproj -scheme Eco-Habbit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build            # Debug

xcodebuild -project Eco-Habbit.xcodeproj -scheme Eco-Habbit -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build            # archiving works

./tools/run-checks.sh                                                       # 6 suites
```

`main` has **no test target** — `project.pbxproj` contains 0 `Eco-HabbitTests`
references. `tools/run-checks.sh` is the substitute: it compiles the **real** sources
and asserts the economy, not a copy. Keep it green — the Firebase repositories sit
behind a flag precisely so those checks keep running against the local store.

### Migration is the recurring hazard

Synthesized `Decodable` **ignores property defaults** and throws `keyNotFound` on a
missing key, and `PersistenceStore.load()` swallows the throw into a blank account. That
combination silently wiped every account once already. `PersistedState` and `Fight` both
have hand-written `init(from:)` using `decodeIfPresent` for exactly this reason.

**Any field added in this plan must follow that pattern** — and be *proved* by injecting
an old-format state file into the simulator container and relaunching, not assumed:

```bash
DEV=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
C=$(xcrun simctl get_app_container "$DEV" Ardhana.Eco-Habbit data)
# edit "$C/Documents/ecohabit-state.json", remove the new key, relaunch
```

---

## Watch-outs

| Risk | Why it bites | Do |
|---|---|---|
| **Auth needs network** | Firestore reads from cache offline, but **authentication does not work offline at all**. No wifi = nobody past the first screen | Test on the venue wifi in advance; keep a phone hotspot; make the failure message say "check your connection", not an SDK string |
| **Offline writes look successful** | `setData` returns before the server sees it; a rules rejection surfaces later, silently | For check-in, read the document back before showing the reward animation |
| **1 MB document limit** | `PersistedState` grows with every log | Why Stage 3 splits the blob rather than storing it whole |
| **Catalogue is not user data** | `habits.json` and the badge list are identical for everyone | Leave them bundled — moving them costs a billed read per user per launch |
| **`isOrganization` is a debug toggle** | Anyone reaching the debug menu grants themselves hosting rights | Rules guard the field; set it from the console or Admin SDK |
| **Real personal data** | Sign in with Apple gives private-relay emails, but these are real accounts | Privacy policy URL (App Review needs one anyway) + the delete path in Stage 3; plan to wipe the project afterwards |
| **Free-tier limits** | 50k reads / 20k writes per day | An exhibition won't come close — unless a snapshot listener loops. Watch the usage graph during the dry run |

---

## Not in this plan, still outstanding

- **Detection thresholds.** `autoLogSimilarity = 0.30`; real photographs score
  0.10–0.25, so the camera may reject nearly everything in venue lighting. Independent
  of Firebase and **still the highest exhibition risk**. Needs a phone and daylight.
- **Mascot artwork.** `HabitCategory+Camera.swift` maps `mascotName → iconDetail`
  because main has no mascot assets; the six SVGs are on the `Vincent` branch. One line
  to switch once they land.
- **Test target.** 6 suites (~60 tests) sit on `Vincent` and cannot build — the target
  was removed from `project.pbxproj`.
- **`DebugGate`.** The `mangrove` password screen is on `Vincent`; `TimeTravelMenu` is
  currently reachable **unguarded** on main.
- **Globe pacing.** The prototype advanced a stage every 2 actions; real thresholds need
  150 points for the first transition, so at a booth the globe will not move. Either
  lower the early values in `PointsConfiguration.stageThresholds` or seed demo accounts
  near a boundary. Product call.
