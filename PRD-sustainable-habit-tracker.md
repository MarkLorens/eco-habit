# Product Requirements Document
## Sustainable Habit Tracker (working title: **Terra**)

| Field | Value |
|---|---|
| Version | 0.6 (Draft) |
| Owner | GreenApple |
| Audience | Internal team |
| Context | Apple Developer Academy — exhibition MVP |
| Platform | iOS only, SwiftUI |
| Target OS | iOS 18.0+ |
| Language | English (v1) |
| Status | Pending team review |

> **Changelog.**
> **0.2** — Vouchers, partners, and redemption removed. External engagement became **Fights**: real-world community events hosted by verified organisations.
> **0.3** — **Seeds removed entirely.** There is now a single point system, and its only function is to feed the Earth. Nothing is spendable, nothing is redeemable, and there is no second balance anywhere in the app.
> **0.4** — Backend switched from Supabase to **Firebase**. Check-in restructured to eliminate the last piece of server logic — the app now has **zero server code**. Added the security model (§9.6), forward-compatibility constraints (§9.7), backend migration triggers (§9.8), and trust and safety (§9.9). Local notifications brought back into scope.
> **0.5** — Camera repurposed from evidence capture to **visual search** — no photos stored, no evidence bonus, Firebase Storage removed. Organisation host tools moved fully into iOS; the web dashboard is now admin-only.
> **0.6** — **Camera switched to zero-shot MobileCLIP** (§5.2): no trained head, no training photographs, 18 searchable habits — this closes §12 Q3. **Onboarding removed entirely** (§6.0) — sign in lands straight on the dashboard. **Firebase deferred from Phase 3 to Phase 10** (§13): all business logic is proven on-device against bundled JSON before the cloud arrives. Local persistence is a `Codable` blob until then; SwiftData is no longer assumed (§9.10). Added **§9.13 Code architecture and collaboration**: file layout, ownership boundaries, and the rule against a shared god object. Screen specs in §6 cleaned of the evidence-photo language 0.5 orphaned. Catalogue totals corrected to 43 recurring + 7 Foundations. Notifications reconciled with §9.4. Added **Phase 0** to §13 — the existing prototype is built against 0.1 and needs an explicit teardown before Phase 1.

> **How to read this doc.** **[DECISION]** marks a call made to keep the spec unblocked — overrule freely. **[OPEN]** marks something still needing an owner.

---

## 1. Overview

### 1.1 Problem
People who already care about sustainability struggle to convert intent into daily habit. Existing habit trackers are generic and give no feedback on *why* an action matters; existing sustainability apps are one-shot carbon calculators. Neither gives a reason to come back tomorrow, and neither connects private effort to collective action.

### 1.2 Solution
A habit tracker built exclusively around sustainable actions, organised around **one thing**: a living Earth that heals when you act and degrades when you stop.

- **Habits** earn points. Points feed the Earth. That is the entire economy.
- **Fights** — real-world community events hosted by verified organisations — feed it far harder than any daily habit can.
- **Badges** record what you have done. They are a history, not a balance.

Plus a low-friction logging path: the camera acts as a **visual search** over the habit catalogue — point it at something and the matching habits surface as tappable chips. No photo is stored.

**There is one currency and it cannot be spent.** No vouchers, no rewards, no second balance to accumulate in parallel. Points exist solely to move Vitality. This is the defining constraint of the product — every feature either feeds the Earth or it doesn't ship.

### 1.3 Target user (v1)
Bali-based residents, 20–40, who already self-identify as environmentally conscious but are inconsistent in practice. Secondary: long-stay expats and digital nomads in the Ubud/Canggu corridor.

We are **not** targeting people who need convincing that sustainability matters. That's a different product with a different onboarding.

### 1.4 Success criteria (exhibition)
1. A visitor completes the full loop — log a habit → watch the Earth respond → browse a Fight → check in — in under 90 seconds unassisted.
2. Camera recognition works live, on-device, with no network, across at least 10 demo habits. *(18 ship; needs on-device threshold tuning.)*
3. The Earth visualisation reads as *alive* to someone who has never seen the app.

Product metrics (DAU, D7, event attendance rate) are **[OPEN]** and deferred past the exhibit.

---

## 2. Core concepts

### 2.1 One currency

**Points** are earned by logging habits and attending Fights. Their only function is to determine whether the Earth grows or decays that day.

| | **Points** | **Vitality** |
|---|---|---|
| What it is | Daily earnings from actions | Earth health, 0–100 |
| Lifespan | **Reset every day at local midnight** | Persistent |
| Can it be spent? | No — nothing to spend on | No |
| Relationship | Points determine today's Vitality delta | The only number that persists |

**[DECISION]** Points do **not** accumulate into a lifetime balance. There is no running total displayed anywhere, no wallet, no score to grind. Each day you earn points, the day's total is compared against a target, the Earth moves accordingly, and the counter resets.

This is the whole reason for the change from 0.2: a persistent point total is a second progress bar competing with the Earth for the user's attention. If the Earth is the emotional core, nothing else should be countable.

*(Lifetime counts of habits logged and Fights attended still exist as profile statistics and badge criteria — but those are counts of actions, not a currency.)*

### 2.2 Vitality mechanics

**Daily Target — 30 points.**

**[DECISION]** The target is expressed in points, not in a number of habits. This is deliberate: three trivial Tier 1 habits (15 points) shouldn't satisfy the same goal as one genuinely difficult Tier 3 action (20 points). Weighting the target by impact means the system rewards what actually matters rather than what's easiest to tap.

Roughly, 30 points is: three moderate habits, or two moderate plus one light, or one high-impact plus one moderate.

**Daily Vitality delta**, evaluated for each elapsed local day:

| Points earned that day | Vitality change |
|---|---|
| 0 | **−3** |
| 1–29 | **+1** |
| 30+ (target met) | **+3** |
| 30+ for 7 consecutive days | **+3**, plus a one-off **+5** bonus |
| Attended a Fight | **+10** (replaces the above for that day) |

- Vitality is clamped to **[5, 100]**. It never reaches zero — a dead Earth is a dead app, and there's no recovery narrative from a rock.
- Recovery outpaces decay. Returning after a lapse should feel achievable, not like starting over.
- Reaching 100 takes ~30 days of consistent logging. Maintaining it still requires logging — Vitality at 100 decays if you stop.
- **Daily point cap: 60.** Twice the target. Prevents one burst session from banking a week's progress, and keeps the target meaningful.

**[OPEN]** Whether decay should accelerate after consecutive zero days (−3, −4, −5). Simpler to ship flat; revisit after playtesting.

### 2.3 Earth stages

Vitality maps to five visual stages, transitioned with animation, never a hard cut.

| Stage | Vitality | Visual direction |
|---|---|---|
| 1 — Barren | 5–20 | Grey, cracked, smog-heavy, no water |
| 2 — Stirring | 21–40 | First green patches, murky water returns |
| 3 — Recovering | 41–60 | Visible forests, clearer oceans, thinning smog |
| 4 — Thriving | 61–85 | Lush, clear atmosphere, wildlife elements |
| 5 — Flourishing | 86–100 | Vibrant, ambient particle effects, aurora |

**[DECISION]** v1 uses a **single global transformation**, not per-biome. Biome-per-category is better long-term design but multiplies art requirements by six, and the exhibit doesn't need it. Noted in §11 as a v2 candidate.

**[OPEN]** Art pipeline — layered PNG/SVG crossfades vs. SpriteKit particles vs. rendered image sequence. Needs a designer call in week 1; it is the long pole on the dashboard.

### 2.4 Shield (vacation protection)

- **2 Shields per calendar month**, non-stacking above a **3 Shield** ceiling.
- One Shield forces that day's Vitality delta to **0** — no decay, no gain, streak preserved but not extended.
- **Must be activated before or during the day it covers.** No retroactive application, ever. This is the entire anti-abuse mechanism.
- Maximum **3 consecutive** Shielded days, then decay resumes regardless of balance.

