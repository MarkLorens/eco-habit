# Eco Habit — iOS frontend

SwiftUI front-end for the Eco Habit sustainability habit-tracker. UI, navigation and
local state only: no backend, no real auth, no CoreML. Every number you see is computed
on device from data in `MockData.swift` and persisted to a JSON file in Documents.

Built against the **Organic** design system from the attached Claude Design project
(`EcoHabit.dc.html`). Its tokens — cream/sand ground, terracotta + sage accents,
Caprasimo over Figtree, over-rounded containers and pill controls — are ported verbatim
into `DesignSystem/Theme.swift`. Nothing else in the app hard-codes a colour or radius.

## Running it

```bash
open ~/Documents/Eco-Habbit/Eco-Habbit.xcodeproj
```

Scheme `Eco-Habbit`, iOS 17+, portrait. The login screen has a **demo account** button
that fills valid credentials and goes straight through.

## Structure

```
Eco-Habbit/
  Models/          ActivityCategory, Activity, PointsEngine (stages, multipliers, decay)
  ViewModels/      AppState (the shared store), PersistenceStore, PhotoStore
  MockData/        activity catalog, vouchers, badges, missions; MockMLDetector
  DesignSystem/    Theme tokens, components, GlobeView, CategoryIconView, FontLoader
  Views/           Auth · Onboarding · Home · Activity · Camera · Redeem · Profile · Shared
  Resources/Fonts/ Caprasimo + Figtree (OFL)
```

The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, so: the model layer, `MockData`,
`PersistenceStore` and `PhotoStore` are explicitly `nonisolated` (pure values and file
I/O, called from `AppState.init` and from detached tasks), and files using Combine types
import Combine rather than relying on SwiftUI re-exporting it. Keeping those settings on
means this compiles clean under the Swift 6 language mode later.

`AppState` is a single `@MainActor ObservableObject` injected as an `@EnvironmentObject`.
Every mutation goes through `mutate { }`, which writes the whole `PersistedState` blob
atomically — small enough that this is cheaper than Core Data at this stage. Evidence
photos are the exception: they're downscaled JPEGs on disk, indexed by `EvidencePhoto`.

## The rules it implements

**Two point pools.** Earth Points drive the globe and are never spendable. Reward Points
are the redeemable pool and never expire. A logged action credits both; redeeming only
debits Reward Points.

**Points.** Base 5–20 per activity by effort, evidence bonus +25% (mid-band of the 20–30%
spec), streak multiplier ×1 / ×1.25 / ×1.5 / ×2 at days 1–6 / 7–13 / 14–29 / 30+. All of
it lives in `PointsEngine` — nothing computes points anywhere else.

**One credit per activity per day, from any source.** The checklist, a Home suggestion
card and the camera all funnel through `AppState.logActivity`, which checks today's
completions first. The camera says "Already logged today" instead of paying out twice.

**Earth stages.** 0 / 300 / 800 / 1,800 / 3,500 cumulative Earth Points. Globe health is
`8 + 92 × (points / 3500)` — floored at 8 so a fresh account picks up exactly where the
onboarding story animation ends.

**Decay.** After a full inactive week, Earth Points drop 7.5% per week, applied
idempotently via `decayWeeksApplied`. A warning banner appears on Home from day 5.
Streak breaks after two days. Both are re-evaluated on launch and on foreground.

**Mock detection.** `MockMLDetector` picks at random from activities flagged
`isCameraDetectable`, weighted 70/30 toward the user's favourite categories, and reports a
plausible confidence. Correcting the category reverts the first award and re-logs against
the corrected one, so points never double up. Replacing this with a real `VNCoreMLRequest`
means rewriting one function body.

## Things worth knowing

- **Camera.** `Views/Camera/` is a custom AVFoundation capture UI, because the design's
  camera screen isn't a system picker. On the Simulator there's no capture device, so it
  shows the designed placeholder and the shutter still runs the full detect → award →
  correct flow with a nil image. Evidence attachment from the activity list uses
  `PhotosPicker` (library) and `UIImagePickerController` (camera).
- **Fonts** are bundled TTFs from Google Fonts. `FontLoader` registers everything in the
  bundle at launch so `Font.custom` resolves regardless of where the build copies them.
- **Permissions** are real native prompts (`AVCaptureDevice`, `CoreLocation`), asked in
  onboarding and re-askable from Profile → Privacy. Both are skippable.
- **Notification toggles** are UI only — nothing is scheduled with the system yet.
- **Debug launch hook.** `#if DEBUG` only, for screenshots and QA:
  `-EHDemo 1` seeds a mid-game account, `-EHStage login|onboarding|app` picks the flow,
  `-EHTab home|activity|redeem|profile` picks the tab. Release builds ignore all of it.
- **Reset.** Profile → Reset local data wipes state and photos and re-runs onboarding.

## Deliberate departures from the reference

- The design file's five categories are consumption-shaped (Food, Shopping, Home &
  Energy, Mobility, Community). The spec's five are impact-shaped, so the app uses those:
  Waste Reduction, Energy Saving, Water Conservation, Green Mobility, Community Action.
  The icon set is the design's, plus a droplet drawn in the same style for water.
- Copy is English throughout, matching the design file. The category names above are the
  English forms of the spec's Indonesian ones.
- `Activity` is an immutable catalog entry; per-day state lives in `Completion` and is
  joined into `ActivityRow` for rendering. The spec sketched `isCompletedToday` /
  `hasEvidence` as properties on `Activity`, but three surfaces read that state and one
  copy of the truth is what makes the dedup rule hold.
