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
CATALOGUE = HERE.parent / "Eco-Habbit" / "Resources" / "activities.json"
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
    "food_reusable_bottle": [  # Use a reusable water bottle
        "a stainless steel water bottle",
        "an insulated metal flask",
        "a reusable water bottle with a screw cap",
        "a person holding a metal drinking bottle",
        "a photo of a refillable sports bottle",
        "a close-up of a metal water bottle",
        "a steel drinking bottle standing on a desk",
    ],
    "food_reusable_bag": [  # Refuse a plastic bag; use your own
        "a canvas tote bag",
        "a cloth shopping bag full of groceries",
        "a jute string mesh produce bag",
        "a person carrying a fabric shopping bag",
        "a photo of a reusable grocery bag on a table",
        "a close-up of a cloth tote bag",
        "a folded fabric shopping bag",
    ],
    "waste_segregate": [  # Segregate waste into organic and inorganic
        "a blue recycling bin with the recycling symbol",
        "sorted bins for paper glass and plastic",
        "a recycling container full of cans and bottles",
        "a person putting a bottle into a recycling bin",
        "a photo of a bottle bank at a recycling point",
        "a close-up of the recycling symbol on a bin",
        "a bin with sorted bottles and cans inside it",
    ],
    "waste_compost": [  # Compost food scraps
        "a compost bin full of vegetable peelings",
        "a countertop food scrap caddy",
        "dark compost soil with eggshells and coffee grounds",
        "a garden compost heap of leaves and food waste",
        "a photo of a brown organic waste bin",
        "a close-up of vegetable peelings",
        "a kitchen compost caddy on a worktop",
    ],
    "waste_refill_product": [  # Refill household products at a bulk store
        "a bulk food refill dispenser in a shop",
        "gravity bins of grains and nuts in a zero waste store",
        "a public water refill fountain",
        "a soap refill station with pump dispensers",
        "a photo of a person filling a jar from a bulk dispenser",
        "a close-up of a bulk food dispenser",
        "a jar being filled with dry goods",
    ],
    "food_plant_based_meal": [  # Eat a fully plant-based meal
        "a plate of vegetables and grains",
        "a bowl of salad with chickpeas",
        "a vegan buddha bowl on a wooden table",
        "roasted vegetables on a dinner plate",
        "a photo of a tofu and vegetable stir fry",
        "a close-up of a vegetable dish",
        "a plate of food with no meat on it",
    ],
    "food_buy_local": [  # Buy produce from a local market
        "a farmers market vegetable stall",
        "crates of fresh produce at an outdoor market",
        "a greengrocer stand with boxes of fruit",
        "loose unpackaged vegetables in wooden crates",
        "a photo of a market stall selling local produce",
        "a close-up of loose vegetables in a crate",
        "an outdoor produce stall",
    ],
    "food_own_container": [  # Pack a home-cooked lunch
        "a glass food storage container with a lid",
        "a stainless steel lunchbox",
        "a bento box packed with food",
        "meal prep containers stacked on a counter",
        "a photo of a packed lunch in a reusable tub",
        "a close-up of a glass food container",
        "a metal lunch tin on a table",
    ],
    "mobility_cycle": [  # Walk or cycle a trip under 2 km
        "a bicycle parked on the street",
        "a person riding a bike",
        "a bike leaning against a wall",
        "a row of bicycles in a bike rack",
        "a photo of handlebars and a bicycle wheel",
        "a close-up of a bicycle frame and pedals",
        "a bike seen from the side",
    ],
    "mobility_public_transport": [  # Take public transport instead of driving
        "the interior of a city bus",
        "a train platform at a station",
        "a tram on a city street",
        "the inside of a subway carriage with seats",
        "a photo of a bus stop shelter",
        "a bus seen from the pavement",
        "a train arriving at a platform",
    ],
    "waste_repair_instead_replace": [  # Repair something instead of replacing it
        "hands sewing a patch onto jeans",
        "a needle and thread mending a sweater",
        "a sewing kit with spools of thread",
        "someone repairing a device with a screwdriver",
        "a photo of a darned sock with visible mending",
        "a close-up of a stitched patch on fabric",
        "hands holding a needle and thread",
    ],
    "food_buy_secondhand": [  # Buy secondhand instead of new
        "a rail of used clothes in a thrift store",
        "the inside of a charity shop",
        "a vintage clothing market stall",
        "packed racks of secondhand jackets on hangers",
        "a photo of a flea market clothes stall",
        "a close-up of used clothes on wooden hangers",
        "a thrift shop clothing rail",
    ],
    "energy_air_dry_clothes": [  # Air-dry laundry instead of using a dryer
        "laundry hanging on a clothesline",
        "clothes drying on an indoor airer rack",
        "washing pegged out on a line in the sun",
        "a folding clothes horse with towels on it",
        "a photo of shirts hanging on a washing line",
        "a close-up of clothes pegged on a line",
        "a drying rack of damp clothes indoors",
    ],
    "water_collect_rainwater": [  # Collect rainwater
        "a green water butt beside a house",
        "a rain barrel collecting water from a downpipe",
        "a large rainwater tank in a garden",
        "a watering can being filled from a rain barrel",
        "a photo of a rainwater collection drum",
        "a close-up of a water butt tap",
        "a rain barrel standing against a wall",
    ],
    "energy_unplug_chargers": [
        "an unplugged charger beside a wall socket",
        "a phone charger removed from the outlet",
        "a bare wall socket with nothing plugged in",
        "a hand pulling a plug from a socket",
        "a photo of a coiled unused charging cable",
        "a close-up of an empty power outlet",
        "a switched-off power strip",
    ],
    "water_fix_leaking_tap": [
        "a dripping tap with a water droplet",
        "a wrench tightening a tap fitting",
        "hands repairing a leaking faucet",
        "a plumber's tools beside a sink tap",
        "a photo of water dripping from a spout",
        "a close-up of a tap washer being replaced",
        "a leaking pipe joint under a sink",
    ],
}

DUPLICATE_COSINE = 0.9  # habits above this are visually inseparable


def load_catalogue() -> dict[str, dict]:
    """The same file the app bundles — one source of truth for activity ids."""
    with open(CATALOGUE) as f:
        rows = json.load(f)
    return {
        r["id"]: {
            **r,
            # Tio's own data decides what is photographable.
            "isCameraDetectable": r["evidenceStrength"] in ("direct", "contextual"),
        }
        for r in rows
    }


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
    payload = {
        "model": MODEL_NAME,
        "dim": dim,
        "habits": [{"id": hid, "vec": v.tolist()} for hid, v in zip(ids, vectors)],
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