---

## 3. Habit system

### 3.1 Categories

**[DECISION]** Six categories:

| Category | Scope | Icon direction |
|---|---|---|
| **Energy** | Electricity, cooling, devices | Bolt / sun |
| **Water** | Consumption, reuse, pollution | Droplet |
| **Waste** | Reduce, reuse, recycle, compost | Recycling arrows |
| **Food** | Diet, sourcing, waste | Leaf / bowl |
| **Transport** | Mobility choices | Bicycle |
| **Consumption** | Purchasing, repair, secondhand | Tag / bag |

Fights use a **separate taxonomy** (§4.2) and do not map onto these.

### 3.2 Habit frequency types

| Type | Behaviour | Counts toward Daily Target? |
|---|---|---|
| **Daily** | Loggable once per calendar day | Yes |
| **Weekly** | Loggable up to N times per ISO week | Yes |
| **One-time** | Loggable exactly once, ever, per account | **No** — see below |

**[DECISION]** One-time habits are branded **Foundations** ("switch to LED bulbs", "install a low-flow showerhead"). They award a **one-off +2 Vitality directly**, bypassing the point system entirely.

Rationale: Foundations are genuinely high-impact and deserve recognition, but they cannot be part of a daily target — a new user would clear a week of targets in one sitting and then face a cliff. Awarding Vitality directly, in a small fixed amount, recognises them without distorting the daily loop. They live in a separate tab within Habits.

### 3.3 Points

**[DECISION]** Three tiers by combined impact × effort:

| Tier | Points | Description |
|---|---|---|
| Tier 1 — Light | **5** | Low friction, small impact |
| Tier 2 — Moderate | **10** | Real effort or real impact |
| Tier 3 — High | **20** | Significant effort/impact, often weekly |

**No evidence bonus.** Removed in 0.5 along with photo capture (§5.1). Point values are purely tier-based, which makes the 30-point daily target easier to reason about: exactly three moderate habits, or one high plus one moderate.

**Outside the tier system:**
- **Foundations** — +2 Vitality directly, no points (§3.2).
- **Fights** — +10 Vitality directly, no points (§4.5).

**Daily cap:** 60 points (§2.2). Shown as a progress ring against the 30-point target, so a user sees both "am I on track" and "how much further can today go."

**[DECISION]** No streak multipliers on points. Streaks are rewarded through the Vitality bonus and through badges. Compounding both would make a long-running user's Earth effectively immune to decay.

### 3.4 Logging rules

- Day boundary is **local midnight in the device's current timezone**.
- **No retroactive logging.** If you didn't log it yesterday, it didn't happen. Unusual for habit trackers, but it removes the largest cheating vector and makes evidence meaningful.
- Un-logging permitted **within the same day only**. Points reversed, cap refunded.
- Custom user-created habits: **out of scope for v1**.

### 3.5 Habit content

| Field | Purpose |
|---|---|
| `title` | Short imperative, e.g. "Air-dry your laundry" |
| `category` | One of six |
| `tier` | 1 / 2 / 3 / Foundation |
| `frequency` | Daily / Weekly(N) / One-time |
| `shortDescription` | One line, shown on card |
| `howTo` | 3–5 step guidance |
| `impactStatement` | Quantified where possible, e.g. "~0.7 kg CO₂e per load" |
| `impactSource` | Citation URL — **mandatory**, no unsourced claims |
| `mlClassLabel` | Nullable — maps to classifier output class. Non-null for the 12 camera-searchable habits |

**[OPEN]** Content ownership. 50 habits × sourced impact data is ~2–3 person-days. Assign a named owner in week 1 or this is the thing still unfinished at exhibit time.

### 3.6 The 50 habits (v1 catalogue)

📷 marks habits that are plausible candidates for camera search. Only 12 ship in the v1 classifier (§5.2); the rest are manual-only.

**Energy (8)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 1 | Set AC to 25°C or higher 📷 | 2 | Daily |
| 2 | Air-dry laundry instead of using a dryer 📷 | 2 | Daily |
| 3 | Unplug idle chargers and devices 📷 | 1 | Daily |
| 4 | Work by natural daylight for the morning | 1 | Daily |
| 5 | Run the fan instead of the AC | 2 | Daily |
| 6 | Full-load only for washing machine | 1 | Weekly (3) |
| 7 | Switch all bulbs to LED 📷 | Foundation | One-time |
| 8 | Enable low-power mode for a full day 📷 | 1 | Daily |

**Water (8)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 9 | Shower in under 5 minutes | 2 | Daily |
| 10 | Turn off tap while brushing teeth | 1 | Daily |
| 11 | Reuse greywater for plants 📷 | 2 | Daily |
| 12 | Collect rainwater 📷 | 3 | Weekly (3) |
| 13 | Fix a dripping tap 📷 | Foundation | One-time |
| 14 | Install a low-flow showerhead 📷 | Foundation | One-time |
| 15 | Wash produce in a basin, not running water 📷 | 1 | Daily |
| 16 | Skip watering the garden after rainfall | 1 | Weekly (4) |

**Waste (10)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 17 | Refuse a plastic bag; use your own 📷 | 2 | Daily |
| 18 | Use a reusable water bottle 📷 | 2 | Daily |
| 19 | Bring your own coffee cup 📷 | 2 | Daily |
| 20 | Refuse a plastic straw 📷 | 1 | Daily |
| 21 | Segregate waste into organic/inorganic 📷 | 2 | Daily |
| 22 | Compost food scraps 📷 | 3 | Daily |
| 23 | Drop recyclables at a collection point 📷 | 3 | Weekly (2) |
| 24 | Refill household products at a bulk store 📷 | 3 | Weekly (1) |
| 25 | Use cloth instead of paper towels 📷 | 1 | Daily |
| 26 | Set up a home composting system 📷 | Foundation | One-time |

**Food (8)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 27 | Eat a fully plant-based meal 📷 | 2 | Daily |
| 28 | Eat a fully plant-based day 📷 | 3 | Weekly (7) |
| 29 | Finish leftovers instead of discarding 📷 | 2 | Daily |
| 30 | Buy produce from a local market 📷 | 2 | Weekly (3) |
| 31 | Choose loose produce over packaged 📷 | 1 | Daily |
| 32 | Pack a home-cooked lunch 📷 | 2 | Daily |
| 33 | Cook with in-season local ingredients 📷 | 1 | Daily |
| 34 | Plan a week's meals to prevent waste 📷 | 2 | Weekly (1) |

**Transport (8)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 35 | Walk or cycle a trip under 2 km 📷 | 2 | Daily |
| 36 | Take public transport instead of driving 📷 | 2 | Daily |
| 37 | Share a ride / carpool 📷 | 2 | Daily |
| 38 | Combine errands into one trip | 1 | Weekly (3) |
| 39 | Go a full day without motorised transport | 3 | Weekly (7) |
| 40 | Maintain correct tyre pressure 📷 | 1 | Weekly (1) |
| 41 | Work from home to skip the commute | 2 | Weekly (5) |
| 42 | Service your vehicle for efficiency 📷 | Foundation | One-time |

**Consumption (8)**
| # | Habit | Tier | Freq |
|---|---|---|---|
| 43 | Repair something instead of replacing it 📷 | 3 | Weekly (3) |
| 44 | Buy secondhand instead of new 📷 | 3 | Weekly (3) |
| 45 | Complete a no-spend day | 2 | Daily |
| 46 | Donate or pass on usable items 📷 | 3 | Weekly (2) |
| 47 | Choose a product with minimal packaging 📷 | 1 | Daily |
| 48 | Borrow or rent instead of buying 📷 | 2 | Weekly (3) |
| 49 | Unsubscribe from retail marketing emails 📷 | Foundation | One-time |
| 50 | Switch to a refillable cleaning-product system 📷 | Foundation | One-time |

