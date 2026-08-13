"""
Score a real photograph exactly the way the app does.

    <venv>/bin/python validate_image.py photo.jpg
    <venv>/bin/python validate_image.py photos/*.jpg

This is the ONLY honest way to set the thresholds in HabitClassifier.swift.
test_vectors.py works in text space, where cosines run far higher — a number
that looks decisive there is routine on a photograph, which carries background,
clutter and lighting the prompts never mention.

The verdict logic below MUST stay in step with HabitClassifier.verdict(). If you
change one, change the other; a tuning tool that disagrees with the app is worse
than no tuning tool.
"""

import glob
import json
import pathlib
import sys

import numpy as np
import coremltools as ct
from PIL import Image

# CoreML leaves FP status flags set; numpy reports them on the next operation.
# Finiteness is asserted explicitly in score_one().
np.seterr(all="ignore")

from generate_vectors import MODEL_NAME, OUT

HERE = pathlib.Path(__file__).parent
IMAGE_TOWER = HERE.parent / "Eco-Habbit" / "Resources" / "mobileclip_s2_image.mlpackage"
INPUT_SIZE = 256

# --- keep in step with HabitClassifier.swift --------------------------------
MIN_SIMILARITY = 0.15
AUTO_LOG_SIMILARITY = 0.30
AUTO_LOG_CONFIDENCE = 0.55
DECISIVE_MARGIN = 0.05
DISTRACTOR_MARGIN = 0.02
# ---------------------------------------------------------------------------

CATALOGUE = pathlib.Path(__file__).parent.parent / "Eco-Habbit" / "Resources" / "activities.json"


def main() -> None:
    paths: list[str] = []
    for arg in sys.argv[1:]:
        paths.extend(sorted(glob.glob(arg)) or [arg])
    if not paths:
        sys.exit("usage: validate_image.py <image> [image ...]")

    with open(OUT) as f:
        payload = json.load(f)
    if "distractors" not in payload:
        sys.exit("habit_vectors.json has no distractors — rerun generate_vectors.py")

    ids = [h["id"] for h in payload["habits"]]
    mat = np.array([h["vec"] for h in payload["habits"]])
    dids = [d["id"] for d in payload["distractors"]]
    dlabels = [d["label"] for d in payload["distractors"]]
    dmat = np.array([d["vec"] for d in payload["distractors"]])
    scale = payload.get("logitScale", 100.0)

    with open(CATALOGUE) as f:
        evidence = {r["id"]: r["evidenceStrength"] for r in json.load(f)}

    print(f"[0] {MODEL_NAME} — {len(ids)} habits, {len(dids)} distractors, "
          f"logitScale {scale:.1f}")
    print(f"    image tower: {IMAGE_TOWER.name} (the very one the app bundles)")
    model = ct.models.MLModel(str(IMAGE_TOWER))

    for path in paths:
        score_one(path, model, ids, mat, dids, dlabels, dmat, scale, evidence)


def preprocess(img: Image.Image) -> Image.Image:
    """Resize short side to 256, then centre crop 256x256.

    This mirrors `request.imageCropAndScaleOption = .centerCrop` in
    HabitClassifier.swift. Get it wrong — squash the frame to a square instead of
    cropping it — and every embedding shifts, which shows up as scores that are
    plausible but wrong rather than as an error.

    Scale and colour normalisation are baked into the .mlpackage itself, so
    nothing else is applied here.
    """
    w, h = img.size
    scale = INPUT_SIZE / min(w, h)
    img = img.resize((round(w * scale), round(h * scale)), Image.BICUBIC)
    w, h = img.size
    left, top = (w - INPUT_SIZE) // 2, (h - INPUT_SIZE) // 2
    return img.crop((left, top, left + INPUT_SIZE, top + INPUT_SIZE))


def score_one(path, model, ids, mat, dids, dlabels, dmat, scale, evidence) -> None:
    try:
        img = Image.open(path).convert("RGB")  # PIL applies no EXIF rotation; Vision does
    except Exception as exc:                   # noqa: BLE001 - report and keep going
        print(f"\n{path}: cannot open ({exc})")
        return

    emb = model.predict({"image": preprocess(img)})["final_emb_1"]
    vec = np.asarray(emb, dtype=np.float64).ravel()
    assert np.isfinite(vec).all(), "image tower returned a non-finite embedding"
    vec = vec / np.linalg.norm(vec)   # L2-normalise, same as HabitClassifier.swift

    hcos = (mat @ vec).tolist()
    dcos = (dmat @ vec).tolist()

    # Softmax over the WHOLE field, exactly as the app does. Over habits alone
    # the winner's share is meaningless — the shares are forced to sum to 1
    # among options that might all be wrong.
    logits = np.array(hcos + dcos) * scale
    exp = np.exp(logits - logits.max())    # shift before exp or float overflows
    probs = (exp / exp.sum()).tolist()

    order = sorted(range(len(ids)), key=lambda k: -hcos[k])
    top = order[0]
    runner = order[1] if len(order) > 1 else None
    dtop = max(range(len(dids)), key=lambda k: dcos[k])

    print(f"\n=== {path}")
    print(f"    {'habit':<32} {'cosine':>7} {'conf':>7}  evidence")
    for i in order[:5]:
        print(f"    {ids[i]:<32} {hcos[i]:>7.4f} {probs[i]:>6.1%}  {evidence.get(ids[i], '?')}")
    print(f"    {'-' * 32}")
    for k in sorted(range(len(dids)), key=lambda k: -dcos[k])[:3]:
        mark = "  <-- beats every habit" if dcos[k] >= hcos[top] else ""
        print(f"    {dlabels[k]:<32} {dcos[k]:>7.4f} "
              f"{probs[len(ids) + k]:>6.1%}{mark}")

    # --- the same gates, in the same order, as HabitClassifier.verdict() -----

    if dcos[dtop] >= hcos[top]:
        print(f"\n    VERDICT  rejected — looks like {dlabels[dtop]}")
        return

    if hcos[top] < MIN_SIMILARITY:
        print(f"\n    VERDICT  nothing (top {hcos[top]:.4f} < min {MIN_SIMILARITY})")
        return

    clear_runner = runner is None or (hcos[top] - hcos[runner]) >= DECISIVE_MARGIN
    clear_distractor = (hcos[top] - dcos[dtop]) >= DISTRACTOR_MARGIN
    direct = evidence.get(ids[top]) == "direct"
    confident = probs[top] >= AUTO_LOG_CONFIDENCE
    scored = hcos[top] >= AUTO_LOG_SIMILARITY

    if direct and scored and confident and clear_runner and clear_distractor:
        print(f"\n    VERDICT  AUTO-LOG {ids[top]}")
        return

    print(f"\n    VERDICT  asks the user  ({ids[top]})")
    why = []
    if not direct:
        why.append(f"evidence is {evidence.get(ids[top], '?')}, only 'direct' auto-logs")
    if not scored:
        why.append(f"cosine {hcos[top]:.4f} < {AUTO_LOG_SIMILARITY}")
    if not confident:
        why.append(f"confidence {probs[top]:.1%} < {AUTO_LOG_CONFIDENCE:.0%}")
    if not clear_runner:
        why.append(f"only {hcos[top] - hcos[runner]:+.4f} over {ids[runner]}")
    if not clear_distractor:
        why.append(f"only {hcos[top] - dcos[dtop]:+.4f} over '{dlabels[dtop]}'")
    for reason in why:
        print(f"             - {reason}")


if __name__ == "__main__":
    main()
