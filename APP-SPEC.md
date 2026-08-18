# Eco-Habit — App Specification (gameplay & features)

**Source:** branch `MockData`

**Scope:** what the app *does* from the user's side. No file names, no architecture. Every number here is a real number the app uses today.

---

## 1. The idea in one paragraph

You log small sustainable things you did today — brought a bottle, took the bus, sorted your rubbish. Each one is worth points. Points accumulate into a single lifetime score, and that score drives one image: the state of the Earth, which climbs through six stages from **Critical** to **Restored**. Keeping a daily streak multiplies what you earn. Stopping for more than a week starts eating the score back down. Community events are worth far more than daily actions, but are capped so they can't replace the habit.

**The core loop:** open app → see Earth stage and streak → log 1–5 actions → points go up → stage inches closer.

---

## 2. The action catalogue — 38 daily actions

Six fixed categories. Every action belongs to exactly one.

| Category | Actions | Points range |
|---|---|---|
| Food & Consumption | 8 | 5–15 |
| Water | 6 | 5–20 |
| Waste Management | 7 | 5–20 |
| Energy | 6 | 5–10 |
| Mobility | 6 | 10–15 |
| Actions (advocacy/learning) | 5 | 5–20 |
| **Total** | **38** | |

### Base points come from effort, not from category

Every action is graded on how much effort it takes. That grade *is* the point value — there is no per-action tuning.

| Effort | Meaning | Base points |
|---|---|---|
| **F1** | Almost no effort — a decision you make in a second | **5** |
| **F2** | Small deliberate change to your routine | **10** |
| **F3** | Needs planning or a detour | **15** |
| **F4** | Costs money, time, or a trip | **20** |

### Full catalogue

| # | Action | Category | Effort | Points | Photo evidence | Repeat |
|---|---|---|---|---|---|---|
| 1 | Bring a reusable bottle | Food | F1 | 5 | **Direct** | Daily |
| 2 | Bring a reusable shopping bag | Food | F1 | 5 | **Direct** | Daily |
| 3 | Refuse single-use cutlery/straw | Food | F1 | 5 | None | Daily |
| 4 | Bring your own food container | Food | F2 | 10 | **Direct** | Daily |
| 5 | Finish your food | Food | F2 | 10 | Contextual | Daily |
| 6 | Buy local products | Food | F2 | 10 | Contextual | Daily |
| 7 | Eat a plant-based meal | Food | F2 | 10 | Contextual | Daily |
| 8 | Buy secondhand | Food | F3 | 15 | Contextual | Daily |
| 9 | Turn off tap while brushing | Water | F1 | 5 | Contextual | Daily |
| 10 | Shorter shower (< 5 min) | Water | F2 | 10 | Contextual | Daily |
| 11 | Reuse washing water for plants | Water | F2 | 10 | Contextual | Daily |
| 12 | Wash full loads only | Water | F2 | 10 | Contextual | Daily |
| 13 | Collect rainwater | Water | F3 | 15 | Contextual | Daily |
| 14 | Fix a leaking tap | Water | F4 | 20 | Contextual | **Every 30 days** |
| 15 | Refuse plastic bag | Waste | F1 | 5 | None | Daily |
| 16 | Choose digital receipt | Waste | F1 | 5 | None | Daily |
| 17 | Segregate organic/inorganic waste | Waste | F2 | 10 | Contextual | Daily |
| 18 | Compost food scraps | Waste | F3 | 15 | Contextual | Daily |
| 19 | Refill household product | Waste | F3 | 15 | Contextual | Daily |
| 20 | Repair instead of replacing | Waste | F4 | 20 | Contextual | **Every 7 days** |
| 21 | Drop off waste at bank sampah | Waste | F4 | 20 | Contextual | Daily |
| 22 | Turn off unused lights | Energy | F1 | 5 | Contextual | Daily |
| 23 | Unplug idle chargers | Energy | F1 | 5 | Contextual | Daily |
| 24 | Turn off monitor when away | Energy | F1 | 5 | Contextual | Daily |
| 25 | Wash clothes with cold water | Energy | F2 | 10 | Contextual | Daily |
| 26 | Air-dry clothes | Energy | F2 | 10 | Contextual | Daily |
| 27 | Set AC to 24°C or above | Energy | F2 | 10 | Contextual | Daily |
| 28 | Combine errands into one trip | Mobility | F2 | 10 | None | Daily |
| 29 | Walk instead of riding | Mobility | F2 | 10 | None | Daily |
| 30 | Carpool / ride-share | Mobility | F2 | 10 | Contextual | Daily |
| 31 | Skip commute (WFH) | Mobility | F2 | 10 | None | Daily |
| 32 | Take public transport | Mobility | F3 | 15 | **Direct** | Daily |
| 33 | Cycle instead of motor vehicle | Mobility | F3 | 15 | **Direct** | Daily |
| 34 | Complete in-app learning card | Actions | F1 | 5 | None | Daily |
| 35 | Share your progress | Actions | F1 | 5 | None | Daily |
| 36 | Educate someone about local issue | Actions | F2 | 10 | None | Daily |
| 37 | Regional daily mission | Actions | F3 | 15 | None | Daily |
| 38 | Visit refill station / bank sampah | Actions | F4 | 20 | Contextual | Daily |