*Totals: **43 recurring + 7 Foundations**. Foundations are #7, #13, #14, #26, #42, #49, #50. 12 camera-searchable in v1.*

---

## 4. Fights (community events)

### 4.1 Concept
A **Fight** is a real-world, scheduled, location-based sustainability event — a beach cleanup, a mangrove planting, a reef restoration dive. Users browse upcoming Fights, sign up, attend, and are checked in on site by the host.

Fights are the app's collective layer. Habits are what you do alone; Fights are what you do together, and the reward reflects that: **+10 Vitality**, awarded directly. That is more than three consecutive perfect days of habits, delivered in a single afternoon.

### 4.2 Event types

**[DECISION]** Fights have their own taxonomy, deliberately not mapped to habit categories — a mangrove planting isn't "Water" or "Food," and forcing the mapping would distort both lists.

| Type | Example |
|---|---|
| Beach Cleanup | Coastal plastic collection |
| River Cleanup | Waterway and drainage clearing |
| Mangrove Planting | Coastal restoration |
| Tree Planting | Reforestation and urban greening |
| Reef Restoration | Coral fragment planting |
| Waste Drive | Community sorting or collection event |
| Workshop | Composting, repair café, education |
| Wildlife Protection | Turtle release, habitat protection |

### 4.3 Hosting

**[DECISION]** **Verified organisations only.** Individual users cannot host in v1.

- A boolean `is_organization` on the user record gates all hosting capability.
- **Verification is manual.** A developer or admin flips the flag directly in the database, or via the admin dashboard (§8). No application flow, no review queue, no automated vetting.
- Intentional scope reduction: real host vetting is a trust-and-safety system, not a feature, and it is not buildable before the exhibit.
- **[OPEN]** Whether individual hosting ever unlocks, and on what basis. With no lifetime score to gate it against, this needs a different mechanism than 0.2 assumed — likely admin approval per user.

An organisation account can create, edit, cancel, and check in attendees for its own events. It cannot touch anyone else's.

### 4.4 Signup and cancellation

- Any user may sign up for any upcoming Fight.
- **No capacity limits in v1.** No waitlist, no cap. **[OPEN]** — real events have physical limits, so this returns in v2.
- Users may cancel at any time before the event starts.
- **No penalty for cancelling or for no-shows.** No Vitality damage, no reliability score. Punishing non-attendance in a v1 with no capacity pressure creates anxiety for no benefit.

### 4.5 Attendance verification

**[DECISION]** **Host scans attendee QR.**

1. On signup, the app generates a signed check-in token for that `(user, event)` pair and renders it as a QR code in the app.
2. At the venue, the host opens the event in scan mode and scans each attendee's code.
3. The scan calls the `check_in_attendee` server function, which validates the token, confirms the event is within its check-in window, confirms the attendee is signed up, and awards **+10 Vitality** atomically.
4. The attendee's device reflects the change on next sync; the host sees a running attendee count.

**Why the host scans, not the attendee:**
The host controls the physical space. If attendees scanned a host-displayed code, that code could be photographed and shared with people who never showed up. Reversing the direction means the credential lives on the attendee's phone and can only be redeemed by someone physically holding the host's device.

**Constraints:**
- Check-in window opens 1 hour before start and closes 3 hours after end. **[OPEN]** — tune after a real event.
- One check-in per attendee per event, enforced by a unique database constraint.
- The **+10 Vitality replaces** that day's normal delta rather than stacking on top of it. Attending a Fight is the best possible outcome for a day; habits logged the same day still count toward the streak but do not add further Vitality.
- Check-in **requires connectivity on the host's device.** No offline queue: awarding Vitality to another user is a cross-user write and cannot be optimistic. **[OPEN]** — many Bali beaches and mangrove sites have no signal, which is precisely where these events happen. Fallback: host marks attendance from a roster afterwards.

### 4.6 Past events
Attended Fights are archived permanently and visible on the profile — a scrollable history of what the user has shown up for. This is the record the Fight badges are built on.

### 4.7 Not in v1
- Event photos or recaps (host or attendee uploaded).
- Attendee lists visible to other users — **the attendee list is private**, visible only to the host.
- Map view or distance-based filtering. The Fights list is **chronological**. **[OPEN]** — a map is the obvious v2 addition and is why events carry lat/lng from day one.
- Comments, chat, or any social interaction between attendees.

---

## 5. Camera (visual search)

### 5.1 What the camera is — and is not

**[DECISION]** The camera is a **search input**, not a verification mechanism.

Point it at something and it finds the matching habit in the catalogue, saving the user from navigating six categories and fifty rows. That is its entire job. It does not verify that a habit was performed, it does not produce evidence, and **no photo is ever saved or uploaded.**

This is a reversal from 0.3, and it is a significant simplification:

| Removed | Consequence |
|---|---|
| Evidence photos | **Firebase Storage drops out of the stack entirely** |
| Evidence bonus (+50%) | Point values are purely tier-based |
| Photo retention policy | No retention question, because nothing is retained |
| Photo-based anti-abuse (pHash, EXIF) | Nothing to check |
| Upload queue and retry | One fewer offline concern |

The honest framing: photo evidence was never real verification. Nothing stopped a user photographing the same reusable bottle daily, and with points unspendable there was never an incentive to. It added a storage dependency, a privacy surface, and a retention decision in exchange for the *appearance* of rigour. Dropping it costs nothing real.

**The app is now honour-system throughout, by design** (§5.5).

### 5.2 Approach

**[DECISION] Zero-shot MobileCLIP. Changed in 0.6 — there is no trained head and there are no training photographs.**

0.5 assumed a linear head trained on 15–25 photos per class, which made ML data collection a blocking open question (§12 Q3) and the second-longest calendar item in the project. It is not needed. CLIP's text tower and image tower share one embedding space, so a habit can be described in *words* and matched against a frame directly.

1. Habit described by ~7 prompts, offline → **text** tower → normalise each, mean, normalise again → one vector per habit.
2. Viewfinder frame → **image** tower → embedding vector.
3. Cosine similarity against every habit vector; the top three over threshold become chips (§5.3).

Only the vectors and the image tower ship. Adding a habit costs five sentences and a re-run of the generator, not a photo shoot.

| | Trained head (0.5) | Zero-shot (0.6) |
|---|---|---|
| Photos required | 15–25 × N classes | **none** |
| Adding a class | collect, retrain, re-export | write prompts, re-run generator |
| Blocking on data collection | yes | **no** |
| Ships | encoder + head | encoder + a 200 KB JSON |

**Variant: MobileCLIP-S2 (v1), 512-dim.** The image tower in the bundle and the text tower that generated the vectors **must be the same variant**. A v1/v2 or S0/S2 mismatch produces scores in a completely normal-looking range that mean nothing at all — no error, no warning. This is the single sharpest edge in the feature.

**The frame is processed in memory and discarded.** Nothing is written to disk, the photo library, or the network.

**[DECISION]** v1 ships **18 camera-searchable habits**, up from the 12 in 0.5 because the cost per habit collapsed: ws1 bag, ws2 bottle, ws3 cup, ws4 straw/cutlery, ws5 segregation, ws6 compost, ws8 bulk refill, ws9 cloth, f1 plant-based meal, f4 local market, f6 packed lunch, t1 bicycle, t2 public transport, c1 repair, c2 secondhand, c6 borrow, e2 air-dried laundry, w4 rainwater.

Dropped from the 0.5 list: **#11 greywater reuse** — a bucket of water has no visual signature CLIP can name. Habits that are not object-presence detectable are correctly absent rather than forced; CLIP has no negation, no counting and no spatial reasoning, so "set the AC to 25°C" was never reachable.

