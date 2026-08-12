"""
Score one image against habit_vectors.json using the PyTorch image tower.
Ground truth to compare against what the Swift app prints for the SAME file.

    ./venv/bin/python validate_image.py test.jpg

Swift and PyTorch should agree to roughly +/- 0.01 on each cosine, and agree
exactly on the ranking. If the ranking differs, the usual suspects are:
  - .mlpackage is a different MobileCLIP variant than MODEL_NAME below
  - imageCropAndScaleOption in Swift != the resize/crop printed by [0] here
  - image orientation not passed to VNImageRequestHandler
"""

import json
import sys

import open_clip
import torch
from PIL import Image

# MUST be identical to generate_vectors.py and match the bundled .mlpackage
# (models/mobileclip_s2_image.mlpackage).
MODEL_NAME = "MobileCLIP-S2"
CKPT = "datacompdr"
VECTORS = "habit_vectors.json"


def main() -> None:
    # validate_image.py <image>                  -> rank all habits (discover flow)
    # validate_image.py <image> --habit <id>     -> positive vs negatives (verify flow)
    args = sys.argv[1:]
    habit_id = None
    if "--habit" in args:
        i = args.index("--habit")
        if i + 1 >= len(args):
            sys.exit("--habit needs a habit id")
        habit_id = args[i + 1]
        args = args[:i] + args[i + 2:]
    if len(args) != 1:
        sys.exit("usage: validate_image.py <image> [--habit <id>]")
    path = args[0]

    with open(VECTORS) as f:
        habits = json.load(f)
    mat = torch.tensor([h["vec"] for h in habits])

    print(f"[0] Loading {MODEL_NAME} from {CKPT}")
    model, _, preprocess = open_clip.create_model_and_transforms(MODEL_NAME, pretrained=CKPT)
    model.eval()
    print(f"    preprocess pipeline (compare to how the .mlpackage was converted):\n{preprocess}")

    img = Image.open(path).convert("RGB")  # PIL applies no EXIF rotation; Vision does
    with torch.no_grad():
        emb = model.encode_image(preprocess(img).unsqueeze(0)).float()
    emb = emb / emb.norm()  # L2-normalise, same as HabitClassifier.swift does

    if habit_id is not None:
        # Verify flow. MUST match HabitClassifier.verify(): max over negatives,
        # never a mean, and the same two conditions for a pass.
        match = next((h for h in habits if h["id"] == habit_id), None)
        if match is None:
            sys.exit(f"no habit {habit_id!r}; have: {', '.join(h['id'] for h in habits)}")
        if not match.get("neg"):
            sys.exit(f"{habit_id} has no negatives - re-run generate_vectors.py")

        vec = emb.squeeze(0)
        pos_vec = torch.tensor(match["vec"])
        neg_mat = torch.tensor(match["neg"])
        positive = float(pos_vec @ vec)
        neg_scores = (neg_mat @ vec).tolist()

        # Per-contrast scaling, worst case - identical to HabitClassifier.verify().
        gaps = (pos_vec - neg_mat).norm(dim=-1).clamp(min=1e-4).tolist()
        scaled = [(positive - n) / g for n, g in zip(neg_scores, gaps)]
        decides = min(range(len(scaled)), key=lambda k: scaled[k])
        negative = neg_scores[decides]

        MIN_SIMILARITY = 0.20  # HabitClassifier.minSimilarity
        VERIFY_MARGIN = 0.01   # HabitClassifier.verifyMargin (on the SCALED margin)
        passed = positive >= MIN_SIMILARITY and scaled[decides] >= VERIFY_MARGIN

        print(f"\n[1] {path}  verify against {habit_id}")
        print(f"    positive          {positive:>8.4f}  (need >= {MIN_SIMILARITY})")
        print(f"    {'negative':<9} {'cos':>8} {'gap':>7} {'scaled':>8}")
        for k, (n, g, s) in enumerate(zip(neg_scores, gaps, scaled)):
            print(f"    [{k}]       {n:>8.4f} {g:>7.3f} {s:>8.4f}"
                  f"{'  <- decides' if k == decides else ''}")
        print(f"    raw margin        {positive - negative:>8.4f}")
        print(f"    scaled margin     {scaled[decides]:>8.4f}  (need >= {VERIFY_MARGIN})")
        print(f"\n[2] {'PASS' if passed else 'FAIL'}")
        return

    cos = (mat @ emb.squeeze(0)).tolist()
    # Softmax temperature 100 - MUST match HabitClassifier.temperature in Swift.
    probs = torch.softmax(torch.tensor(cos) * 100.0, dim=0).tolist()

    print(f"\n[1] {path}  (embedding dim {emb.shape[1]})")
    print(f"    {'habit':<22} {'cosine':>7} {'conf':>7}")
    for i in sorted(range(len(habits)), key=lambda k: -cos[k]):
        print(f"    {habits[i]['id']:<22} {cos[i]:>7.4f} {probs[i]:>6.1%}")

    best = max(cos)
    print(f"\n[2] best cosine {best:.4f} - minSimilarity in Swift starts at 0.20")
    if best < 0.20:
        print("    below threshold: the app would show 'nothing recognised'")


if __name__ == "__main__":
    main()
