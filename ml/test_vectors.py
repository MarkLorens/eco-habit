"""
Self-check for habit_vectors.json. Run after generate_vectors.py:

    <venv>/bin/python test_vectors.py

Uses HELD-OUT descriptions — none of these strings appear in PROMPTS or in
DISTRACTORS — so it tests that the ensembled vectors generalise rather than
memorised.

WHAT THIS PROVES, AND WHAT IT CANNOT
------------------------------------
Text-only. It cannot catch an image-side preprocessing bug, and text-to-text
cosines run far higher than image-to-text ones, so **no threshold should be read
off these numbers**. Use validate_image.py against real photographs for that.

What it does prove is the ordering, which is what the distractor mechanism
depends on: a plastic bottle has to rank a distractor above every habit. If that
ordering is wrong in text space it has no chance on a photograph.
"""

import json

import numpy as np

# See `encode` below: CoreML leaves several FP status flags set; numpy reports them on the next op.
np.seterr(all="ignore")

from generate_vectors import (
    DISTRACTORS, MODEL_NAME, OUT, PROMPTS, load_catalogue, load_text_encoder,
)

# Held-out phrasing -> the habit id it must rank first.
CASES = [
    ("a chrome thermos flask on a desk", "food_reusable_bottle"),
    ("a shopper holding a linen bag of vegetables", "food_reusable_bag"),
    ("wheelie bins marked for glass and cardboard", "waste_segregate"),
    ("worms and rotting fruit in a wooden composter", "waste_compost"),
    ("a shop wall of dispensers for rice and pasta", "waste_refill_product"),
    ("a vegetarian curry with lentils and rice", "food_plant_based_meal"),
    ("wooden stalls of local produce under awnings", "food_buy_local"),
    ("leftovers sealed in a glass tub in the fridge", "food_own_container"),
    ("a red racing bike chained to a lamppost", "mobility_cycle"),
    ("commuters standing inside a crowded metro train", "mobility_public_transport"),
    ("stitching a torn elbow back together with thread", "waste_repair_instead_replace"),
    ("a crowded rack of pre-owned denim jackets", "food_buy_secondhand"),
    ("bed sheets blowing on a washing line in a garden", "energy_air_dry_clothes"),
    ("a barrel under a gutter catching runoff", "water_collect_rainwater"),
    ("a charging cable lying loose beside an empty wall socket", "energy_unplug_chargers"),
    ("a spanner being used on a kitchen mixer tap", "water_fix_leaking_tap"),
]

# The whole reason distractors ship. Each of these MUST rank a distractor above
# every habit — these are the frames that used to log points for the wrong thing.
# Phrasing is held out from DISTRACTORS for the same reason CASES is.
REJECTIONS = [
    "a plastic bottle of mineral water with the cap on",
    "a supermarket carrier bag made of thin plastic",
    "a takeaway latte in a cardboard cup with a lid",
    "a plate of roast beef with gravy",
    "a saloon car parked outside a house",
    "a beige wall in an empty room",
    "a clamshell of strawberries wrapped in plastic",
    "plastic spoons in a takeaway bag",
]