**On false positives.** Pointed at a single-use plastic bottle, the model will happily suggest "Use a reusable water bottle" — to CLIP both are simply *a bottle*. For a validator that would be fatal. For a search box it is the **correct** result: it found the habit related to what you are looking at, and it never claims you performed it. This is exactly the property that made §5.1's reframing worth doing.

### 5.3 Interaction model

**[DECISION]** **Live viewfinder with continuous inference**, in the manner of a visual search tool — not shutter-then-result.

- The viewfinder runs inference on a throttled frame stream (target ~3 fps, tuned for thermals).
- Matching habits surface as **chips along the bottom edge**, ranked, updating as the camera moves.
- Each chip shows the habit title and its point value.
- **Tapping a chip logs that habit.** One tap, no confirmation step, with the standard same-day undo.
- A persistent **"Browse all habits"** affordance sits beside the chips.

**There is no auto-log, at any confidence.** The camera never decides on the user's behalf — it only narrows fifty options down to two or three. This is why the shutter button disappears: there is nothing to capture.

**Thresholds** are now a display concern rather than a correctness one:

| Condition | Behaviour |
|---|---|
| Any class ≥ **0.15** | Show as a chip, up to 3, ranked |
| Nothing ≥ 0.15 | Empty state: "Point at something, or browse all habits" |

Low and permissive, deliberately. A false suggestion costs a glance; a missing suggestion costs the whole feature.

### 5.4 Rules
- A habit already logged today, or at its weekly cap, appears **greyed with a "done today" label** rather than being hidden. Hiding it makes the camera look broken.
- Habits not in the 12-class model are unreachable by camera and must be logged manually. This is invisible to the user and needs no explanation.
- **No photo library access. No `NSPhotoLibraryUsageDescription`.** Camera permission only.

### 5.5 Anti-abuse

With one non-spendable currency, no real-world reward, and no evidence requirement, **the app is honour-system by design**. Cheating harms only the cheater's own Earth.

Enforced:
- One log per habit per day (document ID keyed on `localDate`).
- Weekly caps and the 60-point daily ceiling, client-side.
- No retroactive logging.
- One check-in per attendee per event (§9.3).

Deliberately absent, and no longer meaningful now that photos are gone: evidence duplicate detection, EXIF validation, screen-capture detection.

---

## 6. Screens

### 6.0 Auth

**[DECISION] There is no onboarding flow.** Cut in 0.6. Sign in and you are on the dashboard.

The intro panels and the starter-habit picker were removed for the reason they usually should be: at an exhibition the visitor has under 90 seconds (§1.4), and every panel between them and a living Earth is a panel spent not seeing the product. The app also isn't aimed at people who need convincing (§1.3) — it is aimed at people who already care, and they do not need three screens explaining why sustainability matters.

- **Sign in with Apple only.** One provider, minimal PII, one tap for exhibit visitors.
- New accounts start at **Vitality 30** (Stage 2 — Stirring), not at the floor. A brand-new user staring at a dead planet they didn't kill is demotivating; starting at Stirring gives them something visibly worth protecting.
- **No starter-habit selection, no motivation questions, no permission pre-prompts.** Favourite categories are an opt-in preference in Settings, empty by default. Camera access is requested by the camera the first time it opens, which is where iOS wants it asked anyway.

### 6.1 Dashboard — Tab 1
- **Earth visualisation** — dominant, ~55% of viewport. Tappable for a detail sheet.
- Vitality value and stage name.
- **Today's points ring**: `20 / 30` against the daily target, with the 60 cap marked. This is the only point display in the app.
- Current streak.
- Quick-log strip: 3 suggested habits, one-tap loggable.
- **Next Fight** card if signed up for an upcoming event.
- Decay warning banner after a zero day.
- Shield button with remaining balance.

Earth detail sheet: 30-day Vitality sparkline, category breakdown, next-stage threshold.

### 6.2 Habits — Tab 2
- Six category cards in a grid, each showing today's completion (e.g. `2/8`).
- Segmented control: **Today** / **Foundations**.
- Category tap → habit list.
- Row: title, tier badge, point value, checkbox. **No camera icon on the row** — the camera is a search entry point in the tab bar, not a per-habit action (§5.1).
- Checking logs immediately with haptic; points animate into the dashboard ring.
- Chevron → habit detail.
- Completed habits collapse to a dimmed section at the bottom.
- Foundations show `+2 Vitality` rather than a point value, so the difference is legible at a glance.

### 6.3 Habit detail
- Title, category, tier, point value. **One value — there is no evidence variant** (§3.3).
- **How to do it** — 3–5 steps.
- **Why it matters** — quantified impact with linked source.
- Last 30 days of logs as a small grid.
- Primary action: **Log**. Nothing else — no capture, no attachment.

### 6.4 Camera — visual search
Centre button in the tab bar — one tap from anywhere.
- Full-screen live viewfinder. **No shutter button** — there is nothing to capture (§5.3).
- Continuous inference; matching habits surface as ranked **chips along the bottom edge**, each showing title and point value.
- **Tap a chip to log.** Immediate, with haptic and same-day undo.
- Already-logged habits appear greyed with a "done today" label rather than vanishing.
- Persistent **Browse all habits** affordance beside the chips.
- Empty state when nothing matches: "Point at something, or browse all habits."
- Torch and camera flip. No gallery access, no filters, no capture.

### 6.5 Fights — Tab 3

**Browse (default):**
- Chronological list of upcoming Fights.
- Card: type icon, title, host organisation, date and time, location name, signup state.
- Filter by event type. No map, no distance filter in v1.

**Fight detail:**
- Title, type, host organisation, full description.
- Date, time, location name and address. Address tappable → opens Maps.
- What to bring / preparation notes.
- Reward: **+10 Vitality**.
- Primary action: **Join** / **Cancel signup**.
- Once joined: **Show my check-in code** → full-screen QR, brightness boosted.

**My Fights:**
- Upcoming (with quick access to the QR) and Past (attended, archived permanently).

### 6.5.1 Host mode — organisation accounts

**[DECISION]** Organisation host tooling lives **fully in the iOS app**, not the web dashboard. Reversed from 0.4, which had event creation dashboard-only.

Rationale: an organisation running a beach cleanup is standing on a beach with a phone. Requiring them to open a laptop to post an event, then a phone to scan attendees, splits one workflow across two devices for no benefit. If they need the phone for check-in anyway, everything else should be there too.

**How it surfaces.** Host mode is an *additive* layer on the existing Fights tab, gated on `isOrganization`, not a separate app mode or a parallel tab bar. A verified organisation sees the same Browse, Fight detail, and My Fights as everyone else — an organisation is still a user who attends other people's events — plus:

- A **Hosting** segment alongside Upcoming and Past in My Fights.
- A **+ (create event)** button in the Fights tab navigation bar.
- Host-owned events gain a **Manage** action in their detail view.

**Create / edit event** — a form covering title, description, event type, location name, address, date and time, and preparation notes.
- **[DECISION]** Location is entered as free text plus an optional map pin. No address autocomplete in v1 — that is a Places API dependency and a cost centre. Lat/lng captured from the pin for the v2 map view.
- Events save as `draft` and require explicit **Publish**, so a half-written event never appears in the public list.
- Editing a published event is permitted; **cancelling is not deletion** — status moves to `cancelled` and it stays visible to anyone signed up.

**Manage event** — signup count, attendance count, and the attendee roster (host-visible only, §10).

**Scan attendees** — full-screen QR scanner, running tally, clear per-scan success and failure feedback. Requires connectivity (§9.11).

**[OPEN]** Whether an organisation account should be able to attend and be checked into *another* organisation's event. Recommend yes; no reason to prevent it.

