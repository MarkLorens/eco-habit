"""
Generate habit_vectors.json for the Eco-Habit iOS app.

Encodes prompt ensembles with the MobileCLIP-S2 TEXT tower and writes one
L2-normalised vector per camera-searchable habit.

    ../../CameraAI/venv/bin/python generate_vectors.py

>>> READ THIS BEFORE TRUSTING ANY SCORE <<<
The text vectors below only mean anything if the .mlpackage in the iOS app is
the IMAGE tower of the SAME model. v1 vs v2, or S0 vs S2, silently produces
scores in a plausible-looking range that are pure noise.

WHAT THIS IS, ARCHITECTURALLY
-----------------------------
This is **zero-shot** CLIP. There is no trained classifier head and there are no
training photographs: a habit is described in words, the text tower turns those
words into a vector, and the app scores camera frames against them by cosine
similarity. Adding a habit costs five sentences, not fifty photos.

PRD §5.2 assumed a linear head trained on ~15-25 photos per class. Zero-shot
removes that entirely — see the note in REWORK-PLAN §3.

IDS ARE CATALOGUE IDS
---------------------
Every key in PROMPTS must be a real habit id from Resources/habits.json. That
file is the single source of truth for what a habit *is*; this one only says
what it *looks like*. The generator fails loudly on any id that has drifted.
"""

import itertools
import json
import pathlib

import open_clip
import torch

# --- MUST MATCH THE iOS .mlpackage -----------------------------------------
# MobileCLIP-S2 is v1. Its image tower is mobileclip_s2_image.mlpackage in the
# app's Resources, which is what HabitClassifier loads. Do NOT point this at
# MobileClip/mobileclip2_s0.pt — that is MobileCLIP2 (v1 vs v2 = different
# embedding space, normal-looking scores that mean nothing).
MODEL_NAME = "MobileCLIP-S2"
CKPT = "datacompdr"  # open_clip tag; downloads apple/MobileCLIP-S2-OpenCLIP and caches

HERE = pathlib.Path(__file__).parent
CATALOGUE = HERE.parent / "Eco-Habbit" / "Resources" / "habits.json"
OUT = HERE.parent / "Eco-Habbit" / "Resources" / "habit_vectors.json"
# ---------------------------------------------------------------------------

