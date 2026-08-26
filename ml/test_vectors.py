"""
Self-check for habit_vectors.json. Run after generate_vectors.py:

    ../../../CameraAI/venv/bin/python test_vectors.py

Uses HELD-OUT descriptions — none of these strings appear in PROMPTS — so it
tests that the ensembled vectors generalise rather than memorised.

Text-only: it cannot catch an image-side preprocessing bug. Use validate_image.py
against real photographs for that.
"""

import json

import torch

import open_clip
from generate_vectors import CKPT, MODEL_NAME, OUT, PROMPTS, load_catalogue

# Held-out phrasing -> the catalogue habit id it must rank first.
# Habits no photograph can separate, so a swap between them is not a failure.
#
# "Bring a reusable shopping bag" and "Refuse plastic bag" are the same action written
# from two sides: both are a person holding a cloth bag. The duplicate check in
# generate_vectors.py scores them at 0.955. Sharpening the prompts until this test went
# green would move each set AWAY from the object it actually describes — passing a
# synthetic ranking at the cost of real photographs.
#
# The app already handles it correctly: a near-tie fails `decisiveMargin`, so the verdict
# is `.unsure` and the picker offers both for the user to choose between.
INSEPARABLE = {
    frozenset(("food_reusable_bag", "waste_refuse_plastic_bag")),
}

CASES = [
    # Held out on purpose: none of these wordings appear in PROMPTS, so a habit that
    # only ranks first for its own prompts fails here rather than in somebody's hand.
    ("a chrome thermos flask on a desk", "food_reusable_bottle"),
    ("a shopper holding a linen bag of vegetables", "food_reusable_bag"),
    ("a travel set of wooden utensils with a metal straw", "food_refuse_single_use_cutlery"),
    ("leftovers sealed in a glass tub in the fridge", "food_own_container"),
    ("a scraped clean dinner plate with a fork on it", "food_finish_food"),
    ("wooden stalls of local produce under awnings", "food_buy_local"),
    ("a vegetarian curry with lentils and rice", "food_plant_based_meal"),
    ("a crowded rack of pre-owned denim jackets", "food_buy_secondhand"),

    ("a toothbrush resting in a glass by a washbasin", "water_tap_off_brushing"),
    ("a rainfall shower head above a tiled cubicle", "water_shorter_shower"),
    ("a pail of grey water beside a row of pot plants", "water_reuse_washing_water"),
    ("a washer drum stuffed with towels and sheets", "water_full_loads_only"),
    ("a barrel under a gutter catching runoff", "water_collect_rainwater"),
    ("a spanner tightening the pipe beneath a basin", "water_fix_leaking_tap"),

    ("a folded cloth carrier tucked into a pocket", "waste_refuse_plastic_bag"),
    ("a mobile displaying an emailed proof of purchase", "waste_digital_receipt"),
    ("wheelie bins marked for glass and cardboard", "waste_segregate"),
    ("worms and rotting fruit in a wooden composter", "waste_compost"),
    ("a shop wall of dispensers for rice and pasta", "waste_refill_product"),
    ("stitching a torn elbow back together with thread", "waste_repair_instead_replace"),
    ("bulging sacks of bottles stacked at a collection yard", "waste_bank_sampah_dropoff"),

    ("a pendant lamp hanging from a ceiling rose", "energy_lights_off"),
    ("a cable pulled free of a wall outlet", "energy_unplug_chargers"),
    ("a widescreen display sitting on an office desk", "energy_monitor_off"),
    ("a dial marked with wash temperatures", "energy_cold_water_wash"),
    ("bed sheets blowing on a washing line in a garden", "energy_air_dry_clothes"),
    ("a handset for controlling a room cooling unit", "energy_ac_24_or_above"),

    ("a boot loaded with carrier bags after shopping", "mobility_combine_errands"),
    ("sneakers photographed mid stride on paving", "mobility_walk_instead"),
    ("four friends buckled into one vehicle", "mobility_carpool"),
    ("a notebook and laptop on a dining table at home", "mobility_skip_commute_wfh"),
    ("commuters standing inside a crowded metro train", "mobility_public_transport"),
    ("a red racing bike chained to a lamppost", "mobility_cycle"),

    ("a handset showing a page of study material", "actions_learning_card"),
    ("a phone open on a post being shared", "actions_share_progress"),
    ("two neighbours deep in conversation", "actions_educate_someone"),
    ("a route displayed on a phone map", "actions_regional_daily_mission"),
    ("a bottle held under a public drinking tap", "actions_visit_refill_station"),
]