### 6.6 Profile — Tab 4
- Avatar, display name, member-since. Organisation accounts show a verified marker.
- Lifetime **counts**, not balances: habits logged, Fights attended, Foundations completed, longest streak, peak Vitality.
- Category breakdown chart.
- **Badge wall** (§7).
- Past Fights history.
- Settings: notifications (daily reminder, decay warning, Fight reminders — see §9.4), account, privacy, sign out, delete account.

---

## 7. Badges

**[DECISION]** Seven badge families. All criteria are based on **counts of actions**, never on point totals — there is no point total to threshold against.

| Family | Example | Trigger |
|---|---|---|
| **Streak** | Fortnight, Century | N consecutive days meeting the daily target |
| **Category mastery** | Water Guardian | Log every habit in a category at least once |
| **Volume** | Hundred Acts | N habits logged, cumulative |
| **Vitality** | Flourishing | First time reaching Stage 5 |
| **Foundation** | Groundwork | Complete N Foundations |
| **Fight** | First Fight, Frontliner | Attend N events; type-specific variants (Reef Keeper, Mangrove Hand) |
| **Seasonal** | Earth Day 2026 | Time-boxed challenges |

Three states: locked (silhouette), in-progress (progress bar), earned.

### 7.1 Badge wall sharing
- Always-available export, not a periodic recap. **[DECISION]** — a Wrapped-style annual recap needs a year of data the app won't have by exhibit.
- Renders a shareable image: earned-badge grid, headline stat, Earth stage illustration, wordmark.
- Two ratios: 9:16 (Stories) and 1:1 (feed).
- Standard `ShareLink` share sheet. No custom social integrations, no deep-link attribution in v1.

---

## 8. Admin dashboard

**[DECISION]** With host tooling moved into iOS (§6.5.1), the dashboard shrinks to **admin-only**. Organisations never open it.

Small Next.js web app, **admin-only**, out of scope for the iOS build.

**Admin capabilities:**
- Flip `isOrganization` on any user — this *is* the verification mechanism (§4.3), and the only thing that genuinely cannot live in the app.
- Manage the habit catalogue (`/habits` is client-read-only).
- Moderate or cancel any event.
- View aggregate metrics.

**[DECISION]** Same Firebase project, same Security Rules as the app. No second data model, no separate API. Admin privileges come from a **custom auth claim checked in rules** — never a client-writable field.

**Scope note:** this is now a handful of internal screens with no design requirement, and it should be built accordingly. Given that verification is a single boolean, an even leaner v1 is acceptable — set the flag directly in the Firebase console and defer the dashboard until after the exhibit. **[OPEN]** for the team.

For the exhibit, seed 3–4 plausible fictional Bali organisations (a beach cleanup collective, a mangrove NGO, a reef restoration group) with events in the near future, clearly labelled as demonstration data.

---
## 9. Technical architecture

### 9.1 Firebase — decided

**[DECISION]** Firebase (Auth + Firestore + Security Rules). **Storage is not used** — the camera stores no photos (§5.1). Supersedes the Supabase decision in 0.2/0.3; the team is already working in Firebase and familiarity outweighs the marginal advantages of Postgres for a project this size.

What Firebase gives us, and what it costs:

| | |
|---|---|
| **Sign in with Apple** | Native, one line of config |
| **Offline persistence** | Built in and battle-tested — significant, given §9.5 |
| **Security Rules** | Server-enforced authorization without deploying anything |
| **Cost — weaker queries** | No joins, no transactions across documents, composite indexes must be declared |
| **Cost — no geo-queries** | v2 map view needs manual geohashing; Postgres would have had PostGIS |

Neither cost bites in v1. Both are noted so the v2 map work isn't a surprise.

### 9.2 There is no application server

**[DECISION]** All business logic runs on-device. Firebase provides authentication, authorization, and data persistence. **There is no application server and no Cloud Functions in v1.**

The precise phrasing matters, and the team should use it verbatim when asked:

> **Business logic runs on-device. Firebase provides authentication, authorization, and data storage. There is no application server.**

"All logic on the phone" is the wrong summary — it invites *"so anyone can cheat?"* and misrepresents the design. **Security Rules execute on Google's servers, not on the device.** A modified client cannot bypass them any more than it could bypass a REST API we wrote ourselves. "No backend" means "no backend *we* deploy," not "no authorization layer."

**On-device:** Vitality math, daily point totals, streaks, Shield, Foundations, badge evaluation, habit catalogue, ML visual search, Fight browsing, signup, event creation and management, notification scheduling.

**Server-side (Firebase):** identity, authorization rules, data durability.

### 9.3 Check-in without server code

In the Supabase design, attendance required one stored procedure, because the host awarding Vitality to an attendee is a cross-user write. Firestore has no stored procedures, so the direct port would need a Callable Cloud Function.

**[DECISION]** Restructure instead, and eliminate the server logic entirely.

The host never writes to the attendee's record. The host writes only an **attendance document**:

```
/attendance/{eventId}_{userId}
    eventId, userId, checkedInAt, checkedInBy
```

- The **composite document ID gives uniqueness for free** — a duplicate check-in is a write to an existing document, which rules reject. No unique constraint needed, no race.
- **Security Rules enforce** that only the event's host may create it, that the attendee is genuinely signed up, and that the document is immutable after creation.
- The **attendee's own client** reads its attendance documents and applies +10 Vitality when computing that day's delta.

This does not weaken the trust model, because Vitality is already client-authoritative by design (§9.6). The attendance record is the source of truth; Vitality is derived from it on-device, exactly like every other number in the app.

**Result:** zero server code, zero cold starts, zero deploy target.

### 9.4 Notifications — local, not push

**[DECISION]** v1 ships **local notifications** via `UNUserNotificationCenter`. No APNs certificates, no FCM, no Cloud Functions. Reversed from the 0.3 decision to defer notifications entirely: the decay warning does real retention work and is nearly free to build.

| Notification | Mechanism |
|---|---|
| Daily reminder | Repeating calendar trigger |
| "Your Earth is decaying" | Scheduled at the end of the evaluation loop; **cancelled when the user hits the target** |
| Streak about to break | Same optimistic-schedule-then-cancel pattern |
| Upcoming Fight | Scheduled at signup, cancelled on cancellation |

The pattern for anything conditional: **schedule optimistically, cancel on the good outcome.** The app can't wake at 9pm to check whether the user logged, but it can schedule the nag in advance and remove it by identifier (`removePendingNotificationRequests`) the moment the target is met.

**Genuinely requires push, therefore deferred:** a new Fight posted nearby, a host cancelling an event. A Firestore listener catches cancellations while foregrounded, which is sufficient for v1. True push is a Cloud Function on a Firestore trigger (~30 lines) whenever it becomes worth it.

### 9.5 Streaks and the evaluation loop

The streak is **not** a counter incremented on logging. That version cannot notice days on which nothing happened. It is derived in the same daily pass that computes Vitality.

```swift
func evaluate(context: ModelContext) {
    var day = user.lastEvaluatedDate
    let yesterday = Calendar.current.startOfDay(for: .now)
        .addingTimeInterval(-86400)

    while day < yesterday {
        day = Calendar.current.date(byAdding: .day, value: 1, to: day)!

        let points = pointsLogged(on: day)
        let shielded = isShielded(day)

        if shielded {
            // streak preserved, not extended
        } else if points >= 30 {
            user.currentStreak += 1
            user.longestStreak = max(user.longestStreak, user.currentStreak)
        } else {
            user.currentStreak = 0
        }

        applyVitalityDelta(points: points, shielded: shielded)
        user.lastEvaluatedDate = day
    }
}
```

**The loop is idempotent**, which is the entire reason it works without a scheduler. Nine days offline runs it nine times and correctly zeroes the streak. Two launches a minute apart make it a no-op, because `day < yesterday` is already false.

Three implementation requirements:

