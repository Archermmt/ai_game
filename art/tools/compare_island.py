"""Compare a pair of island renders with the original 852 × 480 reference frame.

Run from any directory with Python 3, NumPy, SciPy, Pillow and FFmpeg installed:
    python3 tools/compare_island.py
    python3 tools/compare_island.py --after captures/island/optimization/final_soft.png --output /tmp/island_test.json
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))
from street.capture.compare import HEIGHT, WIDTH, box_slice, ciede2000, decode_image, to_lab

REFERENCE = PROJECT / "docs/examples/island/reference.jpg"
CAPTURES = PROJECT / "captures/island"
EXCLUSIONS = {
    "upper_left_video_watermark": (0, 0, 209, 50),
    "desktop_taskbar": (0, 457, WIDTH, HEIGHT),
}
# Fixed rectangles in the recorded frame, independent of which render is loaded.
REGIONS = {
    "sky_right": (680, 19, 740, 46),
    "lake_far": (660, 96, 730, 112),
    "lake_middle": (657, 161, 736, 190),
    "lake_near": (665, 335, 744, 367),
    "crown_bright": (464, 55, 500, 99),
    "crown_center": (412, 62, 453, 107),
    "crown_dark": (360, 65, 388, 101),
    "grass": (411, 291, 442, 306),
    "undershore": (336, 319, 395, 330),
    "reflected_tree": (443, 411, 470, 438),
    "reflected_center": (402, 405, 437, 427),
}
LOW_FREQUENCY_SIGMA_PX = 3.0
POLYGONS = {
    "crown": [(340, 17), (495, 15), (534, 75), (521, 151), (439, 167), (351, 132)],
    "house": [(288, 153), (464, 154), (464, 271), (311, 288), (285, 230)],
    "meadow": [(202, 253), (294, 249), (308, 282), (454, 259), (526, 251),
               (563, 286), (542, 316), (422, 346), (241, 332), (203, 305)],
    "waterline": [(204, 310), (320, 323), (407, 327), (519, 310), (560, 294),
                  (554, 324), (445, 351), (325, 355), (218, 334)],
    "house_reflection": [(300, 344), (457, 340), (471, 386), (351, 420), (304, 392)],
    "crown_reflection": [(359, 413), (435, 377), (503, 386), (520, 417), (508, 455), (349, 455)],
    "sky_halo": [(524, 75), (582, 85), (581, 229), (467, 239), (465, 160), (512, 142)],
}


def compare_low_frequencies(paths, valid):
    # Match the broad-region calibration, including its decoder and resampler.
    blurred = {}
    for role, path in paths.items():
        with Image.open(path) as image:
            rgb = image.convert("RGB").resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            blurred[role] = gaussian_filter(
                np.asarray(rgb, dtype=float), sigma=(LOW_FREQUENCY_SIGMA_PX, LOW_FREQUENCY_SIGMA_PX, 0)
            )
    regions = {}
    for name, vertices in POLYGONS.items():
        mask = Image.new("1", (WIDTH, HEIGHT))
        ImageDraw.Draw(mask).polygon(vertices, fill=1)
        keep = np.asarray(mask, dtype=bool) & valid
        reference_lab = to_lab(blurred["reference"][keep])
        region = {"polygon_xy": vertices, "sigma_px": LOW_FREQUENCY_SIGMA_PX, "pixels": int(keep.sum())}
        for role in ("before", "after"):
            delta = ciede2000(reference_lab, to_lab(blurred[role][keep]))
            region[role] = {"median_delta_e00_to_reference": round(float(np.median(delta)), 3)}
        regions[name] = region
    return regions


def source(path):
    absolute = path.resolve()
    label = absolute.relative_to(PROJECT) if absolute.is_relative_to(PROJECT) else absolute
    return {"file": str(label), "sha256": hashlib.sha256(absolute.read_bytes()).hexdigest()}


def compare(before, after):
    paths = {"reference": REFERENCE, "before": before, "after": after}
    images = {name: decode_image(path) for name, path in paths.items()}
    valid = np.ones((HEIGHT, WIDTH), dtype=bool)
    for bounds in EXCLUSIONS.values():
        valid[box_slice(bounds)] = False
    report = {
        "sources": {name: source(path) for name, path in paths.items()},
        "compare_size_px": [WIDTH, HEIGHT],
        "coordinate_convention": "Pixel coordinates from the top left, (x0,y0,x1,y1), upper bounds exclusive.",
        "excluded_xyxy": EXCLUSIONS,
        "method": "Each input is decoded and resampled to 852 x 480 with Lanczos, without color matching or content registration. For each fixed ROI, sRGB values are on the 0-255 scale. L* percentiles use D65 CIELAB. Each reported median CIEDE2000 is computed from individual corresponding pixel pairs (kL=kC=kH=1).",
        "interpretation": "Changed geometry, silhouettes and occlusion can place different surfaces inside the same fixed ROI. These are per-region diagnostics and should be reviewed alongside the images.",
        "regions": {},
    }
    for name, bounds in REGIONS.items():
        area = box_slice(bounds)
        keep = valid[area]
        count = int(keep.sum())
        if not count:
            raise ValueError(f"All pixels in {name} were excluded.")
        rgb = {role: image[area][keep] for role, image in images.items()}
        lab = {role: to_lab(samples) for role, samples in rgb.items()}
        measures = {"xyxy": bounds, "pixels": count}
        for role, samples in rgb.items():
            measures[role] = {
                "median_srgb": np.median(samples, axis=0).tolist(),
                "lstar_p10_p50_p90": np.percentile(lab[role][:, 0], [10, 50, 90]).round(3).tolist(),
            }
        for role in ("before", "after"):
            per_pixel = ciede2000(lab["reference"], lab[role])
            measures[role]["median_delta_e00_to_reference"] = round(float(np.median(per_pixel)), 3)
        report["regions"][name] = measures
    report["low_frequency_method"] = (
        "Pillow RGB Lanczos resize to 852 x 480; Gaussian filter on floating-point sRGB with "
        "sigma 3 pixels on each spatial axis and no channel mixing, before conversion to D65 Lab. "
        "Median CIEDE2000 over corresponding pixel pairs inside each fixed polygon, excluding the marked overlays."
    )
    report["low_frequency_regions"] = compare_low_frequencies(paths, valid)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, default=CAPTURES / "optimization/before.png")
    parser.add_argument("--after", type=Path, default=CAPTURES / "final.png")
    parser.add_argument("--output", type=Path, default=CAPTURES / "color_review.json")
    args = parser.parse_args()
    report = compare(args.before, args.after)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{len(report['regions'])} original ROIs and {len(report['low_frequency_regions'])} "
          f"low-frequency polygons written to {args.output}")


if __name__ == "__main__":
    main()
