"""Rebuild the cabin reference comparison and its fixed color sample report."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT))
from street.capture.compare import ciede2000, save_png, to_lab

REFERENCE = PROJECT / "docs/examples/cabin/reference.jpg"
CAPTURES = PROJECT / "captures/cabin"
BOXES = {
    "understory": (480, 65, 610, 161),
    "upper_left_forest": (157, 12, 330, 115),
    "lit_meadow": (314, 412, 432, 462),
    "slate": (375, 222, 402, 271),
    "pond": (578, 333, 613, 353),
    "lower_left_foliage": (64, 382, 197, 455),
    "lower_right_foliage": (680, 383, 825, 456),
}


def frame(path):
    fit = "scale=854:478:force_original_aspect_ratio=decrease,pad=854:478:(ow-iw)/2:(oh-ih)/2"
    raw = subprocess.check_output(["ffmpeg", "-loglevel", "error", "-i", str(path),
                                   "-vf", fit, "-frames:v", "1", "-pix_fmt", "rgb24", "-f", "rawvideo", "-"])
    return np.frombuffer(raw, np.uint8).reshape(478, 854, 3)


def color_error(a, b):
    return round(float(ciede2000(to_lab(a), to_lab(b))), 2)


ART_REGIONS = {
    "forest_behind_cottage": [(156,35),(670,35),(670,235),(526,253),(496,191),(357,195),(350,255),(156,279)],
    "blue_slate_and_chimney": [(351,208),(456,192),(456,161),(481,158),(483,192),(501,190),(521,287),(377,320),(350,261)],
    "cottage_and_deck": [(307,290),(373,285),(378,311),(503,285),(506,343),(443,369),(379,359),(318,358)],
    "pond_and_shore": [(534,344),(566,316),(623,302),(673,304),(683,337),(664,372),(589,382),(539,368)],
    "meadow_and_figures": [(280,391),(351,369),(390,362),(437,372),(505,376),(486,410),(439,440),(408,473),(310,473),(283,440)],
    "foreground_left": [(0,316),(140,316),(266,380),(360,450),(343,477),(0,477)],
    "foreground_right": [(417,477),(494,401),(586,353),(698,328),(804,300),(853,247),(853,477)],
}


def regional_review(reference, before, current):
    # Smooth at reference resolution to measure large shapes and value groups.
    lab = [to_lab(gaussian_filter(image.astype(float),sigma=(3,3,0))) for image in (reference,before,current)]
    differences = [ciede2000(lab[0],other) for other in lab[1:]]
    regions = {}
    for name, vertices in ART_REGIONS.items():
        mask = Image.new("L",(854,478))
        ImageDraw.Draw(mask).polygon(vertices,fill=1)
        selected = np.asarray(mask).astype(bool)
        # Exclude the weather panel and upper-right video signature.
        selected[:314,:153] = False
        selected[:54,675:] = False
        regions[name] = {"polygon_xy":vertices,"pixels":int(selected.sum()),
                         "previous_deltaE00":round(float(np.median(differences[0][selected])),2),
                         "current_deltaE00":round(float(np.median(differences[1][selected])),2)}
    return regions


def report(previous=None):
    final_file = CAPTURES / "final.png"
    images = [frame(p) for p in (REFERENCE, CAPTURES / "palette_pass.png", final_file)]
    regions = {}
    for name, (x, y, end_x, end_y) in BOXES.items():
        target, draft, final = [np.median(im[y:end_y, x:end_x], axis=(0, 1)) for im in images]
        regions[name] = {
            "xyxy": [x, y, end_x, end_y], "target_median_sRGB": target.tolist(),
            "final_median_sRGB": final.tolist(), "palette_pass_deltaE00": color_error(target, draft),
            "final_deltaE00": color_error(target, final)}
    result = {
        "method": "sRGB D65 CIEDE2000 of target and capture regional median colors. Target UI/watermark excluded. Aspect ratio preserved with padding.",
        "rois": regions, "target": str(REFERENCE.relative_to(PROJECT)), "capture": str(final_file.relative_to(PROJECT)),
        "target_sha256": hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
        "capture_sha256": hashlib.sha256(final_file.read_bytes()).hexdigest()}
    if previous:
        result["previous_file"] = str(previous)
        result["previous_sha256"] = hashlib.sha256(Path(previous).read_bytes()).hexdigest()
        result["shape_comparison_method"] = "Median corresponding-pixel Delta E00 per polygon after Gaussian smoothing in display RGB at sigma=3 reference pixels."
        result["shape_regions"] = regional_review(images[0],frame(previous),images[2])
    (CAPTURES / "color_review.json").write_text(json.dumps(result, indent=2) + "\n")
    save_png(CAPTURES / "comparison.png", np.concatenate([images[0], images[2]], axis=1))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before",type=Path,help="Additional previous capture for a same-camera shape comparison.")
    report(parser.parse_args().before)
