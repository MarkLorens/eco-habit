"""
Generate habit_vectors.json for the Eco-Habit iOS app.

Encodes prompt ensembles with the MobileCLIP-S2 TEXT tower and writes one
L2-normalised vector per camera-searchable habit, plus the distractor vectors
that let the app answer "none of these".

    ml/venv/bin/python generate_vectors.py

Runs on CoreML, not torch: the text tower ships as an .mlpackage next to this
script, so the dependencies are coremltools + a CLIP tokenizer and nothing else.

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

import numpy as np
import coremltools as ct
from transformers import CLIPTokenizerFast

# --- MUST MATCH THE iOS .mlpackage -----------------------------------------
# This runs the TEXT tower from the same Apple release as the app's IMAGE tower,
# through CoreML — not through torch/open_clip. That removes the entire class of
# "v1 vs v2, S0 vs S2" mismatch this file used to warn about, because both
# towers now come from one place instead of two.
#
# Verified equivalent: encoding the habit prompts through this path reproduces
# the previous open_clip-generated vectors at cosine 1.000000.
MODEL_NAME = "MobileCLIP-S2"
CKPT = "mobileclip_s2_text.mlpackage"

HERE = pathlib.Path(__file__).parent
TEXT_TOWER = HERE / CKPT
CATALOGUE = HERE.parent / "Eco-Habbit" / "Resources" / "activities.json"
OUT = HERE.parent / "Eco-Habbit" / "Resources" / "habit_vectors.json"

CONTEXT_LENGTH = 77

# CLIP's learned temperature. The text tower alone cannot report it — it is a
# separate parameter of the full model — so it is stated here. open_clip clamps
# logit_scale at 100 during training and MobileCLIP trains to that ceiling, so
# this is the trained value rather than a guess. It only scales the softmax
# confidence; `autoLogConfidence` in Swift is tuned on photographs regardless.
LOGIT_SCALE = 100.0
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

# --- DISTRACTORS ------------------------------------------------------------
# Things the camera WILL be pointed at that are not habits. These ship as
# vectors and are ranked in the same pass as the habits.
#
# WHY THIS EXISTS
# Ranking against habits alone is a closed set: whatever you photograph, the
# nearest of N habits wins, because there is no option to return nothing. A
# single-use plastic bottle is overwhelmingly "a bottle", so it lands on
# food_reusable_bottle with a healthy score and the app logs points for it.
#
# Two things that do NOT fix it, both tried:
#   * Raising minSimilarity. The plastic bottle genuinely scores high — you would
#     have to raise the floor past where real reusable bottles land.
#   * Negation in the habit prompt ("a metal bottle, not a plastic one"). CLIP
#     has no negation. The tokens "plastic bottle" pull the habit vector TOWARD
#     plastic bottles. It reliably makes things worse.
#
# Giving the wrong answer somewhere correct to land is what works. Each key is
# an id; the label is shown to the user ("That looks like a single-use plastic
# bottle"), so write labels as a noun phrase that completes that sentence.
#
# THE UNSUSTAINABLE TWINS MATTER MOST. A distractor only earns its place if it
# is close to a habit — "a photo of a cat" defends nothing. Every group below
# either shadows a specific habit or catches the camera pointing at nothing.
DISTRACTORS = {
    "plastic_bottle": (
        "a single-use plastic bottle",
        [
            "a single-use plastic water bottle",
            "a disposable PET bottle with a paper label",
            "a clear plastic drinks bottle with a blue cap",
            "a crushed empty plastic bottle",
            "a pack of bottled water in plastic wrap",
            "a close-up of a transparent disposable bottle",
        ],
    ),
    "plastic_bag": (
        "a disposable plastic bag",
        [
            "a thin white plastic carrier bag",
            "a disposable polythene shopping bag",
            "a crumpled plastic grocery bag",
            "a black bin bag of household rubbish",
            "groceries in a thin plastic supermarket bag",
            "a close-up of a translucent plastic bag",
        ],
    ),
    "paper_cup": (
        "a disposable cup",
        [
            "a disposable paper coffee cup with a plastic lid",
            "a takeaway cup with a cardboard sleeve",
            "a styrofoam cup",
            "a plastic cup with a straw in it",
        ],
    ),
    "disposable_tableware": (
        "single-use tableware",
        [
            "disposable plastic forks and knives",
            "a styrofoam takeaway food container",
            "a paper plate with plastic cutlery",
            "food wrapped in cling film on a plastic tray",
        ],
    ),
    "packaged_food": (
        "packaged supermarket food",
        [
            "a supermarket aisle of packaged food",
            "vegetables sealed in a plastic tray",
            "a shelf of branded snack packets",
            "fruit wrapped in plastic film",
        ],
    ),
    "meat_meal": (
        "a meal with meat in it",
        [
            "a steak on a plate",
            "a plate of grilled chicken and chips",
            "a hamburger with a beef patty",
            "sausages frying in a pan",
        ],
    ),
    "private_car": (
        "a car or motorbike",
        [
            "the interior of a private car",
            "a parked motorbike with a chrome exhaust",
            "a car dashboard and steering wheel",
            "a car parked on a driveway",
        ],
    ),
    "appliance": (
        "an electrical appliance running",
        [
            "a tumble dryer machine",
            "an air conditioner unit on a wall",
            "a washing machine with the door open",
            "a television switched on in a living room",
        ],
    ),
    # Not a twin of anything — this group catches the camera pointing at nothing
    # in particular, which without it lands on whichever habit is least unlike a
    # wall. It is the difference between "no" and a confident wrong answer.
    "scene": (
        "an ordinary scene",
        [
            "an empty white wall",
            "a laptop keyboard on a desk",
            "a person's face in close up",
            "a plain ceiling with a light fitting",
            "a carpeted floor",
            "a blurry dark photo of nothing in particular",
            "a hand held up to the camera",
            "a street with parked cars",
        ],
    ),
}

DUPLICATE_COSINE = 0.9  # habits above this are visually inseparable


def load_text_encoder():
    """Returns `encode(prompts) -> unit vector`, prompt-ensembled.

    Shared by test_vectors.py and validate_image.py so the tokenizer, the
    padding value and the ensembling procedure exist in exactly one place. They
    have to match the app bit for bit, and three copies is three chances to drift.
    """
    if not TEXT_TOWER.exists():
        raise SystemExit(f"missing {TEXT_TOWER}")

    model = ct.models.MLModel(str(TEXT_TOWER))
    tokenizer = CLIPTokenizerFast.from_pretrained("openai/clip-vit-base-patch32")

    def tokenize(text: str):
        """CLIP BPE, padded to 77 with ZERO.

        The padding value is load-bearing and it is not the obvious one:
        HuggingFace's CLIPTokenizer pads with <|endoftext|> (49407), open_clip
        pads with 0, and the tower was trained the open_clip way. Pad with the
        HF default and every vector lands in a different part of the space —
        habit prompts then score ~0.19 against their own vectors, which reads
        like a broken model rather than a wrong constant.
        """
        ids = tokenizer(text, truncation=True, max_length=CONTEXT_LENGTH)["input_ids"]
        return np.array([ids + [0] * (CONTEXT_LENGTH - len(ids))], dtype=np.int32)

    def encode(prompts):
        """Normalise each prompt, mean, normalise again — so a dot product IS a cosine."""
        embs = []
        for text in prompts:
            emb = np.asarray(model.predict({"text": tokenize(text)})["final_emb_1"],
                             dtype=np.float64).ravel()
            embs.append(emb / np.linalg.norm(emb))
        mean = np.stack(embs).mean(axis=0)
        return mean / np.linalg.norm(mean)

    return encode


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

    print(f"\n[2] Loading TEXT tower: {TEXT_TOWER.name}")
    print("    Same Apple release as the app's image tower, run through CoreML —")
    print("    so both halves of the model come from one place, not two.")

    encode = load_text_encoder()

    ids = sorted(PROMPTS)
    vectors = []
    for hid in ids:
        vectors.append(encode(PROMPTS[hid]))
        print(f"    encoded {hid:<34} {len(PROMPTS[hid])} prompts  "
              f"{catalogue[hid]['name']}")

    dids = sorted(DISTRACTORS)
    dvectors = []
    for d in dids:
        dvectors.append(encode(DISTRACTORS[d][1]))
        print(f"    encoded {d:<34} {len(DISTRACTORS[d][1])} prompts  "
              f"[distractor] {DISTRACTORS[d][0]}")

    stacked = np.stack(vectors)
    dstacked = np.stack(dvectors)
    dim = stacked.shape[1]
    logit_scale = LOGIT_SCALE

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

    off = sims - np.eye(len(ids)) * 2
    i, j = divmod(int(off.argmax()), len(ids))
    print(f"    (closest pair overall: {sims[i, j]:.3f}  {ids[i]} <-> {ids[j]})")

    # The report that matters. A habit sitting close to its unsustainable twin is
    # the one that will log a false positive on a real photo, and this says which
    # one and by how much BEFORE anybody points a phone at anything.
    print(f"\n[4b] Nearest distractor per habit (text-space):")
    cross = stacked @ dstacked.T
    worst = []
    for k, hid in enumerate(ids):
        best = int(cross[k].argmax())
        gap = float(cross[k].max())
        worst.append((gap, hid, dids[best]))
    for gap, hid, did in sorted(worst, reverse=True):
        flag = "  <-- TIGHT" if gap > 0.80 else ""
        print(f"    {gap:.3f}  {hid:<34} vs {did}{flag}")
    print("    Text-space cosines run HIGH; the number to watch is the ordering,")
    print("    not the value. Anything marked TIGHT will need sharper prompts —")
    print("    name the material ('stainless steel', 'matte metal'), never the")
    print("    negative ('not plastic'), which pulls the vector the wrong way.")

    # Habits ship id + vec only. `name` is not duplicated here — the app has the
    # catalogue and looks the habit up by id, so a name in two places is two
    # places to drift.
    #
    # Distractors DO carry a label, because there is no catalogue to look "a
    # single-use plastic bottle" up in, and the label is the whole point: it is
    # what lets the app say what it thinks it saw instead of "nothing found".
    payload = {
        "model": MODEL_NAME,
        "dim": dim,
        "logitScale": logit_scale,
        "habits": [{"id": hid, "vec": v.tolist()} for hid, v in zip(ids, vectors)],
        "distractors": [
            {"id": did, "label": DISTRACTORS[did][0], "vec": v.tolist()}
            for did, v in zip(dids, dvectors)
        ],
    }
    # `indent=1` rather than a single long line: an editor that soft-wraps or
    # reformats long lines will happily inject a newline *inside* a float
    # ("-0.0191486943513\n    15,") and silently corrupt the file. Short lines
    # give a formatter nothing to wrap. Costs ~10% size, buys immunity.
    with open(OUT, "w") as f:
        json.dump(payload, f, indent=1)
        f.write("\n")

    size = OUT.stat().st_size / 1024
    print(f"\n[5] Wrote {OUT.relative_to(HERE.parent)}: "
          f"{len(payload['habits'])} habits + {len(payload['distractors'])} distractors "
          f"x {dim} floats ({size:.0f} KB), logitScale {logit_scale:.1f}")
    print("    It is inside the synchronized group, so Xcode picks it up with no")
    print("    project changes. Run test_vectors.py next.")


if __name__ == "__main__":
    main()