def main() -> None:
    with open(OUT) as f:
        payload = json.load(f)

    catalogue = load_catalogue()
    habits = payload["habits"]
    ids = [h["id"] for h in habits]
    mat = np.array([h["vec"] for h in habits])
    n = len(PROMPTS)

    assert payload["model"] == MODEL_NAME, f"vectors built with {payload['model']}"
    assert mat.shape == (n, 512), f"expected {n}x512, got {tuple(mat.shape)}"
    assert np.allclose(np.linalg.norm(mat, axis=-1), 1.0, atol=1e-5), "not unit vectors"
    assert len(set(ids)) == n, "duplicate habit ids"
    assert set(ids) <= set(catalogue), "vectors reference ids not in activities.json"
    assert {c[1] for c in CASES} == set(ids), \
        f"CASES missing: {sorted(set(ids) - {c[1] for c in CASES})}"

    assert "distractors" in payload, \
        "no distractors in habit_vectors.json — rerun generate_vectors.py"
    dids = [d["id"] for d in payload["distractors"]]
    dlabels = {d["id"]: d["label"] for d in payload["distractors"]}
    dmat = np.array([d["vec"] for d in payload["distractors"]])
    assert set(dids) == set(DISTRACTORS), "distractor ids drifted from the generator"
    assert np.allclose(np.linalg.norm(dmat, axis=-1), 1.0, atol=1e-5), \
        "distractors are not unit vectors"

    scale = payload.get("logitScale")
    assert scale and 50 < scale < 200, f"logitScale {scale} looks wrong (expect ~100)"

    enc = load_text_encoder()

    def encode(texts):
        """One row per text. `load_text_encoder` ensembles a list into one
        vector, so each string is passed as its own single-item ensemble."""
        rows = np.stack([enc([t]) for t in texts])
        # CoreML's prediction leaves the CPU's floating-point "invalid" flag
        # set, and numpy reports that on the NEXT operation — so the matmuls
        # below warn about a NaN that is not there. Assert finiteness for real,
        # then stop numpy crying wolf; suppressing without the assert would hide
        # an actual NaN, which is the one thing that must never pass silently.
        assert np.isfinite(rows).all(), "encoder produced a non-finite embedding"
        return rows

    # --- 1. Held-out habit descriptions rank their own habit first -----------

    emb = encode([c[0] for c in CASES])
    print(f"ranking {len(CASES)} held-out descriptions "
          f"against {n} habits + {len(dids)} distractors:\n")

    failures = []
    true_margins = []
    for (text, want), hs, ds in zip(CASES, emb @ mat.T, emb @ dmat.T):
        got = ids[int(hs.argmax())]
        top = float(hs.max())
        best_d = float(ds.max())
        margin = top - best_d
        true_margins.append(margin)

        ok = got == want and margin > 0
        flag = "ok  " if ok else "FAIL"
        print(f"  {flag} {want:<30} cos {top:.3f}  over distractor {margin:+.3f}  {text}")
        if got != want:
            failures.append(f"{text!r} -> {got}, wanted {want}")
        elif margin <= 0:
            failures.append(
                f"{text!r} lost to distractor {dids[int(ds.argmax())]!r} "
                f"({top:.3f} vs {best_d:.3f})"
            )

    assert not failures, "misranked:\n  " + "\n  ".join(failures)
    print(f"\nPASS: {len(CASES)}/{len(CASES)} ranked correctly and beat every distractor")

    # --- 2. The unsustainable twins are REJECTED ----------------------------

    remb = encode(REJECTIONS)
    print(f"\nrejection cases — a distractor must outrank every habit:\n")

    rejection_failures = []
    reject_margins = []
    for text, hs, ds in zip(REJECTIONS, remb @ mat.T, remb @ dmat.T):
        top_h = float(hs.max())
        top_d = float(ds.max())
        won = dlabels[dids[int(ds.argmax())]]
        margin = top_d - top_h
        reject_margins.append(margin)

        ok = margin > 0
        flag = "ok  " if ok else "FAIL"
        print(f"  {flag} {margin:+.3f}  {won:<32} vs {ids[int(hs.argmax())]:<28} {text}")
        if not ok:
            rejection_failures.append(
                f"{text!r} ranked habit {ids[int(hs.argmax())]!r} ({top_h:.3f}) "
                f"above every distractor ({top_d:.3f}) — it would be logged"
            )

    assert not rejection_failures, \
        "these would log a false positive:\n  " + "\n  ".join(rejection_failures)
    print(f"\nPASS: {len(REJECTIONS)}/{len(REJECTIONS)} rejected")

    # --- 3. Headroom --------------------------------------------------------

    print("\nheadroom (text space):")
    print(f"  tightest true positive over its distractor: {min(true_margins):+.3f}")
    print(f"  tightest rejection over its habit:          {min(reject_margins):+.3f}")
    print("\n  Both must be positive, and the first is the one to watch: it is how")
    print("  much room a real photograph has before its habit loses to a twin.")
    print("  Text cosines run HIGH — do NOT set distractorMargin from these.")
    print("  Tune it on photographs with validate_image.py.")


if __name__ == "__main__":
    main()
