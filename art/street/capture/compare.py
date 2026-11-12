"""Compare an untouched Godot capture with the canonical 852 × 480 street frame.

Usage: python3 street/capture/compare.py captures/street/final/main.png
Requires NumPy for color math, SciPy for mask contours and FFmpeg for image I/O.
"""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from scipy.ndimage import binary_erosion

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "docs/references/street_target.jpg"
WIDTH, HEIGHT = 852, 480
WATERMARK = (635, 8, 852, 54)
# Fixed in original image coordinates. End points are exclusive.
REGIONS = {
    "upper_sky": (334, 52, 349, 67),
    "lower_left_sky": (25, 330, 40, 345),
    "teal_roof": (211, 305, 224, 316),
    "umber_roof": (286, 354, 307, 365),
    "umber_light_wall": (304, 389, 318, 399),
    "asphalt": (598, 365, 608, 372),
    "grass_beside_house": (358, 393, 366, 404),
    "main_cherry_highlight": (504, 316, 517, 325),
    "main_cherry_shadow": (467, 313, 476, 322),
    "main_cherry_upper_pink": (530, 253, 539, 262),
    "left_front_hedge": (188, 400, 197, 408),
    "platform_face": (355, 234, 372, 243),
    "platform_safety_stripe": (470, 231, 481, 235),
}
CROWN_REGIONS = {
    "front_left": (110, 298, 215, 386),
    "middle_left": (242, 251, 367, 341),
    "main": (414, 235, 563, 356),
    "front_small": (365, 337, 441, 418),
    "back": (489, 99, 595, 174),
    "back_right": (639, 150, 711, 207)
}


def decode_image(path):
    """Decode without auto-cropping or exposure adjustment."""
    command = ["ffmpeg", "-loglevel", "error", "-i", str(path), "-vf",
               f"scale={WIDTH}:{HEIGHT}:flags=lanczos", "-frames:v", "1",
               "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    size_raw = subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height", "-of", "json", str(path)])
    size = json.loads(size_raw)["streams"][0]
    if size["width"] * HEIGHT != size["height"] * WIDTH:
        raise ValueError(f"Wrong capture aspect ratio: {size}. Expected {WIDTH}:{HEIGHT}.")
    output = subprocess.check_output(command)
    return np.frombuffer(output, dtype=np.uint8).reshape(HEIGHT, WIDTH, 3)


def save_png(path, pixels):
    height, width = pixels.shape[:2]
    command = ["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo",
               "-pix_fmt", "rgb24", "-s", f"{width}x{height}", "-i", "-",
               "-frames:v", "1", str(path)]
    subprocess.run(command, input=pixels.astype(np.uint8).tobytes(), check=True)


def to_lab(rgb):
    s = rgb.astype(np.float64) / 255.0
    linear = np.where(s <= 0.04045, s / 12.92, ((s + 0.055) / 1.055) ** 2.4)
    xyz = linear @ np.array([[0.4124564, 0.3575761, 0.1804375],
                             [0.2126729, 0.7151522, 0.0721750],
                             [0.0193339, 0.1191920, 0.9503041]]).T
    xyz /= [0.95047, 1.0, 1.08883]
    delta = 6 / 29
    f = np.where(xyz > delta**3, np.cbrt(xyz), xyz / (3 * delta**2) + 4 / 29)
    return np.stack([116*f[..., 1] - 16, 500*(f[..., 0] - f[..., 1]),
                     200*(f[..., 1] - f[..., 2])], axis=-1)


def ciede2000(first, second):
    """CIEDE2000 for D65 Lab arrays, using kL = kC = kH = 1."""
    l1, a1, b1 = np.moveaxis(first, -1, 0)
    l2, a2, b2 = np.moveaxis(second, -1, 0)
    c_mean = (np.hypot(a1, b1) + np.hypot(a2, b2)) * 0.5
    factor = 1.5 - 0.5 * np.sqrt(c_mean**7 / (c_mean**7 + 25**7))
    a1, a2 = a1*factor, a2*factor
    c1, c2 = np.hypot(a1, b1), np.hypot(a2, b2)
    h1 = np.degrees(np.arctan2(b1, a1)) % 360
    h2 = np.degrees(np.arctan2(b2, a2)) % 360
    chroma = np.sqrt(c1*c2)
    angle = h2 - h1
    d_hue = np.where(angle > 180, angle - 360, np.where(angle < -180, angle + 360, angle))
    d_hue = np.where(chroma == 0, 0, d_hue)
    d_h = 2 * chroma * np.sin(np.radians(d_hue/2))
    h_sum = h1+h2
    mean_h = np.where(np.abs(angle) <= 180, h_sum/2,
                      np.where(h_sum < 360, (h_sum+360)/2, (h_sum-360)/2))
    mean_h = np.where(chroma == 0, h_sum, mean_h)
    mean_c = (c1+c2)/2
    mean_l = (l1+l2)/2 - 50
    weights = (1 - 0.17*np.cos(np.radians(mean_h-30)) + 0.24*np.cos(np.radians(2*mean_h))
               + 0.32*np.cos(np.radians(3*mean_h+6)) - 0.20*np.cos(np.radians(4*mean_h-63)))
    d_l = (l2-l1) / (1 + 0.015*mean_l**2 / np.sqrt(20+mean_l**2))
    d_c = (c2-c1) / (1 + 0.045*mean_c)
    d_h /= 1 + 0.015*mean_c*weights
    rotation = (-2*np.sqrt(mean_c**7 / (mean_c**7 + 25**7))
                * np.sin(np.radians(60*np.exp(-((mean_h-275)/25)**2))))
    return np.sqrt(np.maximum(0, d_l**2 + d_c**2 + d_h**2 + rotation*d_c*d_h))