# Prompts describe WHAT THE CAMERA SEES, never what the habit means.
# CLIP has no negation, no counting, no spatial relations — every habit here has
# to be object-presence detectable. "Set AC to 25°C" and "Unsubscribe from
# marketing emails" are real habits that are simply not photographable, and they
# are correctly absent.
#
# Each entry is scenes + close-ups. The scene prompts are what 24-way ranking
# wants; the close-ups cover the other framing, where one object fills the frame.
# A plain metal spoon scored 0.21 against "a bamboo cutlery set in a cloth pouch"
# — barely over threshold — because nothing in that set described a bare object.
PROMPTS = {
    # ---- FOOD ---------------------------------------------------------------
    "food_reusable_bottle": [  # direct
        "a stainless steel water bottle",
        "an insulated metal flask",
        "a reusable water bottle with a screw cap",
        "a person holding a metal drinking bottle",
        "a photo of a refillable sports bottle",
        "a close-up of a metal water bottle",
        "a steel drinking bottle standing on a desk",
    ],
    "food_reusable_bag": [  # direct
        "a canvas tote bag",
        "a cloth shopping bag full of groceries",
        "a jute string mesh produce bag",
        "a person carrying a fabric shopping bag",
        "a photo of a reusable grocery bag on a table",
        "a close-up of a cloth tote bag",
        "a folded fabric shopping bag",
    ],
    "food_refuse_single_use_cutlery": [
        "a stainless steel drinking straw",
        "metal reusable straws in a jar",
        "a bamboo cutlery set in a cloth pouch",
        "a travel fork spoon and knife set",
        "a photo of a rolled up utensil pouch",
        "a stainless steel spoon and fork",
        "a close-up of a metal drinking straw",
    ],
    "food_own_container": [  # direct
        "a glass food storage container with a lid",
        "a stainless steel lunchbox",
        "a bento box packed with food",
        "meal prep containers stacked on a counter",
        "a photo of a packed lunch in a reusable tub",
        "a close-up of a glass food container",
        "a metal lunch tin on a table",
    ],
    "food_finish_food": [
        "an empty dinner plate with cutlery on it",
        "a clean plate after a meal",
        "an empty bowl with a spoon inside",
        "a plate wiped clean at the end of a meal",
        "a photo of an empty plate on a table",
        "a close-up of an empty white plate",
        "used cutlery resting on a finished plate",
    ],
    "food_buy_local": [
        "a farmers market vegetable stall",
        "crates of fresh produce at an outdoor market",
        "a greengrocer stand with boxes of fruit",
        "loose unpackaged vegetables in wooden crates",
        "a photo of a market stall selling local produce",
        "a close-up of loose vegetables in a crate",
        "an outdoor produce stall",
    ],
    "food_plant_based_meal": [
        "a plate of vegetables and grains",
        "a bowl of salad with chickpeas",
        "a vegan buddha bowl on a wooden table",
        "roasted vegetables on a dinner plate",
        "a photo of a tofu and vegetable stir fry",
        "a close-up of a vegetable dish",
        "a plate of food with no meat on it",
    ],
    "food_buy_secondhand": [
        "a rail of used clothes in a thrift store",
        "the inside of a charity shop",
        "a vintage clothing market stall",
        "packed racks of secondhand jackets on hangers",
        "a photo of a flea market clothes stall",
        "a close-up of used clothes on wooden hangers",
        "a thrift shop clothing rail",
    ],

    # ---- WATER --------------------------------------------------------------
    # Negation is impossible for CLIP: a running tap and a closed tap embed almost
    # identically. These describe the scene somebody would photograph as evidence,
    # so the picker offers the bathroom family rather than three food habits.
    "water_tap_off_brushing": [
        "a toothbrush next to a bathroom sink",
        "a toothbrush in a cup by a basin",
        "a close-up of a bathroom tap over a white basin",
        "a bathroom sink with a toothbrush and toothpaste",
        "a photo of a chrome tap on a washbasin",
        "toothpaste and a toothbrush on a bathroom shelf",
    ],
    "water_shorter_shower": [
        "a shower head in a tiled bathroom",
        "a close-up of a chrome shower head",
        "a shower cubicle with a glass door",
        "a bathroom shower with tiled walls",
        "a photo of a shower head mounted on a wall",
        "a hand held shower hose in a bathroom",
    ],
    "water_reuse_washing_water": [
        "a bucket of water next to potted plants",
        "a watering can beside a garden bed",
        "a person watering plants from a bucket",
        "a plastic basin of water in a garden",
        "a photo of a bucket used to water plants",
        "a close-up of a watering can and a plant pot",
    ],
    "water_full_loads_only": [
        "a washing machine drum full of clothes",
        "a front loading washing machine with laundry inside",
        "a laundry basket full of clothes by a washing machine",
        "a close-up of a washing machine door and drum",
        "a photo of a full load of laundry in a machine",
        "a washing machine in a utility room",
    ],
    "water_collect_rainwater": [
        "a rain barrel collecting water from a downpipe",
        "a water butt beside a house wall",
        "buckets outside collecting rainwater",
        "a large plastic water tank in a garden",
        "a photo of a rainwater collection barrel",
        "a close-up of a downpipe running into a barrel",
    ],
    "water_fix_leaking_tap": [
        "a wrench on a tap and pipework under a sink",
        "hands repairing a tap with a spanner",
        "a dripping tap with a drop of water",
        "plumbing tools beside a bathroom sink",
        "a photo of a tap being tightened with a wrench",
        "a close-up of pipework under a washbasin",
    ],

    # ---- WASTE --------------------------------------------------------------
    "waste_refuse_plastic_bag": [
        "a folded fabric shopping bag in a hand",
        "a mesh produce bag holding fruit",
        "a woven market basket",
        "a person carrying groceries in a cloth bag",
        "a photo of a rolled up reusable bag",
        "a close-up of a woven shopping basket",
    ],
    "waste_digital_receipt": [
        "a phone screen showing a receipt",
        "a smartphone displaying a digital ticket",
        "a hand holding a phone with an email receipt on screen",
        "a mobile phone showing an order confirmation",
        "a photo of a payment confirmation on a phone screen",
        "a close-up of a phone screen with a receipt",
    ],
    "waste_segregate": [
        "a blue recycling bin with the recycling symbol",
        "sorted bins for paper glass and plastic",
        "a recycling container full of cans and bottles",
        "a person putting a bottle into a recycling bin",
        "a photo of a bottle bank at a recycling point",
        "a close-up of the recycling symbol on a bin",
        "a bin with sorted bottles and cans inside it",
    ],
    "waste_compost": [
        "a compost bin full of vegetable peelings",
        "a countertop food scrap caddy",
        "dark compost soil with eggshells and coffee grounds",
        "a garden compost heap of leaves and food waste",
        "a photo of a brown organic waste bin",
        "a close-up of vegetable peelings",
        "a kitchen compost caddy on a worktop",
    ],
    "waste_refill_product": [
        "a soap refill station with pump dispensers",
        "gravity bins of grains and nuts in a zero waste store",
        "a jar being filled with dry goods",
        "a bulk detergent dispenser in a shop",
        "a photo of a person filling a bottle from a refill tap",
        "a close-up of a bulk refill dispenser",
    ],
    "waste_repair_instead_replace": [
        "hands sewing a patch onto jeans",
        "a needle and thread mending a sweater",
        "a sewing kit with spools of thread",
        "someone repairing a device with a screwdriver",
        "a photo of a darned sock with visible mending",
        "a close-up of a stitched patch on fabric",
        "hands holding a needle and thread",
    ],
    "waste_bank_sampah_dropoff": [
        "sacks of sorted plastic bottles at a collection point",
        "a waste collection depot with sorted materials",
        "bags of cans and bottles ready for recycling",
        "a person handing over a sack of recyclables",
        "a photo of a neighbourhood recycling drop off point",
        "stacked crates of sorted waste at a depot",
    ],

    # ---- ENERGY -------------------------------------------------------------
    "energy_lights_off": [
        "a ceiling light fixture in a room",
        "a light switch on a wall",
        "a close-up of a wall light switch",
        "a hand next to a light switch",
        "a photo of a lamp in an empty room",
        "a bare ceiling bulb in a room",
    ],
    "energy_unplug_chargers": [
        "a phone charger unplugged from a wall socket",
        "a power strip with cables",
        "a close-up of a plug and an electrical socket",
        "a hand pulling a charger out of a socket",
        "a photo of a charging cable beside a wall outlet",
        "tangled charger cables on a desk",
    ],
    "energy_monitor_off": [
        "a computer monitor on a desk",
        "a dark computer screen at a workstation",
        "a desktop monitor and keyboard",
        "a close-up of a monitor power button",
        "a photo of an office desk with a screen",
        "a blank computer display on a table",
    ],
    "energy_cold_water_wash": [
        "a washing machine control dial",
        "a close-up of washing machine temperature settings",
        "a hand turning a washing machine dial",
        "a washing machine control panel with buttons",
        "a photo of laundry machine settings",
        "a front loading washing machine in a bathroom",
    ],
    "energy_air_dry_clothes": [
        "clothes hanging on a washing line",
        "a clothes drying rack indoors",
        "laundry pegged out to dry outside",
        "shirts on hangers drying on a balcony",
        "a photo of a foldable laundry airer",
        "a close-up of clothes pegs on a line",
    ],
    "energy_ac_24_or_above": [
        "an air conditioner remote control",
        "a wall mounted air conditioning unit",
        "a close-up of a thermostat display",
        "a hand holding an air conditioner remote",
        "a photo of an air conditioning unit above a door",
        "a digital temperature display on a wall",
    ],

    # ---- MOBILITY -----------------------------------------------------------
    "mobility_combine_errands": [
        "shopping bags loaded in a car boot",
        "several full grocery bags on a car seat",
        "a car boot packed with shopping",
        "a photo of bags of shopping in a vehicle",
        "a close-up of grocery bags in a car",
    ],
    "mobility_walk_instead": [
        "a pavement path seen from walking height",
        "walking shoes on a footpath",
        "a person walking along a street",
        "a close-up of trainers on a pavement",
        "a photo of a pedestrian footpath",
        "feet walking on a paved road",
    ],
    "mobility_carpool": [
        "several people sitting inside a car",
        "passengers in the back seat of a car",
        "a car interior with people in it",
        "a photo of friends sharing a car ride",
        "a close-up of a car back seat with passengers",
    ],
    "mobility_skip_commute_wfh": [
        "a laptop on a desk at home",
        "a home office desk with a computer",
        "a laptop and notebook on a kitchen table",
        "a photo of a work from home setup",
        "a close-up of a laptop keyboard on a desk",
    ],
    "mobility_public_transport": [  # direct
        "the interior of a city bus",
        "a train platform at a station",
        "a tram on a city street",
        "the inside of a subway carriage with seats",
        "a photo of a bus stop shelter",
        "a bus seen from the pavement",
        "a train arriving at a platform",
    ],
    "mobility_cycle": [  # direct
        "a bicycle parked on the street",
        "a person riding a bike",
        "a bike leaning against a wall",
        "a row of bicycles in a bike rack",
        "a photo of handlebars and a bicycle wheel",
        "a close-up of a bicycle frame and pedals",
        "a bike seen from the side",
    ],

    # ---- ACTIONS ------------------------------------------------------------
    "actions_learning_card": [
        "a phone screen showing an article",
        "a smartphone displaying a reading app",
        "a hand holding a phone with text on screen",
        "a photo of a mobile app screen with a lesson",
        "a close-up of a phone showing written content",
    ],
    "actions_share_progress": [
        "a phone screen showing a social media post",
        "a smartphone displaying a share sheet",
        "a hand holding a phone with an app screen open",
        "a photo of a social media feed on a phone",
        "a close-up of a phone screen with a photo post",
    ],
    "actions_educate_someone": [
        "two people talking together",
        "a person explaining something to another person",
        "a small group in conversation",
        "a photo of two people in discussion",
        "a close-up of people talking face to face",
    ],
    "actions_regional_daily_mission": [
        "a map on a phone screen",
        "a smartphone showing a location map",
        "a hand holding a phone with a map open",
        "a photo of a navigation app on a phone",
        "a close-up of a map with a location pin",
    ],
    "actions_visit_refill_station": [
        "a public water refill fountain",
        "a water bottle refill station on a wall",
        "a person filling a bottle at a refill tap",
        "a drinking water fountain in a public place",
        "a photo of a bottle filling station",
        "a close-up of a water refill tap",
    ],
}

