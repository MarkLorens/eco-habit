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
CASES = [
    ("a chrome thermos flask on a desk", "ws2"),
    ("a person drinking from a bamboo travel mug", "ws3"),
    ("a shopper holding a linen bag of vegetables", "ws1"),
    ("a travel set of wooden utensils with a metal straw", "ws4"),
    ("wheelie bins marked for glass and cardboard", "ws5"),
    ("worms and rotting fruit in a wooden composter", "ws6"),
    ("a shop wall of dispensers for rice and pasta", "ws8"),
    ("a waxed cotton wrap folded around a loaf of bread", "ws9"),
    ("a vegetarian curry with lentils and rice", "f1"),
    ("wooden stalls of local produce under awnings", "f4"),
    ("leftovers sealed in a glass tub in the fridge", "f6"),
    ("a red racing bike chained to a lamppost", "t1"),
    ("commuters standing inside a crowded metro train", "t2"),
    ("stitching a torn elbow back together with thread", "c1"),
    ("a crowded rack of pre-owned denim jackets", "c2"),
    ("long rows of borrowed hardbacks on wooden shelving", "c6"),
    ("bed sheets blowing on a washing line in a garden", "e2"),
    ("a barrel under a gutter catching runoff", "w4"),
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
        if got != want:
            failures.append(f"{text!r} -> {got} ({catalogue[got]['name']}), wanted {want}")

    assert not failures, "misranked:\n  " + "\n  ".join(failures)
    print(f"\nPASS: {len(CASES)}/{len(CASES)} ranked correctly")

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