def box_slice(rect):
    x0, y0, x1, y1 = rect
    return np.s_[y0:y1, x0:x1]


def rounded(values):
    return np.asarray(values).round(3).tolist()


def heatmap(delta, valid):
    # Dark blue = 0, cyan = 5, yellow = 12, red >= 30 ΔE00. Gray = ignored.
    stops = np.array([[15, 22, 52], [48, 185, 226], [255, 213, 88], [222, 61, 57]])
    output = np.stack([np.interp(delta, [0, 5, 12, 30], stops[:, i]) for i in range(3)], axis=-1)
    output[~valid] = 81
    return output


def pink_mask(image):
    rgb = image.astype(float)
    r, g, b = np.moveaxis(rgb, -1, 0)
    return (r > 150) & (r > g+9) & (b > g+6) & (r+2 >= b)


def crowns(reference, capture):
    """Describe the *visible pink pixels* in fixed crops, including occlusion."""
    contour = (reference * 0.72).astype(np.uint8)
    results = {}
    for name, rect in CROWN_REGIONS.items():
        area = box_slice(rect)
        orig, rendered = pink_mask(reference[area]), pink_mask(capture[area])
        overlap = np.count_nonzero(orig & rendered)
        union = np.count_nonzero(orig | rendered)
        centers = []
        for mask in [orig, rendered]:
            y, x = np.nonzero(mask)
            centers.append([round(float(x.mean() + rect[0]), 2), round(float(y.mean() + rect[1]), 2)] if len(x) else None)
        results[name] = {
            "roi": rect, "visible_pink_centers_xy": centers, "target_pixels": int(orig.sum()),
            "capture_pixels": int(rendered.sum()), "iou": round(overlap/union, 3) if union else None}
        target_edge = orig & ~binary_erosion(orig)
        render_edge = rendered & ~binary_erosion(rendered)
        contour[area][target_edge] = [56, 238, 224]
        contour[area][render_edge] = [255, 90, 100]
        contour[area][target_edge & render_edge] = [255, 255, 255]
    return results, contour


def compare(capture_path, out):
    reference = decode_image(REFERENCE)
    capture = decode_image(capture_path)
    delta = ciede2000(to_lab(reference), to_lab(capture))
    valid = np.ones((HEIGHT, WIDTH), dtype=bool)
    valid[box_slice(WATERMARK)] = False
    region_metrics = {}
    for name, box in REGIONS.items():
        crop = box_slice(box)
        region_metrics[name] = {
            "xyxy_exclusive": box, "median_pixel_delta_e00": rounded(np.median(delta[crop])),
            "median_target_srgb": rounded(np.median(reference[crop], axis=(0, 1))),
            "median_capture_srgb": rounded(np.median(capture[crop], axis=(0, 1)))}
    crown_metrics, contour = crowns(reference, capture)
    medians = [v["median_pixel_delta_e00"] for v in region_metrics.values()]
    out.mkdir(parents=True, exist_ok=True)
    save_png(out / "side_by_side.png", np.concatenate([reference, capture], axis=1))
    save_png(out / "overlay_50.png", np.rint((reference.astype(float) + capture) / 2))
    save_png(out / "delta_e00_heatmap.png", heatmap(delta, valid))
    save_png(out / "cherry_contours.png", contour)
    summary = {
        "reference_sha256": hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
        "capture": str(capture_path), "capture_sha256": hashlib.sha256(Path(capture_path).read_bytes()).hexdigest(),
        "compare_size": [WIDTH, HEIGHT], "watermark_exclusion_xyxy": WATERMARK,
        "method": "sRGB D65 to CIELAB, per-pixel CIEDE2000; no registration. ROI statistics mix material and layout error.",
        "overlay": "Equal weight RGB blend of reference and capture.",
        "heatmap": "0 navy, 5 cyan, 12 yellow, >=30 red, masked watermark gray.",
        "cherry_contours": "Thresholded visible pink occupancy, cyan = reference, red = capture, white = shared edge; background and occluders can affect boundaries.",
        "whole_frame_delta_e00_median": rounded(np.median(delta[valid])),
        "median_of_roi_medians": rounded(np.median(medians)),
        "roi_count_with_median_at_most_8": sum(v <= 8 for v in medians),
        "regions": region_metrics, "cherry_regions": crown_metrics}
    (out / "comparison.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"{out}: ROI median ΔE00 = {summary['median_of_roi_medians']}; "
          f"{summary['roi_count_with_median_at_most_8']}/{len(REGIONS)} regions at or below 8.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    compare(args.capture, args.out or (args.capture.parent / "comparison"))