DISTRACTORS = [
    ("appliance",      "an electrical appliance running"),
    ("single_use",     "single-use tableware"),
    ("meat_meal",      "a meal with meat in it"),
    ("packaged_food",  "packaged supermarket food"),
    ("disposable_cup", "a disposable cup"),
    ("plastic_bag",    "a disposable plastic bag"),
    ("plastic_bottle", "a single-use plastic bottle"),
    ("vehicle",        "a car or motorbike"),
    ("ordinary",       "an ordinary scene"),
    # Added: with 38 habits competing, "an ordinary scene" cannot carry rejection
    # alone. These are the things a phone is actually pointed at all day.
    ("face",           "a person's face"),
    ("wall",           "a plain wall or ceiling"),
    ("screen",         "a laptop or television screen"),
    ("furniture",      "furniture in a room"),
    ("pet",            "a cat or a dog"),
    ("street",         "a street with buildings"),
    ("sky",            "the sky or an outdoor landscape"),
    ("hand",           "a close-up of an empty hand"),
]

DUPLICATE_COSINE = 0.9  # habits above this are visually inseparable


def load_catalogue() -> dict[str, dict]:
    with open(CATALOGUE) as f:
        return {h["id"]: h for h in json.load(f)}


def main() -> None:
    catalogue = load_catalogue()

    print(f"[1] Catalogue: {len(catalogue)} habits from {CATALOGUE.name}")

    unknown = sorted(set(PROMPTS) - set(catalogue))
    if unknown:
        raise SystemExit(
            f"PROMPTS references ids that are not in habits.json: {unknown}\n"
            "The catalogue is the source of truth — fix the id here, not there."
        )

    # A habit flagged isCameraDetectable but with no prompts is unreachable by
    # camera. That is allowed (the flag is a wish, prompts are the implementation)
    # but it should be visible rather than silent.
    missing = sorted(
        hid for hid, h in catalogue.items()
        if h.get("isCameraDetectable") and hid not in PROMPTS
    )
    if missing:
        print(f"    note: flagged isCameraDetectable but no prompts yet ({len(missing)}):")
        for hid in missing:
            print(f"          {hid:<5} {catalogue[hid]['name']}")

    print(f"\n[2] Loading model: {MODEL_NAME} from {CKPT}")
    print("    >>> CONFIRM this matches the app's .mlpackage. A v1/v2 or S0/S2")
    print("    >>> mismatch yields normal-looking, meaningless scores.")

    model, _, _ = open_clip.create_model_and_transforms(MODEL_NAME, pretrained=CKPT)
    tokenizer = open_clip.get_tokenizer(MODEL_NAME)
    model.eval()

    ids = sorted(PROMPTS)
    vectors = []
    with torch.no_grad():
        for hid in ids:
            # Prompt ensembling: normalise each prompt, mean, normalise again.
            # Same procedure the image side uses, so dot product == cosine.
            emb = model.encode_text(tokenizer(PROMPTS[hid])).float()
            emb = emb / emb.norm(dim=-1, keepdim=True)
            mean = emb.mean(dim=0)
            mean = mean / mean.norm()
            vectors.append(mean)
            print(f"    encoded {hid:<5} {len(PROMPTS[hid])} prompts  "
                  f"{catalogue[hid]['name']}")

    stacked = torch.stack(vectors)
    dim = stacked.shape[1]

    print(f"\n[3] Embedding dimension: {dim}  <-- must equal the .mlpackage output length")
    if dim != 512:
        print(f"    WARNING: expected 512, got {dim}. Wrong variant?")

    print(f"\n[4] Habit pairs with cosine > {DUPLICATE_COSINE} (visually inseparable):")
    sims = stacked @ stacked.T
    collisions = [
        (ids[i], ids[j], float(sims[i, j]))
        for i, j in itertools.combinations(range(len(ids)), 2)
        if sims[i, j] > DUPLICATE_COSINE
    ]
    if collisions:
        for a, b, s in sorted(collisions, key=lambda c: -c[2]):
            print(f"    {s:.3f}  {a} ({catalogue[a]['name']})")
            print(f"           {b} ({catalogue[b]['name']})")
        print("    Consider merging these or sharpening their prompts.")
    else:
        print(f"    none — all {len(ids)} habits are distinguishable")

    off = sims - torch.eye(len(ids)) * 2
    i, j = divmod(int(off.argmax()), len(ids))
    print(f"    (closest pair overall: {sims[i, j]:.3f}  {ids[i]} <-> {ids[j]})")

    # Only id + vec ship. `name` is not duplicated here — the app already has the
    # catalogue and looks the habit up by id, so a name in two places is just two
    # places to drift. Negatives are omitted too: they served the verify flow,
    # which PRD §5.1 cut when the camera became a search input.
    print(f"\n[4b] Encoding {len(DISTRACTORS)} distractors")
    with torch.no_grad():
        dvecs = []
        for did, label in DISTRACTORS:
            emb = model.encode_text(tokenizer([label])).float()
            emb = emb / emb.norm(dim=-1, keepdim=True)
            dvecs.append(emb.mean(0) / emb.mean(0).norm())
            print(f"    encoded {did:<16} {label}")

    payload = {
        "model": MODEL_NAME,
        "dim": dim,
        # Softmax temperature. The app reads it; without it the classifier falls back
        # to 100 and the confidence gate silently means something else.
        "logitScale": 100.0,
        "habits": [{"id": hid, "vec": v.tolist()} for hid, v in zip(ids, vectors)],
        "distractors": [
            {"id": did, "label": label, "vec": v.tolist()}
            for (did, label), v in zip(DISTRACTORS, dvecs)
        ],
    }
    with open(OUT, "w") as f:
        json.dump(payload, f)

    size = OUT.stat().st_size / 1024
    print(f"\n[5] Wrote {OUT.relative_to(HERE.parent)}: "
          f"{len(payload['habits'])} habits x {dim} floats ({size:.0f} KB)")
    print("    It is inside the synchronized group, so Xcode picks it up with no")
    print("    project changes. Run test_vectors.py next.")


if __name__ == "__main__":
    main()