**Repeat rules:** each action can be logged **once per calendar day**. Two of them have a longer cooldown (fixing a tap, repairing something) because doing them daily isn't credible. Logging the same action twice in a day is silently refused — it shows as already done, no extra points, no error.

---

## 3. How points are calculated

```
final points  =  base points  ×  streak multiplier  ×  region bonus
```

| Multiplier | Value | When |
|---|---|---|
| **Streak multiplier** | ×1.0 → ×1.5 | See §4 |
| **Region bonus** | ×1.3 | Action matches your province's priority — **not active yet** |
| | ×1.0 | Everything else, today |

**There is no photo bonus.** Logging with the camera and tapping the checklist are worth exactly the same. Photos still count toward the "Proof in Pictures" badge — they just don't multiply anything.

### The daily cap: 100 **base** points

The cap is applied to base points, **before** multipliers. Once you've logged 100 base points of actions in a day, further actions still get recorded and still count toward badges and your streak, but earn 0.

This means **your daily point total can exceed 100.** That is intentional: 100 base × 1.5 streak = **150 points** in a day for a long-streak user. If the cap were applied to the final number, a 60-day-streak user would hit the ceiling *faster* than a beginner, and the streak reward would feel like a punishment.

Roughly, 100 base points a day is **5–20 actions** depending on effort level.

### Worked examples

| Situation | Maths | You get |
|---|---|---|
| Beginner taps "reusable bottle" | 5 × 1.0 | **5** |
| Day 7 streak, same action | 5 × 1.1 | **6** |
| Day 30 streak, same action | 5 × 1.35 | **7** |
| Day 30 streak, F2 action | 10 × 1.35 | **14** |
| Day 60 streak, F4 action | 20 × 1.5 | **30** |
| Full day, day-60 streak | 100 × 1.5 | **150** |

### What the user sees before they tap

Each row in the actions list shows the **real** number — base points with the streak multiplier already applied — plus a `×1.35` tag when a bonus is active. Once the daily cap is spent, rows read `+0` rather than quoting a number that won't be paid. A row that is already ticked shows what it actually earned.

Below day 7 there is no multiplier, so a new user sees plain base points and no extra chrome.

---

## 4. Streaks

A streak counts **days on which you logged at least one action** — not the number of actions. Five actions in a day is still one day.

### Multiplier tiers

| From day | Multiplier |
|---|---|
| 1 | ×1.0 |
| 7 | ×1.1 |
| 15 | ×1.2 |
| 30 | ×1.35 |
| 60 | ×1.5 (maximum) |

The new streak applies immediately to the action that earned it — logging on day 7 gives you ×1.1 on *that* action, not starting tomorrow.

### Breaking it

| Gap since last log | What happens |
|---|---|
| Same day | No change |
| 1 day (yesterday) | Streak +1 |
| 2 days (missed exactly one) | **Freeze** used if available → streak +1 as if nothing happened. Otherwise reset to 1 |
| 3+ days | Reset to 1. Freeze does not help |

**Streak freeze: one per calendar month**, refreshing on the 1st. It covers exactly one missed day and no more. A freeze that covered any-length absence would let someone vanish for three weeks with a 60-day streak intact while decay ate their points — two systems telling the user contradictory things.

### Displayed streak vs. real streak

If you missed two days and have no freeze, the app shows **0** the moment you open it — it doesn't show your old 12 until you log something. Showing a streak you've already lost is lying to the user.

---

## 5. The Earth — six stages

Your **lifetime point total** (after decay) picks one of six stages. This is the single visual that carries progress.