- **Today is not evaluated** — the loop stops at yesterday, because today isn't over. `currentStreak` is therefore a *settled* value, and the dashboard must display `currentStreak + (todayHitTarget ? 1 : 0)`. Otherwise a user who just hit their target sees the number stall until midnight and concludes it's broken.
- **`localDate` is written at log time** as a plain `YYYY-MM-DD` string, never derived later from a timestamp. A user who logs in Bali and reopens in Dublin must not have their history shift.
- **Guard backward clock changes** — if `lastEvaluatedDate` is in the future relative to now, skip evaluation rather than rewinding. Forward-skipping only damages the user's own Earth and isn't worth defending against.

**[OPEN]** Multi-device double-counting. Two devices each running the loop will both advance the streak. Firestore last-write-wins mostly papers over it; the clean fix is to derive the streak fresh from logs on every launch rather than storing it. Worth doing if iPad ever ships.

### 9.6 Security model

Security in this app is real work, but it is not shaped like a backend. It is the **rules file**, and that file deserves more care than configuration usually gets — **it is the only enforcement layer in the system.**

**Why no server-authoritative writes in v1.** A backend's job is protecting things of value. Run this app against that list:

| Concern | Status |
|---|---|
| Secrets in the client | None — Firebase client config is public by design |
| User-generated media | None — no photos are stored anywhere (§5.1) |
| Anything spendable | None — points reset daily, nothing is redeemable |
| Cross-user writes | One (check-in), handled by rules and composite IDs |
| Worst-case attack | A user forges their own Vitality and their own Earth looks nicer |

That last row is the whole argument. **Cutting vouchers in 0.2 cut the threat model.** There is no leaderboard to poison, no reward to steal, and no other user harmed. Vitality is client-authoritative, and that is an accepted, documented risk rather than an oversight.

**Rules requirements (must be met before launch):**
- Users may read and write only their own documents.
- `habit_logs` are immutable after creation; deletion permitted only same-day.
- Attendance documents: host-only creation, no self-check-in, event ownership verified, immutable after write.
- Event documents: writable only by the hosting organisation account.
- `is_organization` is **not** user-writable under any circumstances.
- Event documents may be created only by accounts with `isOrganization == true`, and edited only by the owning host.
- **Firebase Storage is not enabled.** No rules surface, no photo access to secure.

**Rules must have tests.** Use `@firebase/rules-unit-testing` against the emulator. A rules bug fails *silently* — no exception, no log, just a permission that shouldn't exist. That makes it more dangerous than a server bug, which at least throws. This is a named deliverable, not a nice-to-have.

### 9.7 Forward compatibility

Two constraints, cheap to honour now and expensive to retrofit. Both are good architecture independent of any future backend.

**1. Every write goes through a repository layer.** All logging flows through a `HabitRepository` — never `context.insert()` scattered across views. When writes eventually move server-side, one file changes instead of thirty. This is also what makes the logic testable.

**2. Never store a derived total.** `habit_logs` is authoritative; everything else is computed from it. Do not cache a lifetime point total, a habit count, or anything else summable. Derived state can be recomputed server-side later; stored state must be either trusted or discarded.

Honour both and adding a backend is roughly a week of mechanical work. Skip them and it is a rewrite — not because backends are hard, but because logic will have leaked into views.

### 9.8 When to build a backend

Not now. The failure mode that kills a launch here is shipping late with a mediocre Earth animation because two weeks went into Cloud Functions. Retention depends on whether the planet feels alive, not on whether points are server-validated.

**Triggers — any one of these, and server-authoritative writes become required:**

| Trigger | Why |
|---|---|
| **Leaderboards or public comparison** | The moment one user's number is measured against another's, cheating harms someone else. Most likely trigger. |
| **Individual (non-org) event hosting** | Vetting who may gather strangers in a physical place cannot be client-side |
| **Any monetisation** | Sponsorship, premium, partner rewards — anything at all |
| **User-generated event content** | Free-text and photos eventually need a moderation queue |

**Migration cost, honestly:**

- *Trivial* — anything additive. Notifications, vetting flows, moderation queues. New functions on new data; nothing existing changes.
- *Awkward* — inverting existing writes. The client stops writing and starts calling; every call site, the offline queue, and the optimistic UI all change. About a week, and tedious.
- *Unfixable* — **historical data.** Every row written before server validation was client-authoritative and cannot be retroactively verified. If leaderboards launch on top of it, a user who inflated their Vitality in month two keeps that advantage permanently.

**The consequence:** if leaderboards are genuinely on the roadmap, server-validate log writes **before** they ship, not after. This is the one decision that cannot be deferred and then fixed.

### 9.9 Trust and safety

Distinct from security, more important than it, and not a backend problem.

**The app puts strangers in physical locations together.** That is the genuine risk surface — considerably more real than point inflation, and no amount of server code addresses it.

Mitigations in v1:
- **Verified organisations only** may host (§4.3). Individuals cannot.
- **Verification is manual and human.** This is a feature, not a limitation: a person confirming an NGO actually exists beats any automated check.
- **Attendee lists are private**, visible only to the host (§10).
- Signup discloses only the display name, and only to that host.

**[OPEN]** A reporting mechanism for events or hosts. Not required for the exhibit with fictional organisations; **required before any real event is listed.**

### 9.10 Stack

| Layer | Choice |
|---|---|
| UI | SwiftUI |
| Local persistence | **`Codable` blob on disk through Phase 9**; SwiftData only if a query needs it (§13) |
| Cloud | Firebase Auth + Firestore (**no Storage**) |
| Authorization | Firestore Security Rules (+ emulator tests) |
| Server logic | **None** |
| Notifications | `UNUserNotificationCenter` (local only) |
| ML runtime | Core ML — MobileCLIP-S2 image tower, **zero-shot** against precomputed text vectors. Inference in memory only |
| Camera / QR | AVFoundation |
| Charts | Swift Charts |
| Dashboard | Next.js + Firebase JS SDK |
| Project structure | Single Xcode target, file-system synchronized groups, no local SPM packages (§9.13) |

### 9.11 Offline behaviour

**[DECISION]** Optimistic-local-first:

- Habit catalogue bundled with the app. Works with zero network.
- Logging writes locally and immediately; UI updates instantly.
- **Through Phase 9 there is no network at all** — the app is wholly local, and everything below describes the post-Phase-10 state.
- Firestore offline persistence handles the sync queue.
- **Vitality is computed and owned client-side.** The server stores the result but never recomputes it. Multi-device conflict resolves last-write-wins on `lastEvaluatedDate`.
- Camera search and all notification scheduling are fully on-device and work offline.
- **Event creation requires connectivity** — a draft event written offline would be invisible to signups and confusing to the host.
- **Fight check-in requires connectivity on the host device.** Rules cannot validate an offline write.
- Fight browsing works from cache; signup requires connectivity.

### 9.12 Data model (abridged)

Firestore collections. Nested paths indicate subcollections.

```
/users/{uid}
    displayName, createdAt, timezone,
    isOrganization, orgName, orgDescription, orgLogoUrl,
    vitality, shieldBalance,
    currentStreak, longestStreak, lastEvaluatedDate

/users/{uid}/habitLogs/{logId}
    habitId, loggedAt, localDate,
    pointsAwarded,
    source (manual | camera)

/users/{uid}/vitalityHistory/{localDate}
    pointsEarned, delta, vitalityAfter, shielded, fightAttended

/users/{uid}/badges/{badgeKey}
    earnedAt, progress

/habits/{habitId}              — read-only to clients
    title, category, tier, frequencyType, weeklyLimit,
    shortDescription, howTo, impactStatement, impactSource,
    mlClassLabel, pointsBase, isActive

/events/{eventId}
    hostUserId, title, description, eventType,
    locationName, address, latitude, longitude,
    startsAt, endsAt, preparationNotes, status

/events/{eventId}/signups/{uid}
    signedUpAt, checkinToken, cancelledAt

/attendance/{eventId}_{uid}
    eventId, userId, checkedInAt, checkedInBy
```