# Things the camera will be pointed at that are NOT any habit — the unsustainable
# twins, mostly. None should score high enough to surface as a chip. This is the
# check that sets the display threshold honestly.
DISTRACTORS = [
    "a single-use plastic water bottle",
    "a disposable paper coffee cup with a plastic lid",
    "a thin white plastic carrier bag",
    "a steak on a plate",
    "a black bin bag of mixed household rubbish",
    "a tumble dryer machine",
    "a parked motorbike with a chrome exhaust",
    "the interior of a private car",
    "a supermarket aisle of packaged food",
    "disposable plastic forks and knives",
    "a roll of white paper towel on a holder",
    "a bookstore table stacked with new releases",
    "an empty white wall",
    "a laptop keyboard on a desk",
    "a person's face in close up",
]


def main() -> None:
    with open(OUT) as f:
        payload = json.load(f)

    catalogue = load_catalogue()
    habits = payload["habits"]
    ids = [h["id"] for h in habits]
    mat = torch.tensor([h["vec"] for h in habits])
    n = len(PROMPTS)

    assert payload["model"] == MODEL_NAME, f"vectors built with {payload['model']}"
    assert mat.shape == (n, 512), f"expected {n}x512, got {tuple(mat.shape)}"
    assert torch.allclose(mat.norm(dim=-1), torch.ones(n), atol=1e-5), "not unit vectors"
    assert len(set(ids)) == n, "duplicate habit ids"
    assert set(ids) <= set(catalogue), "vectors reference ids not in habits.json"
    # Every habit needs a held-out case, or new ones go silently untested.
    assert {c[1] for c in CASES} == set(ids), \
        f"CASES missing: {sorted(set(ids) - {c[1] for c in CASES})}"

    model, _, _ = open_clip.create_model_and_transforms(MODEL_NAME, pretrained=CKPT)
    tokenizer = open_clip.get_tokenizer(MODEL_NAME)
    model.eval()

    with torch.no_grad():
        emb = model.encode_text(tokenizer([c[0] for c in CASES])).float()
    emb = emb / emb.norm(dim=-1, keepdim=True)

    print(f"ranking {len(CASES)} held-out descriptions against {n} habits:\n")
    failures = []
    true_positive_scores = []
    for (text, want), scores in zip(CASES, emb @ mat.T):
        got = ids[int(scores.argmax())]
        top = float(scores.max())
        margin = top - float(scores.topk(2).values[1])
        true_positive_scores.append(top)
        flag = "ok  " if got == want else "FAIL"
        print(f"  {flag} {want:<5} cos {top:.3f}  lead {margin:+.3f}  {text}")
        if got != want and frozenset((got, want)) not in INSEPARABLE:
            failures.append(f"{text!r} -> {got} ({catalogue[got]['name']}), wanted {want}")

    assert not failures, "misranked:\n  " + "\n  ".join(failures)
    swaps = sum(1 for f in CASES if False)  # placeholder, real count printed above
    print(f"\nPASS: {len(CASES)} descriptions, no unexpected misrankings")

    # What a non-habit scores. The chip threshold has to sit above this.
    with torch.no_grad():
        demb = model.encode_text(tokenizer(DISTRACTORS)).float()
    demb = demb / demb.norm(dim=-1, keepdim=True)
    distractor_tops = (demb @ mat.T).max(dim=1)

    print(f"\ndistractors — best habit each one attracts:\n")
    for text, score, idx in zip(DISTRACTORS, distractor_tops.values, distractor_tops.indices):
        print(f"       cos {float(score):.3f}  -> {ids[int(idx)]:<5} {text}")

    worst_true = min(true_positive_scores)
    best_false = float(distractor_tops.values.max())
    print(f"\n  weakest true positive: {worst_true:.3f}")
    print(f"  strongest distractor:  {best_false:.3f}")
    if worst_true > best_false:
        print(f"  -> a threshold anywhere in ({best_false:.3f}, {worst_true:.3f}) separates them on text")
    else:
        print("  -> OVERLAP on text. Chips will show some false suggestions —")
        print("     acceptable for a search tool (§5.3: a false suggestion costs a")
        print("     glance), but do not raise minSimilarity expecting to fix it.")
    print("\n  NOTE: real photographs score LOWER than text — they carry background,")
    print("  clutter and lighting the prompts never mention. Tune HabitClassifier")
    print("  .minSimilarity on photos with validate_image.py, not on this number.")


if __name__ == "__main__":
    main()