| Stage | Points needed | Points from previous |
|---|---|---|
| **Critical** | 0 | — |
| **Fragile** | 150 | 150 |
| **Stabilizing** | 450 | 300 |
| **Recovering** | 950 | 500 |
| **Flourishing** | 1,600 | 650 |
| **Restored** | 2,500 | 900 |

Gaps widen deliberately — early stages arrive fast to hook you, later ones are a real commitment. At an unhurried ~40 points/day, Restored takes about **two months**.

The home screen always names the stage and the points remaining to the next one, so a change in the Earth is never unexplained.

---

## 6. Decay — what happens when you stop

Checked once, **when you open the app**. Nothing runs in the background.

| Days since your last action | What happens |
|---|---|
| 0–4 | Nothing |
| **5–7** | Warning notification should fire ("your Earth is slipping") |
| 8+ | **−2% of current points per day**, compounding |

**Three brakes so it never feels hopeless:**

1. **Floor at 150 points** — decay never drops you below Fragile. A returning user is never back at zero.
2. **Maximum one stage lost per absence** — however long you're gone, one absence costs at most one stage. Measured from where you were when the absence *started*, so opening the app occasionally during a long absence doesn't drop you a stage each time.
3. **Compounding, not linear** — the loss slows down by itself. From 1,000 points: 30 days away costs ~450; another 30 costs ~250 more.

Logging anything ends the absence and resets the clock.

**Badges never decay.** Once earned, permanent — including point badges. Someone who once touched 1,000 points keeps that badge forever, even if their score later drops.

---

## 7. Community events ("Our Fights")

Real-world events run by partners and communities. Worth much more than daily actions, and deliberately capped so they can't replace the habit.

| Event scale | Duration | Points |
|---|---|---|
| **Micro** | Under an hour | **40** |
| **Standard** | Half day, organised | **75** |
| **Major** | Full-day event | **120** |

**Monthly ceiling: 150 event points.** Attendance beyond that is still recorded in full — your history honestly says "attended 6 events" and it still counts for badges — but the points stop at 150 per calendar month. Resets on the 1st.

Some events require a **check-in code** given out on site; open events can be claimed by the user directly. Each event can be claimed once.

### Sample events shipped (August 2026)

| Event | Organiser | Scale | Points | Date | Code? |
|---|---|---|---|---|---|
| Sanur Beach Clean-Up | Komunitas Peduli Pesisir | Standard | 75 | Aug 3 | Yes |
| Refill & Zero-Waste Workshop | Saraswati Coffee House | Micro | 40 | Aug 8 | No |
| Composting 101 for Beginners | Bandung Urban Farming | Micro | 40 | Aug 12 | No |
| Mangrove Planting Day | Green Ubud Resort | Major | 120 | Aug 16 | Yes |
| Bank Sampah Open Day | Bank Sampah Melati | Standard | 75 | Aug 22 | Yes |
| Car Free Day Ride | Bandung Bike Community | Micro | 40 | Aug 23 | No |
| Nusantara Sustainability Festival | Yayasan Bumi Lestari | Major | 120 | Aug 29 | Yes |

---

## 8. Badges — 15 total

Permanent once earned. Adding a badge is data only; no new rules are needed.

| Badge | Requirement |
|---|---|
| **Seven Days In** | 7-day streak |
| **One Month Strong** | 30-day streak |
| **Hundred Day Habit** | 100-day streak |
| **Water Guardian** | 50 Water actions |
| **Watt Watcher** | 40 Energy actions |
| **Mindful Plate** | 40 Food & Consumption actions |
| **Waste Sorter** | 30 Waste actions |
| **Low-Carbon Commuter** | 25 Mobility actions |
| **Voice for Change** | 20 Actions-category actions |
| **Proof in Pictures** | 25 photo-evidence logs |
| **First Step Out** | Attend 1 event |
| **Community Regular** | Attend 5 events |
| **Movement Builder** | Attend 10 events |
| **Thousand Points** | Reach 1,000 points |
| **Restored** | Reach 2,500 points |

Every badge shows a live progress bar (e.g. 34/50), so nothing is a mystery.

---

## 9. Photo evidence — what the camera can and can't confirm

Every action is graded on whether a photo can actually prove it. This decides the whole camera experience.