**Notes:**
- `habitLogs` is authoritative. Daily point totals are a sum over `localDate`; nothing is cached (§9.7).
- `/attendance` is top-level rather than nested so the composite ID enforces uniqueness (§9.3).
- `/habits` is client-read-only, written only via the admin dashboard.
- `latitude` / `longitude` are captured from day one purely to enable the v2 map view; nothing in v1 reads them.
- **Composite indexes required:** events by `status` + `startsAt`, and by `eventType` + `startsAt`. Declare these early — Firestore fails the query rather than degrading.

### 9.13 Code architecture and collaboration

Three or four people build this in parallel over roughly ten weeks. The layout below is chosen for that constraint specifically, not for architectural elegance.

**The enabling fact.** The Xcode project uses `objectVersion = 77` with a **`PBXFileSystemSynchronizedRootGroup`** (Xcode 16+). Adding, renaming, moving, or deleting a Swift file **does not modify `project.pbxproj`** — the folder on disk *is* the group. Historically that file was the worst merge conflict in iOS team development; here it is already solved.

**The consequence: files are free.** There is no cost to giving a view its own file, and every split removes one place two people can collide. Prefer many small files. Do not add files by dragging them into the Xcode navigator the old way — create them on disk.

#### 9.13.1 One file per what

**[DECISION]** **One file per screen or per type.** Not one file per feature, and not one file per function.

- A view over ~300 lines is a signal to extract subviews, not a rule.
- Extract when a piece is *reused* or *separately owned* — not when it is merely long.
- Private helper views used by exactly one screen stay in that screen's file. Splitting those makes navigation worse and buys nothing.

#### 9.13.2 No shared god object

**[DECISION]** There is no single app-wide store that every feature reads and writes.

A shared `AppState` holding auth, catalogue, logs, points, streaks, badges, and events is the file all three developers edit every day. It produces a daily merge conflict in the most logic-dense code in the project, and it is the main thing preventing parallel work.

Three layers instead, which is also how §9.7's repository requirement is satisfied:

| Layer | Rule |
|---|---|
| **Engines** — `PointsEngine`, `VitalityEngine`, `EvaluationLoop` | Pure functions over values. **Never import SwiftUI. No I/O.** The only code that needs unit tests. |
| **Repositories** — `HabitRepository`, `UserRepository`, `FightRepository` | The only code that reads or writes storage. Every write goes through one (§9.7). |
| **Feature view models** — one per feature, `@Observable` | Owned by that feature's owner. Views talk to these, never to storage. |

A view never touches storage directly. An engine never imports SwiftUI. Those two sentences are the whole architecture.

#### 9.13.3 Layout

```
Eco-Habbit/
├── App/                  Eco_HabbitApp · RootView · MainTabView
├── Core/
│   ├── Models/           Habit · HabitLog · UserState · Fight · Signup · Badge
│   ├── Engine/           PointsEngine · VitalityEngine · EvaluationLoop
│   ├── Repositories/     HabitRepository · UserRepository · FightRepository
│   └── Persistence/      SwiftDataStack · FirestoreSync
├── DesignSystem/         Theme · Tokens · Components · GlobeView · FontLoader
├── Features/
│   ├── Auth/             SignInWithAppleView
│   ├── Earth/            EarthDashboardView · EarthDetailSheet · EarthViewModel
│   ├── Habits/           HabitListView · CategoryDetailView · HabitDetailView
│   │                     FoundationsView · HabitsViewModel
│   ├── Camera/           VisualSearchView · CameraService · HabitClassifier · ChipRow
│   ├── Fights/           FightListView · FightDetailView · MyFightsView · CheckInQRView
│   │   └── Host/         EventFormView · ManageEventView · ScannerView
│   └── Profile/          ProfileView · BadgeWallView · ShareCardView · SettingsView
├── Resources/
│   ├── habits.json       the 50-habit catalogue — content, not code
│   └── Fonts/
└── Debug/                TimeTravelMenu (§13 Phase 2)

Eco-HabbitTests/          VitalityEngineTests · EvaluationLoopTests · PointsEngineTests
```

Features are **vertical slices**: a feature folder holds its own views and its own view model together. Organising by layer instead (`Views/`, `ViewModels/`, all features mixed) means every feature's work is spread across four folders and every folder has four editors.

#### 9.13.4 Ownership

**[DECISION]** One named owner per feature folder. The owner edits it freely; everyone else opens a PR.

| Area | Owner |
|---|---|
| `Core/` — models, engines, repositories | **[OPEN]** — changes ripple; review everything |
| `DesignSystem/` | **[OPEN]** — additive changes only |
| `Features/Earth/` + `Features/Habits/` | **[OPEN]** — the critical path |
| `Features/Camera/` | **[OPEN]** — independent; blocks nothing |
| `Features/Fights/` + `Host/` | **[OPEN]** — largest net-new surface |
| `Resources/habits.json` | **[OPEN]** — content owner, see §3.5 |

Three files everyone eventually touches — `MainTabView`, `Theme`, `habits.json` — keep boring, and announce edits.

#### 9.13.5 The catalogue is data, not Swift

**[DECISION]** The 50 habits ship as **`Resources/habits.json`**, decoded once at launch and seeded into SwiftData (§13 Phase 1).

50 habits × 9 fields — including a sourced impact statement and a citation URL — is a ~500-line Swift array edited by whoever does content research (§3.5), who then must not break the build. As JSON: content edits stop being code edits, conflicts merge line-by-line rather than as Swift syntax, and the same file seeds Firestore `/habits` in Phase 3 unchanged.

#### 9.13.6 No local Swift packages

**[DECISION]** **One target, folder conventions.** No local SPM modules in v1.

Package boundaries buy compile-time enforcement in exchange for manifests, `public` annotations on every cross-module symbol, slower incremental builds, and periodic resolution failures. At this team size, folder conventions and code review get the same boundaries for free. Revisit if the team passes ~6 people or the app ships commercially.

#### 9.13.7 Repository hygiene

- **Per-user Xcode state must not be tracked.** `xcuserdata/` and `*.xcuserstate` are binary, change on every Xcode launch, and cannot be merged. `.gitignore` only covers untracked files — anything already committed needs `git rm --cached`. Commit a **shared scheme** (`xcshareddata/`) so the build config is still uniform.
- **`GoogleService-Info.plist` is committed, not ignored.** §9.6 states the Firebase client config is public by design. Ignoring it just means every teammate hits a build failure on first clone. `.env` stays ignored.
- One `.gitignore`, at the repository root.
- `main` protected; short-lived `feature/<area>-<thing>` branches; PR plus one review; rebase over merge.

## 10. Privacy

- **No photos are stored, uploaded, or retained anywhere.** Camera frames are processed in memory for inference and discarded (§5.1). There is no retention question, no Storage bucket, and no moderation surface for user media.
- Camera inference is on-device; images never leave the device, let alone reach a third-party ML service.
- **Attendee lists are visible only to the event host and admins**, never to other attendees.
- Signing up for a Fight discloses the user's display name to that host. Stated at signup.
- Account deletion cascades to logs, history, signups, attendance, and any events the account hosts. **[OPEN]** — Firestore has no cascading delete; this needs either a client-side sweep before sign-out or the one Cloud Function we would otherwise not deploy.
- Privacy manifest and **camera usage description** required for App Store review. **No photo library usage description** — the app never touches the library.

---

## 11. Out of scope for v1

| Item | Why deferred |
|---|---|
| Vouchers, partners, redemption | **Cut in 0.2.** No real-world reward at all |
| Any spendable or accumulating currency | **Cut in 0.3.** Competes with the Earth for attention |
| **True push** (new Fight nearby, host cancellation) | Requires a Cloud Function; local notifications cover v1 (§9.4) |
| Leaderboards or public comparison | **Would require server-authoritative writes first** (§9.8) |
| Reporting mechanism for events and hosts | **Required before any real event is listed** (§9.9) |
| Individual (non-org) event hosting | Trust-and-safety system, not a feature |
| Event capacity limits and waitlists | Returns in v2 with real events |
| Map view and distance filtering for Fights | Chronological list is sufficient; lat/lng captured now |
| Evidence photos of any kind | **Cut in 0.5.** Never real verification; cost a storage dependency and a privacy surface |
| Event photos and recaps | Adds moderation surface |
| Public attendee lists, comments, friends, leaderboards | Whole additional product surface |
| Per-biome Earth (category-mapped) | 6× art cost |
| Custom user-created habits | Distorts the catalogue and the badge criteria |
| Retroactive logging / streak repair | Undermines evidence integrity |
| Bahasa Indonesia localisation | Should be a fast follow given the target market |
| Android | Academy is iOS |
| Monetisation | No business model in v1 by design |
| Annual Wrapped-style recap | Requires a year of data |

---

## 12. Open questions

| # | Question | Owner | Blocking? |
|---|---|---|---|
| 1 | Earth art pipeline and asset production | Design | **Yes** — long pole |
| 2 | Habit content research (50 × sourced impact) | — | **Yes** |
| 3 | ~~ML training data collection~~ — **closed in 0.6.** Zero-shot needs no photos (§5.2) | — | ~~Yes~~ |
| 4 | Exhibit demo plan for Fights (see §12.1) | — | **Yes** |
| 4a | Folder ownership assignments (§9.13.4) — all six | Team | **Yes** — Phase 0 |
| 4b | Product name: keep `Eco-Habbit` or rename to `Terra`. Costs an hour in Phase 0, a day in week 5 | Product | **Yes** — Phase 0 |
| 4c | Team-neutral bundle identifier (currently a personal one) | Eng | **Yes** — Phase 0 |
| 5 | Is 30 points the right daily target, and 60 the right cap | Product | No |
| 6 | Chip threshold — 0.15 is set from text-only data and **must be retuned on real photographs** (§5.2) | ML | No |
| 6a | Whether to extend past the 18 shipped habits — costs only prompts now (§5.2) | ML | No |
| 6b | Ship the admin dashboard, or use the Firebase console for the exhibit (§8) | Product | No |
| 7 | Check-in window bounds (−1h / +3h) | Product | No |
| 8 | Offline fallback for check-in at no-signal venues | Eng | No |
| 8a | Reporting mechanism for events/hosts — blocking before any *real* event | — | Exhibit: no |
| 8b | Account-deletion cascade strategy in Firestore | Eng | No |
| 8c | Multi-device streak double-counting (§9.5) | Eng | No |
| 12 | Accelerating decay curve | Product | No |
| 13 | Post-exhibit success metrics | Product | No |

### 12.1 The exhibit problem with Fights
Fights are the only feature requiring a physical place at a physical time, so a visitor cannot organically experience one. Plan for this deliberately rather than discovering it the week before:

- Seed a fictional organisation with an event whose check-in window is open for the entire exhibit.
- Run a second device in host mode at the booth so a visitor can sign up, show their QR, and be scanned live.
- This demonstrates the full loop end to end and is far more compelling than static screens.

---

## 13. Suggested build sequence

**[DECISION]** Local-first, Firebase later. This inverts the conventional "schema → backend → client" order, deliberately.

The Firestore schema is a serialisation of the SwiftData model. Designing it before the logic exists means guessing at a shape that would otherwise be *discovered* — and Firestore migrations are irritating enough that guessing twice is expensive. More practically: the alternative order means two weeks with nothing demonstrable, debugging sync against logic that was never validated.

**Phase 0 exists because a prototype already does.** The current SwiftUI prototype was built against 0.1 and is structured around two currencies, cumulative points, evidence photos, and vouchers — all of which 0.2, 0.3, and 0.5 removed. Its design system, globe view, onboarding shell, and camera session plumbing all survive; its economy and persistence do not. Teardown is a discrete, blocking, one-PR job, and half-migrated is worse than either end state. See `REWORK-PLAN.md` for the file-level detail.

| Phase | Deliverable | Firebase? |
|---|---|---|
| 0 | **Teardown and scaffold.** Delete vouchers, evidence, second currency, streak multipliers. Rename `Activity`→`Habit`. Split the shared store into engines and repositories (§9.13.2). Establish the §9.13.3 layout. Repository hygiene (§9.13.7). Green build that does less | No |
| 1 | **One vertical slice, fully local.** SwiftData models for `Habit` and `HabitLog`, 50 habits seeded from bundled JSON, habit list, checkbox logging, Vitality engine, text-only dashboard | No |
| 2 | **Time-travel debug menu.** Advance `lastEvaluatedDate` manually; validate the evaluation loop against missed days, timezone rollover, Shield, streak breaks | No |
| 3 | Earth visualisation and stage transitions | No |
| 4 | ML data collection → head training → Core ML export | No |
| 5 | Camera visual search: live viewfinder, chip UI | No |
| 6 | Fights: browse, detail, signup, QR generation — against a local seeded event | No |
| 7 | Host mode: event create/manage, scanner, attendance | No |
| 8 | Local notifications | No |
| 9 | Badges, badge wall, share export | No |
| 10 | **Firebase.** Auth (Sign in with Apple), mirror the settled models into Firestore, **Security Rules and their emulator tests**. Cross-device check-in becomes real here | Yes |
| 11 | Offline hardening, polish, demo seeding | Yes |

**[DECISION] Firebase moved from Phase 3 to Phase 10 in 0.6.** Every feature is built and proven on-device against bundled JSON first; the cloud arrives once there is nothing left to discover about the data shape.

This is the same argument §13 already opens with, taken to its conclusion. The Firestore schema is a serialisation of the local model — designing it while the model is still moving means migrating Firestore every time a feature teaches us something, and Firestore migrations are irritating enough that guessing twice is expensive. Deferring also means the team debugs Fights, badges and notifications against a file on disk rather than through a sync layer, which is the difference between a print statement and an afternoon.

**The cost, stated plainly:** attendance check-in is a cross-user write (§9.3) and **cannot be genuinely exercised before Phase 10.** Until then Phase 6–7 run against a locally seeded event with a simulated scan, which proves the flow but not the security model.

**Therefore Phase 10 is not the last phase, and must not slip into the final week.** The exhibit demo (§12.1) needs two devices talking to each other, so Firebase plus Rules needs to land with enough runway to test a real check-in between two phones. Treat "Phase 10 complete" as the exhibit-readiness gate, not Phase 11.

**End of Phase 1 test:** log a habit, watch a number move, force-quit, reopen, the number persisted. That is the entire product proven with zero cloud dependency.

**Phase 2 is where the bugs live.** The evaluation loop is the most subtle code in the app, and it is far easier to debug at 300 lines with no network than later through a sync layer.

**Phases 3 and 4 are independent and must run in parallel.** Phase 4 has the longest unavoidable calendar time because of data collection — **start shooting training photos in week 1**, regardless of where the rest of the build stands. It blocks nothing and nothing blocks it.

**Phases 6 and 7 should be built against a seeded fictional event from the start**, so the exhibit demo path (§12.1) is exercised continuously rather than assembled at the end.

**Repository layer from Phase 0** (§9.7, §9.13.2) — established during teardown, not retrofitted later. Brought forward from Phase 1 in 0.6: the split is most of the teardown work anyway, and doing it twice is pointless.

**Parallel work starts at Phase 2.** Phase 0 blocks everyone and Phase 1 is one vertical slice — both are single-owner jobs. Once the engines, repositories, and folder boundaries exist (§9.13), Camera, Fights, and Earth proceed independently. Trying to parallelise before then just means three people editing the same files.