| Grade | Meaning | Count | Camera behaviour |
|---|---|---|---|
| **Direct** | The object in frame *is* the proof | **5** | Can log automatically when confident |
| **Contextual** | The photo shows the setting, not the deed | **23** | Always asks you to confirm |
| **Not detectable** | Nothing to photograph | **10** | Checklist only, never offered by camera |

The distinction that matters: a photo of a **tap** does not prove the tap was turned off. A photo of a **reusable bottle** does prove you have a reusable bottle. So 28 of 38 actions can appear as camera suggestions, but only **5 can ever log themselves without you tapping confirm**.

All five: reusable bottle, reusable shopping bag, own food container, public transport, cycling.

Photographed logs are worth the **same points** as a checklist tap — there is no photo bonus. They do count toward the Proof in Pictures badge.

> The camera itself is not in this branch — it comes from the `Vincent` branch. This section is the contract between the two: the catalogue decides what the camera is allowed to do.

---

## 10. Built but switched off

Two features exist in full and are deliberately inert.

**Regional priority (×1.3).** Each province nominates two priority categories; actions in those categories would earn 1.3×. Data exists for Bali (Water, Waste), Jakarta (Mobility, Energy), West Java (Waste, Water). **Dormant** — the app never asks for location, so everyone gets ×1.0. Nobody is ever *penalised* for missing location; the base value is the floor.

**Regional badges.** The badge system supports province-scoped badges; all 15 shipped ones are national. Regional ones must be cumulative, never streak-based — a regional streak punishes people who move.

---

## 11. What actually exists as a screen

| Screen | Status |
|---|---|
| **Home** — Earth image, greeting, streak, stage name, points to next stage | Built |
| **Daily Practices** — the six category cards | Built |
| **Category detail** — the actions in that category, tap to log | Built |
| **Our Fights** — events | **Placeholder** |
| **Profile** | **Placeholder** |
| Badges | No screen — data and rules exist, nothing displays them |
| Camera | Not in this branch |

The home screen currently opens on a **demo user**: 1,200 points, 30-day streak, Recovering. Placeholder — this seeds only when no saved data exists.

---

## 12. Not in this branch at all

No sign-in or accounts · no onboarding · no notifications (the 5-day warning is computed but nothing sends it) · no location permission · no cloud sync — everything is one file on the phone · no leaderboard, friends, or sharing.

---

## 13. Mapping what's really needed

Sorted by whether the demo falls over without it.

### Must have — the loop is broken without these

| Gap | Why |
|---|---|
| **Badges screen** | 15 badges, full progress tracking, zero ways to see them. Highest reward-per-effort item in the app |
| **Our Fights screen** | Events are fully working underneath — 7 events, tiers, monthly cap, check-in codes. Only the screen is missing |
| **Turn off the demo user** | A booth visitor starting at 1,200 points never sees the Earth move |
| **Something when you log** | Right now points change silently. The moment of reward is the product |

### Should have

| Gap | Why |
|---|---|
| **Profile screen** | Where badges, history, and totals belong |
| **Decay warning notification** | The warning is calculated and thrown away. Decay only motivates if you're told |
| **"You lost points while away"** | Coming back to a lower number with no explanation reads as a bug |
| **Camera** | Ready from the other branch; a faster way to log, and the only route to one badge |

### Can wait

Regional priority (needs location permission for +30% on some actions) · regional badges · cloud sync and accounts · leaderboards · the animated Earth that changes shape per stage — today all six stages show the same image, and only the text changes.

---

## 14. Every tunable number in one place

| Setting | Value |
|---|---|
| Effort → points | F1 5 · F2 10 · F3 15 · F4 20 |
| Stage thresholds | 0 · 150 · 450 · 950 · 1,600 · 2,500 |
| Streak multipliers | day 1 ×1.0 · day 7 ×1.1 · day 15 ×1.2 · day 30 ×1.35 · day 60 ×1.5 |
| Photo bonus | ×1.0 (removed) |
| Regional bonus | ×1.3 (inactive) |
| Daily base-point cap | 100 |
| Monthly event-point cap | 150 |
| Event points | Micro 40 · Standard 75 · Major 120 |
| Decay grace period | 7 days |
| Decay warning fires | day 5 |
| Decay rate | 2% per day, compounding |
| Max stages lost per absence | 1 |
| Decay floor | 150 points |
| Streak freeze | 1 per calendar month, covers 1 day |

All of these live in a single settings block and can be retuned without touching game logic — later, from the server, without shipping an update.
