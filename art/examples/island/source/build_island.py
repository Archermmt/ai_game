"""Build the sunset cottage as vertex-colored GLB with Python 3 and numpy."""

from pathlib import Path
import json, math, random, struct
import numpy as np

rng = random.Random(3194)
out = Path(__file__).resolve().parents[1]
parts = {}
part = None


def group(name):
    global part
    part = parts.setdefault(name, ([], [], []))


def color(hex_color):
    return np.array([int(hex_color[i : i + 2], 16) for i in (0, 2, 4)]) / 255


def face(points, rgb, outside=None):
    p = np.array(points, float)
    n = np.cross(p[1] - p[0], p[2] - p[0])
    length = np.linalg.norm(n)
    if length < 1e-8:
        return
    n /= length
    if outside is not None and np.dot(n, p.mean(axis=0) - outside) < 0:
        p = p[::-1]
        n = -n
    srgb = color(rgb) if isinstance(rgb, str) else rgb
    linear = np.where(srgb < 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
    for i in range(1, len(p) - 1):
        part[0].extend((p[0], p[i], p[i + 1]))
        part[1].extend((n, n, n))
        part[2].extend((linear, linear, linear))


def hull(points, faces, col):
    ctr = np.mean(points, axis=0)
    for f in faces:
        face([points[i] for i in f], col, ctr)


def box(x, y, z, w, h, d, col):
    p = [
        (x + sx * w / 2, y + sy * h / 2, z + sz * d / 2)
        for sy in (-1, 1)
        for sz in (-1, 1)
        for sx in (-1, 1)
    ]
    hull(
        p,
        [
            (0, 1, 3, 2),
            (4, 6, 7, 5),
            (0, 4, 5, 1),
            (2, 3, 7, 6),
            (1, 5, 7, 3),
            (0, 2, 6, 4),
        ],
        col,
    )


def beam(a, b, r, col, n=5, r2=None):
    a = np.array(a)
    b = np.array(b)
    v = b - a
    v = v / np.linalg.norm(v)
    first = np.cross(v, (1, 0, 0) if abs(v[0]) < 0.8 else (0, 1, 0))
    first /= np.linalg.norm(first)
    second = np.cross(v, first)
    c = (a + b) / 2
    rings = [
        [
            ctr
            + (r if j == 0 else (r if r2 is None else r2))
            * (first * math.cos(i * math.tau / n) + second * math.sin(i * math.tau / n))
            for i in range(n)
        ]
        for j, ctr in enumerate([a, b])
    ]
    for i in range(n):
        face([rings[0][i - 1], rings[1][i - 1], rings[1][i], rings[0][i]], col, c)
    face(rings[1], col, c)
    face(rings[0], col, c)


def blob(x, y, z, rx, ry, rz, col, seg=8, levels=4, rough=0.10):
    start = len(part[0])
    ctr = np.array([x, y, z])
    rings = []
    for j in range(1, levels):
        a = math.pi * j / levels
        row = []
        for i in range(seg):
            ang = (i + (j % 2) * 0.35) * math.tau / seg
            v = 1 + rng.uniform(-rough, rough)
            row.append(
                (
                    x + rx * math.sin(a) * math.cos(ang) * v,
                    y + ry * math.cos(a) * v,
                    z + rz * math.sin(a) * math.sin(ang) * v,
                )
            )
        rings.append(row)
    for i in range(seg):
        face([(x, y + ry, z), rings[0][i - 1], rings[0][i]], col, ctr)
        face([(x, y - ry, z), rings[-1][i], rings[-1][i - 1]], col, ctr)
        for j in range(len(rings) - 1):
            a, b, c, d = (
                rings[j][i - 1],
                rings[j][i],
                rings[j + 1][i],
                rings[j + 1][i - 1],
            )
            face([a, b, c], col, ctr)
            face([a, c, d], col, ctr)
    if part is parts.get("AutumnOak"):
        for i in range(start, len(part[0])):
            n = (part[0][i] - ctr) / np.array([rx * rx, ry * ry, rz * rz])
            part[1][i] = n / np.linalg.norm(n)


def surface(x, z):
    radius = math.hypot(x / 5.95, z / 4.14)
    lip = min(1.0, max(0.0, (radius - 0.77) / 0.23))
    azimuth = math.atan2(z / 4.14, x / 5.95)
    scoured = 0.095 * math.sin(8 * azimuth + 0.25) + 0.045 * math.cos(15 * azimuth - 0.7)
    return (
        lip * scoured +
        0.40
        + 0.74 * (1 - (x / 6) ** 2 - (z / 4.25) ** 2)
        + 0.10 * math.sin(x * 0.92 + z * 0.56)
    )


# A separate stream keeps additions to wooden joinery and tile edges from
# changing the placement of the grass, stones, or canopy.
house_detail_rng = random.Random(721)


def roof(x, z, width, depth, base, rise, rotate=False):
    # u along ridge, v runs from the ridge to the eave.
    def point(u, v, h):
        return (x + v if rotate else x + u, h, z + u if rotate else z + v)

    for side in [-1, 1]:
        corners = [
            point(-width / 2, 0, base + rise),
            point(width / 2, 0, base + rise),
            point(width / 2, side * depth / 2, base),
            point(-width / 2, side * depth / 2, base),
        ]
        face(corners, "955239", (x, base - 0.2, z))
        rows = max(4, int(depth * 3.65))
        cols = max(6, int(width * 5.6))
        for j in range(rows):
            v1 = depth * 0.5 * j / rows
            v2 = depth * 0.5 * (j + 1) / rows
            for i in range(-1, cols):
                u1 = max(-width / 2, -width / 2 + (i + (j % 2) * 0.5) * width / cols)
                u2 = min(
                    width / 2,
                    -width / 2 + (i + 1 + (j % 2) * 0.5) * width / cols - 0.009,
                )
                if u2 <= u1:
                    continue
                high = base + rise * (1 - 2 * v1 / depth) + 0.027
                low = (
                    base
                    + rise * (1 - 2 * v2 / depth)
                    + 0.012
                    + rng.uniform(-0.009, 0.009)
                )
                # Slightly bowed lower noses overlap the next row of handmade clay tiles.
                gap = house_detail_rng.uniform(0.003, 0.016)
                lip = house_detail_rng.uniform(0.010, 0.027)
                um = (u1 + u2) * 0.5
                toe_v = v2 + house_detail_rng.uniform(0.008, 0.026)
                toe_y = low - (toe_v - v2) * rise * 2 / depth
                first = point(u1, side * v1, high)
                second = point(u2, side * v1, high)
                nose = [
                    point(u2 - gap, side * v2, low),
                    point(um, side * toe_v, toe_y + 0.006),
                    point(u1 + gap, side * v2, low),
                ]
                col = rng.choice(
                    [
                        "a96347",
                        "ba6747",
                        "bd7152",
                        "c37c59",
                        "ac5e41",
                        "be7758",
                        "b3694d",
                    ]
                )
                outside = (x, base - 0.5, z)
                tint = color(col) * house_detail_rng.uniform(0.95, 1.035)
                face([first, second, *nose], tint, outside)
                under = [
                    point(u2 - gap, side * v2, low - lip),
                    point(um, side * toe_v, toe_y + 0.006 - lip),
                    point(u1 + gap, side * v2, low - lip),
                ]
                for j in range(2):
                    face(
                        [nose[j], nose[j + 1], under[j + 1], under[j]],
                        tint * 0.80,
                        outside,
                    )
        beam(
            point(-width / 2, side * depth / 2, base - 0.015),
            point(width / 2, side * depth / 2, base - 0.015),
            0.047,
            "774929",
            6,
        )
    # Ridge caps overlap slightly, giving a shallow segmented silhouette.
    cap_count = max(2, round(width / 0.32))
    for i in range(cap_count):
        start = -width / 2 + i * width / cap_count
        end = start + width / cap_count + 0.018
        beam(
            point(start, 0, base + rise + 0.030),
            point(end, 0, base + rise + 0.033),
            0.066,
            house_detail_rng.choice(["a76549", "aa6a4c", "ac6d50"]),
            8,
            0.052,
        )
    for side in [-1, 1]:
        u = side * (width / 2 - 0.09)
        q = [
            point(u, 0, base + rise - 0.03),
            point(u, -depth / 2 + 0.1, base - 0.01),
            point(u, depth / 2 - 0.1, base - 0.01),
        ]
        if rotate and width > 2:
            # Terrain and triangles stay independent of this pigment-only wash.
            # Barycentric vertices give gradual aging under the two eaves.
            top, left, right = (np.array(c) for c in q)
            subdivisions = 13
            def sample(i, j):
                return top + (left-top)*i/subdivisions + (right-top)*j/subdivisions
            def paint_triangle(points):
                start = len(part[0])
                face(points, "e0c49a", (x,base-.25,z))
                for index in range(start,len(part[0])):
                    px,py,pz = part[0][index]
                    local_x, local_y = px-x, py-base
                    fade = max(0.,1.-local_y/rise)
                    edge = min(1.,abs(local_x)/max(.045,depth*.50*fade))
                    age = .08+.19*edge**2+.07*fade + .11*(
                        .5+.5*math.sin(local_x*7.4+local_y*3.9)*math.cos(local_y*8.3))
                    age += .18*math.exp(-((local_x+.52)/.34)**2-((local_y-.27)/.44)**2)
                    pigment = color('e9d1af')*(1-age)+color('b1936c')*age
                    part[2][index] = np.where(pigment<=.04045,pigment/12.92,
                                             ((pigment+.055)/1.055)**2.4)
            for i in range(subdivisions):
                for j in range(subdivisions-i):
                    paint_triangle([sample(i,j), sample(i+1,j), sample(i,j+1)])
                    if i+j+1 < subdivisions:
                        paint_triangle([sample(i+1,j), sample(i+1,j+1), sample(i,j+1)])
        else:
            face(q, "dec09b", (x, base - 0.25, z))
        for s in [-1, 1]:
            beam(
                point(side * width / 2, 0, base + rise),
                point(side * width / 2, s * depth / 2, base),
                0.063,
                "78492e",
                5,
            )
        beam(
            point(u, 0, base - 0.02),
            point(u, 0, base + rise - 0.04),
            0.065,
            "815136",
            4,
        )


def painted_leaf(center, width, height, pigment, yaw=0.0):
    x, y, z = center
    c, s = math.cos(yaw), math.sin(yaw)
    face(
        [
            (x - c * width, y, z - s * width),
            (x, y + height, z + 0.015),
            (x + c * width, y, z + s * width),
            (x, y - height * 0.40, z - 0.01),
        ],
        pigment,
        (x, y - 0.35, z - 0.35),
    )


def window(x, y, z, w, h, flowers=False):
    # A recessed dark field, casement, little sill and thin stiles. The
    # palette picks up the surrounding timber instead of opaque grey panes.
    wood, edge = "735039", "966944"
    box(x, y, z, w + 0.10, h + 0.12, 0.092, wood)
    box(x, y, z + 0.053, w, h, 0.030, "73604b")
    for j, glaze in enumerate(["816e58", "78634c", "70604f"]):
        box(
            x + (j - 1) * w / 3,
            y + h * 0.10,
            z + 0.074,
            w / 3 - 0.025,
            h * 0.69,
            0.01,
            glaze,
        )
    for u in [-w / 6, w / 6]:
        box(x + u, y, z + 0.088, 0.021, h, 0.026, edge)
    box(x, y + h * 0.16, z + 0.091, w, 0.024, 0.028, "89664a")
    box(x, y - h * 0.50 - 0.036, z + 0.075, w + 0.17, 0.058, 0.19, edge)
    if flowers:
        flower_box(x, y - h * 0.5 - 0.065, z + 0.085, w + 0.12)


def flower_box(x, y, z, w):
    box(x, y, z + 0.095, w, 0.105, 0.175, "896042")
    box(x, y + 0.047, z + 0.19, w + 0.026, 0.026, 0.034, "a1744c")
    for j in range(max(5, int(w * 17))):
        px = x + house_detail_rng.uniform(-0.44, 0.44) * w
        pz = z + house_detail_rng.uniform(0.060, 0.18)
        py = y + house_detail_rng.uniform(0.09, 0.17)
        painted_leaf(
            (px, py, pz),
            0.031,
            0.056,
            house_detail_rng.choice(["758155", "818950", "667949"]),
            house_detail_rng.uniform(-0.8, 0.8),
        )
        if j % 2 == 0:
            painted_leaf(
                (px + 0.012, py + 0.046, pz + 0.014),
                0.024,
                0.029,
                house_detail_rng.choice(["be93ac", "ccb8c7", "c7b48b"]),
            )


    for j in range(4):
        px=x-w*.42+j*w*.26
        py=y+.073+.036*math.sin(j*2.7+x)
        painted_leaf((px,py,z+.205),.037,.047,
                     ["99a169","83945c","a6a667","83965e"][j],.21+j*.16)
        painted_leaf((px+.010,py+.066,z+.168),.027,.029,
                     ["d3b4b8","c7a0ab","d3c29b","c3a2b8"][j])


group("TurfAndEarth")
n = 64
outline = []
for i in range(n):
    a = i * math.tau / n
    rr = (
        1
        + 0.038 * math.sin(3 * a)
        + 0.022 * math.cos(7 * a)
        + max(0.0, math.sin(a)) * (0.032 * math.sin(6 * a + 0.8) + 0.024 * math.cos(14 * a))
        + rng.uniform(-0.018, 0.018)
    )
    x, z = 5.95 * rr * math.cos(a), 4.14 * rr * math.sin(a)
    outline.append((x, surface(x, z), z))
# The upper sod breaks into a damp undercut, then a sloping gravel skirt.
# Construct shared per-vertex profiles so the facets join continuously.
def bank_profile(point):
    x,y,z = point
    az = math.atan2(z/4.14, x/5.95)
    wash = .5+.5*math.sin(7*az+.51)*math.cos(4*az-.6)
    moss_drop = .055+.12*wash+.025*math.cos(19*az)
    return [
        (x,y,z),
        (x*1.003,y-moss_drop,z*1.003),
        (x*(.989+.008*wash),max(.065,(y-moss_drop)*.49),z*(.989+.008*wash)),
        (x*(1.018+.013*wash),.018+.045*wash,z*(1.018+.013*wash)),
        (x*1.033,-.085,z*1.033),
    ]

profiles = [bank_profile(p) for p in outline]
for i, p in enumerate(outline):
    q = outline[i - 1]
    col = rng.choice(["6e5140", "826144", "8f6748", "795744"])
    for level,hue in enumerate(["657140",col,"776451","6e6650"]):
        a,b = profiles[i][level:level+2]
        c,d = profiles[i-1][level:level+2]
        face([a,c,d],hue,(0,0,0))
        face([a,d,b],hue,(0,0,0))
    prev = (0, surface(0, 0), 0)
    prevq = prev
    for k in range(1, 6):
        t = k / 5
        a = (p[0] * t, surface(p[0] * t, p[2] * t), p[2] * t)
        b = (q[0] * t, surface(q[0] * t, q[2] * t), q[2] * t)
        face(
            [a, b, prevq],
            rng.choice(["83894c", "899052", "808c49", "86894b"]),
            (0, -10, 0),
        )
        face([a, prevq, prev], rng.choice(["83894c", "8d9353", "86894b"]), (0, -10, 0))
        prev = a
        prevq = b
group("SlateAndCobbles")
# A short upright outcrop breaks the far bank. The broad tilted piece in
# front exposes a single dark face. Only small partly buried chips join them.
# Each block uses two seven-point rings, the same sampling budget as the
# original stones, preserving the random stream for the house and oak.
shore_blocks = [
    # x, z, waterline height, width, height, depth, angle, local stone hue
    (5.28, -2.04, 0.09, 1.42, 1.35, 1.12, -0.23, "b0a28e"),
    (5.59, -1.38, 0.06, 0.42, 0.60, 0.63,  0.33, "938a79"),
    (5.08, -2.56, 0.15, 0.49, 0.68, 0.62,  0.49, "8b897c"),
    (4.91,  1.61, 0.02, 1.53, 1.17, 1.20, -0.32, "958b7a"),
    (4.40,  2.37, 0.01, 0.75, 0.49, 0.73,  0.24, "867b6d"),
    (5.30,  0.89, 0.08, 0.78, 0.65, 0.97,  0.36, "9a9280"),
    (5.62, -0.27, 0.03, 0.44, 0.27, 0.35, -0.25, "8b8370"),
    (5.06,  2.15, 0.01, 0.30, 0.32, 0.46,  0.54, "847a66"),
    (5.35, -2.89, 0.04, 0.33, 0.29, 0.31,  0.17, "a19889"),
    (4.21,  2.78, 0.02, 0.25, 0.24, 0.37, -0.53, "938772"),
]
for x, z, base, width, height, depth, angle, pigment in shore_blocks:
    angle += rng.uniform(-0.055, 0.055)
    width *= rng.uniform(0.96, 1.04)
    height *= rng.uniform(0.96, 1.04)
    depth *= rng.uniform(0.96, 1.04)
    stone = color(pigment) * rng.choice([0.98, 1.0, 1.02, 1.015])
    rings = []
    for upper in [False, True]:
        ring = []
        for j in range(7):
            az = (j + 0.41) * math.tau / 7
            jitter = rng.uniform(-0.095, 0.095)
            r = (0.43 if upper else 0.52) + jitter
            local_x = width * (r * math.cos(az) + (0.13 if upper else 0.0))
            local_z = depth * (r * math.sin(az) - (0.09 if upper else 0.0))
            y = height * (0.82 + 0.23 * math.cos(az - 0.6) + jitter if upper else jitter)
            ring.append(np.array([x + local_x * math.cos(angle) + local_z * math.sin(angle),
                                  base + y,
                                  z - local_x * math.sin(angle) + local_z * math.cos(angle)]))
        rings.append(ring)
    low, high = rings
    if width > 1.1:
        # Three exposed arrises make the near stone a broken wedge. On the
        # far stone a slanted shoulder leads to a short top crest.
        standing = z < 0
        cross_section = (
            [(0.46, .42, .00),(.18, .81, .31),(-.26,.94,.26),(-.42,.69,.02),
             (-.38,.71,-.24),(-.12,1.05,-.30),(.29,.92,-.20)] if standing else
            [(.42,.25,.05),(.14,.24,.34),(-.24,.45,.29),(-.34,.57,.02),
             (-.22,.76,-.20),(.03,1.03,-.19),(.28,.67,-.14)]
        )
        high = [np.array([x+u*width*math.cos(angle)+v*depth*math.sin(angle),
                          base+e*height,
                          z-u*width*math.sin(angle)+v*depth*math.cos(angle)])
                for u,e,v in cross_section]
    center = np.array([x, base + 0.40 * height, z])
    crown = np.mean(high, axis=0) + np.array([0.08 * width, 0.08 * height, -0.06 * depth])
    if width > 1.1:
        crown = high[5] * .74 + high[3] * .26 + np.array([0,.047*height,0])
    for j in range(7):
        k = (j + 1) % 7
        # The near-left fracture retains a deep cool plane even in the warm fill light.
        face_center = (low[j] + high[k]) * 0.5 - center
        dark_face = face_center[2] > 0.01 and face_center[0] < 0
        shade = np.array([0.63, 0.64, 0.67]) if dark_face else np.array([0.93, 0.92, 0.90])
        face([low[j], low[k], high[k], high[j]], stone * shade, center)
        face([high[j], high[k], crown], np.minimum(1, stone * 1.06), center)
for i in range(155):
    sample_z = rng.uniform(0.8, 3.6)
    across = rng.uniform(-0.7, 0.65)
    sample_x = -1.15 - 0.36 * sample_z + across
    if (sample_x / 5.7) ** 2 + (sample_z / 3.9) ** 2 < 0.98:
        # A worn track curves from the log-store threshold to the foot of
        # the porch, then narrows as grass grows between its outer cobbles.
        t = (sample_z - 0.8) / 2.8
        x = -3.20 + 3.55 * t
        z = 2.07 + 0.89 * t + 0.25 * math.sin(t * math.pi) + across * (0.48 + 0.23 * t)
        size = 0.083 + 0.067 * abs(math.sin(i * 1.731)) * (1 - 0.55 * abs(across))
        blob(x, surface(x, z) + 0.030, z, size * 1.22, 0.026, size * 0.72,
             rng.choice(["aa9578", "bcab89", "87836a", "a39b7a"]), 6, 2, 0.18)
group("CottageWalls")
mainx = -0.58
mainz = -0.53
floor = 0.63
eave = 2.93
box(mainx, 1.78, mainz, 4.65, 2.30, 2.16, "e1c7a0")
roof(mainx, mainz, 5.15, 2.66, eave, 2.02)
for x in [-2.85, -1.85, -0.64, 0.42, 1.68]:
    box(x, 1.78, 0.57, 0.085, 2.30, 0.11, "765032")
for y in [0.85, 1.48, 2.82]:
    box(mainx, y, 0.59, 4.72, 0.105, 0.11, "755139")
for x in [-2.62, -0.06, 0.92]:
    beam((x, 0.88, 0.6), (x + 0.58, 1.58, 0.60), 0.054, "755139", 4)
window(0.41, 1.94, 0.605, 0.63, 0.81, flowers=True)
window(1.29, 1.99, 0.605, 0.54, 0.77, flowers=True)
# Front gable projects toward the path; roof ridge is perpendicular to the main ridge.
gx, gz = -2.06, 1.02
box(gx, 1.92, gz, 2.31, 2.24, 1.85, "e6c6a1")
roof(gx, gz, 2.80, 2.67, 3.03, 1.99, True)
front = gz + 0.93
for x in [gx - 1.06, gx + 1.05, gx - 0.40, gx + 0.41]:
    box(x, 1.84, front + 0.012, 0.082, 2.48, 0.085, "79523a")
for y in [0.80, 2.92]:
    box(gx, y, front + 0.013, 2.25, 0.082, 0.085, "7d563b")
# A raised ledged plank door fills the space immediately below the awning.
box(gx, 1.54, front + 0.058, 0.79, 1.79, 0.085, "68482e")
for j in range(6):
    plank = ["936344", "906044", "966747", "936344", "8a5f40", "936546"][j]
    box(gx + (j - 2.5) * 0.112, 1.53, front + 0.112, 0.110, 1.63, 0.036, plank)
box(gx, 2.38, front + 0.108, 0.81, 0.084, 0.084, "7c5537")
box(gx + 0.24, 1.50, front + 0.15, 0.047, 0.075, 0.025, "634936")
window(gx - 0.736, 1.96, front + 0.08, 0.41, 0.61, flowers=True)
for sign in [-1, 1]:
    beam(
        (gx + sign * 0.91, 3.03, 2.4), (gx + sign * 0.35, 4.13, 2.4), 0.055, "77533b", 4
    )
box(gx, 3.59, 2.41, 1.4, 0.12, 0.09, "754d35")
# Entrance awning and rear chimney.
# A transverse lean-to roof shades the entrance below its dark upper shutter.
for j in range(4):
    for i in range(10):
        x1 = gx - 0.94 + i * 0.187
        z1 = 1.92 + j * 0.245
        x2 = x1 + 0.186
        z2 = z1 + 0.246

        def canopy_h(z):
            return 3.02 - 0.58 * (z - 1.92)

        variation = rng.choice([-.027,-.008,.018])
        clay = color("cc9886")*(1-j/5) + color("ad7666")*(j/5)
        shade = 1.0 + variation + .047*math.cos(i*.74-j*.91)
        corners = [(x1,canopy_h(z1),z1),(x2,canopy_h(z1),z1),
                   (x2,canopy_h(z2),z2),(x1,canopy_h(z2),z2)]
        face(corners, np.clip(clay*shade,0,1),(gx,1.9,2.25))
        if j == 3:
            ylip=canopy_h(z2)-.021
            face([corners[3],corners[2],(x2,ylip,z2),(x1,ylip,z2)],
                 np.clip(clay*shade*.80,0,1),(gx,2.2,2.4))

beam(
    (gx - 0.96, canopy_h(2.90), 2.90),
    (gx + 0.96, canopy_h(2.90), 2.90),
    0.033,
    "754e37",
    5,
)
# Paired weathered attic shutters are deep in the gable reveal.
box(gx, 3.59, 2.422, 0.84, 0.71, 0.082, "694b34")
for side in [-1, 1]:
    box(gx + side * 0.19, 3.59, 2.471, 0.356, 0.63, 0.03, "876343")
    for j in range(4):
        box(gx + side * 0.19, 3.36 + j * 0.128, 2.494, 0.337, 0.027, 0.018, "906a48")
box(gx, 3.23, 2.459, 0.89, 0.058, 0.12, "9d7650")
# Exposed west gable flank, seen obliquely from the main camera.
west = gx - 2.31 / 2
for zpost in [gz - 0.87, gz + 0.04, gz + 0.88]:
    box(west - 0.016, 1.91, zpost, 0.086, 2.24, 0.089, "805d42")
for rail_y in [0.82, 2.89]:
    box(west - 0.014, rail_y, gz, 0.089, 0.089, 1.87, "80583e")
box(west - 0.057, 1.94, gz + 0.04, 0.055, 0.62, 0.59, "785841")
for j in range(4):
    box(west - 0.095, 1.94, gz - 0.21 + j * 0.14, 0.025, 0.53, 0.11, "917052")
box(west - 0.08, 1.61, gz + 0.04, 0.12, 0.061, 0.64, "a37c56")
window(gx + 0.75, 1.95, front + 0.073, 0.39, 0.60, flowers=True)
# A small dormer on the left slope is visible from the capture angle.
box(gx - 0.69, 3.64, 1.02, 0.47, 0.44, 0.66, "bd9f79")
roof(gx - 0.70, 1.02, 0.80, 0.77, 3.83, 0.43)
for x in [gx - 0.84, gx + 0.84]:
    beam((x, 2.27, front + 0.09), (x, canopy_h(2.81) - 0.045, 2.81), 0.055, "895e40", 4)
    beam(
        (x, canopy_h(2.79) - 0.062, 1.98),
        (x, canopy_h(2.79) - 0.062, 2.79),
        0.047,
        "805638",
        4,
    )
box(-1.65, 5.12, -0.63, 0.47, 1.80, 0.48, "806b54")
box(-1.65, 6.00, -0.63, 0.59, 0.17, 0.61, "5e5248")
for x in [-0.04, 0.96]:
    box(x, 3.48, 0.33, 0.49, 0.57, 0.60, "bba27f")
    roof(x, 0.29, 0.76, 0.67, 3.77, 0.36, True)
    # Small shuttered dormers are mostly dark ridged wood from this distance.
    box(x, 3.51, 0.655, 0.365, 0.356, 0.054, "71513a")
    for j in range(5):
        box(
            x + (j - 2) * 0.062,
            3.51,
            0.695,
            0.053,
            0.292,
            0.020,
            ["896547", "8e6748", "815f44", "876145", "946e4d"][j],
        )
    box(x, 3.375, 0.712, 0.366, 0.026, 0.042, "a98463")
    box(x, 3.342, 0.676, 0.42, 0.046, 0.12, "966e4d")

# Low stone sill and a paved fan meet the door and bridge into the older
# cottage path; its individual shallow steps are embedded in the apron.
box(mainx, 0.26, mainz, 4.68, 0.74, 2.20, "746952")
box(gx, 0.26, gz, 2.37, 0.74, 1.90, "776951")
for row in range(2):
    n = 7 - row
    for j in range(n):
        u = (j + 0.5) / n - 0.5
        box(
            gx + u * 2.32,
            0.10 + row * 0.28,
            front + 0.026,
            2.32 / n - 0.020,
            0.245,
            0.072,
            house_detail_rng.choice(["827762", "897c64", "7e715d", "8a7e65"]),
        )
# The cottage sits on a low grassy lip. Bed each stepping stone in that
# lip so its joints open into the connecting garden path without a slab.
earth_rng = random.Random(409)
# Project onto the actual triangles used by the finished turf. Sampling the
# analytic height function here misses the faceted edge after Z compression.
def final_bank_z(z):
    t = np.clip(z / 4.14, 0., 1.)
    return z * (1. - .18*t*t)

turf_tri = np.asarray(parts["TurfAndEarth"][0], dtype=float).reshape(-1,3,3).copy()
turf_tri[:,:,2] = final_bank_z(turf_tri[:,:,2])
edges_a = turf_tri[:,1] - turf_tri[:,0]
edges_b = turf_tri[:,2] - turf_tri[:,0]
denom = edges_a[:,0]*edges_b[:,2] - edges_a[:,2]*edges_b[:,0]
usable = np.abs(denom)>1e-8
contour = np.asarray([(v[0], final_bank_z(v[2])) for v in outline])
bank_start = np.roll(contour, 1, axis=0)
bank_edge = contour-bank_start
bank_edge_lengths = np.sum(bank_edge*bank_edge, axis=1)
from functools import lru_cache

@lru_cache(maxsize=8192)
def turf_at_door(x,z):
    # Drop a world-vertical ray at this local footprint location.
    angle = math.radians(34)
    wx = (x+.58)*math.cos(angle)+(z+.53)*math.sin(angle)-.45
    wz = -(x+.58)*math.sin(angle)+(z+.53)*math.cos(angle)-.53
    dx, dz = wx-turf_tri[:,0,0], wz-turf_tri[:,0,2]
    u = np.divide(dx*edges_b[:,2]-dz*edges_b[:,0], denom,
                  out=np.zeros_like(denom),where=usable)
    v = np.divide(edges_a[:,0]*dz-edges_a[:,2]*dx, denom,
                  out=np.zeros_like(denom),where=usable)
    hits = usable & (u>=-1e-7) & (v>=-1e-7) & (u+v<=1+1e-7)
    if not np.any(hits):return None
    rel = np.array([wx,wz])-bank_start
    along = np.clip(np.sum(rel*bank_edge,axis=1)/bank_edge_lengths,0.,1.)
    inset = np.min(np.linalg.norm(rel-along[:,None]*bank_edge,axis=1))
    if inset < .48:return None
    heights = turf_tri[:,0,1] + u*edges_a[:,1] + v*edges_b[:,1]
    return (float(np.max(heights[hits]))-1.03)/.80

def porch_surface(x,z):
    floor_y=turf_at_door(x,z)
    if floor_y is None:return None
    r2=((x-gx)/.92)**2+((z-1.88)/.61)**2
    weight=max(0.,1.-r2)**1.5
    return floor_y + max(0.,.54-floor_y)*weight

# Only fill beneath the doorstep, with the outer ring below the actual dirt.
# The garden approach past this small nose is entirely real turf.
for i in range(19):
    a0=math.pi*i/19
    a1=math.pi*(i+1)/19
    def mound_point(t,a):
        x=gx+.92*math.cos(a)*t
        z=1.88+.61*math.sin(a)*t
        y=porch_surface(x,z)
        return None if y is None else (x,y-.050*t*t-.012,z)
    for j in range(4):
        p,q,r,s=[mound_point(t,a) for t,a in ((j/4,a0),((j+1)/4,a0),
                                               ((j+1)/4,a1),(j/4,a1))]
        tint=earth_rng.choice(["7f814c","82854c","808650","84864e"])
        for tri in ((p,q,r),(p,r,s)):
            if all(v is not None for v in tri):face(tri,tint,(gx,-3.,2.1))

def doorstep(x,z,w,d,key,phase,proud):
    # Contact and edge clearance are tested for every actual corner, not
    # just for the center of the stone. All outer stones follow local grade.
    ring=[]
    for j in range(8):
        a=math.tau*(j+.5)/8+phase
        dx=math.copysign(abs(math.cos(a))**.64,math.cos(a))*w*.5
        dz=math.copysign(abs(math.sin(a))**.64,math.sin(a))*d*.5
        rx,rz=x+dx,z+dz
        ry=porch_surface(rx,rz)
        if ry is None:return
        ring.append((rx,ry+proud+earth_rng.uniform(-.007,.008),rz))
    face(ring,key,(x,-1,z))
    for j,p in enumerate(ring):
        q=ring[j-1]
        face([q,p,(p[0],p[1]-.060,p[2]),(q[0],q[1]-.060,q[2])],
             color(key)*.76,(x,min(p[1],q[1])-.04,z))

for xoff,z,w,d,key in [
        (-.02,2.020,.88,.25,"8f816c"),(.035,2.185,.74,.20,"897f68"),
        (-.045,2.335,.65,.19,"8d836c"),(.055,2.51,.43,.16,"928a72")]:
    doorstep(gx+xoff,z,w,d,key,earth_rng.uniform(-.16,.16),.020)

# Route the irregular gravel strip toward the shed rather than downhill
# toward the water. Its unraised outer part sits directly on the turf.
for row in range(11):
    for col in range(18):
        u=(col+earth_rng.uniform(.12,.85))/18
        v=(row+earth_rng.uniform(.08,.85))/11
        x=gx-1.43+2.38*u
        z=2.12+.53*v+.14*math.sin(u*math.pi)-.17*(1-u)
        if abs(x-gx)<.48 and z<2.61:continue
        tone=earth_rng.choice(["a19175","a2967b","908571","a19882","8b836c"])
        doorstep(x,z,earth_rng.uniform(.09,.17),earth_rng.uniform(.065,.122),
                 tone,earth_rng.uniform(-.4,.4),.013)
for j in range(44):
    a=earth_rng.uniform(0,math.pi);rad=math.sqrt(earth_rng.random())
    x=gx+.86*rad*math.cos(a);z=1.88+.55*rad*math.sin(a)
    if abs(x-gx)<.46 and z<2.55:continue
    y=porch_surface(x,z)
    if y is None:continue
    for b in [-1,1]:
        face([(x-.020,y-.035,z),(x+.017,y-.035,z+.006),
              (x+b*.035,y+.04+earth_rng.random()*.07,z+.014)],
             earth_rng.choice(["859453","7e8e52","9d9d68"]),(x,y-.2,z-.3))

# A single house transform turns the front gable toward the reference angle.
# At this angle its left roof flank appears beside the entrance.
def house_transform(p):
    a = math.radians(34)
    x, y, z = p
    x += 0.58
    z += 0.53
    return np.array(
        [
            x * math.cos(a) + z * math.sin(a) - 0.45,
            0.80 * y + 1.03,
            -x * math.sin(a) + z * math.cos(a) - 0.53,
        ]
    )


def fit_mesh(name, transform, normal_matrix):
    pos, norm, _ = parts[name]
    for i in range(len(pos)):
        pos[i] = transform(pos[i])
        n = normal_matrix @ norm[i]
        norm[i] = n / np.linalg.norm(n)


a = math.radians(34)
house_normal = np.array(
    [[math.cos(a), 0, math.sin(a)], [0, 1 / 0.80, 0], [-math.sin(a), 0, math.cos(a)]]
)
fit_mesh("CottageWalls", house_transform, house_normal)
group("Fence")
for j in range(16):
    a = -2.93 + j * 2.95 / 15
    x, z = 5.05 * math.cos(a), 3.50 * math.sin(a)
    y = surface(x, z)
    beam((x, y, z), (x, y + 0.49, z), 0.045, "8f693f", 5, 0.036)
    if j > 0:
        for h in [0.18, 0.37]:
            beam((px, py + h, pz), (x, y + h, z), 0.026, "b68b56", 5)
    px, py, pz = x, y, z
group("OakWood")
for a, b, r, r2 in [
    ((1.92, 0.62, -1.08), (2, 3.25, -1.02), 0.30, 0.25),
    ((2, 3.25, -1.02), (2.47, 6.13, -0.83), 0.25, 0.145),
    ((2.05, 3.41, -1), (1.02, 5.73, -1.47), 0.13, 0.067),
    ((2.23, 4.73, -0.95), (3.08, 6.67, -0.48), 0.14, 0.036),
]:
    beam(a, b, r, "8c634d", 8, r2)
group("AutumnOak")
# Branch reach is calibrated from the photographed canopy. The merged lobes
# guide the leaf tips in three dimensions.
center = np.array([1.38, 7.56, -1.12])
# Overlapping boughs have different depth as well as different heights.
# The forward cheek breaks the lighting between the upper dome and the
# low right bough. The shorter lower-left quadrant leaves air by the trunk.
lobes = [
    ([-1.45, 0.08, 0.27], [1.51, 1.49, 1.39]),
    ([-0.99, 0.95, -0.04], [1.12, 0.99, 1.20]),
    ([0.28, 0.52, -0.26], [1.84, 1.83, 1.64]),
    ([1.80, -0.52, -0.02], [1.24, 1.30, 1.37]),
    ([-0.03, 0.13, 0.98], [1.22, 1.49, 1.17]),
    ([-0.06, -0.91, 0.23], [1.38, 1.41, 1.37]),
]
lobes = [(np.array(c), np.array(r) ** 2) for c, r in lobes]


def envelope(direction):
    outer = 0.10
    for c, radii2 in lobes:
        a = np.sum(direction**2 / radii2)
        b = np.sum(direction * c / radii2)
        d = b * b - a * (np.sum(c * c / radii2) - 1.0)
        if d <= 0:
            continue
        dist = (b + math.sqrt(d)) / a
        # Smooth max removes creases where neighboring boughs meet.
        blend = max(0.25 - abs(outer - dist), 0.0) / 0.25
        outer = max(outer, dist) + blend * blend * 0.0625
    x, y, z = direction
    wave = (
        0.065 * math.sin(7 * x + 5 * y - 4 * z) * math.cos(5 * y + 3 * z)
        + 0.036 * math.sin(14 * x + 13 * y) * math.cos(8 * y - 15 * z)
        + 0.018 * math.sin(27 * x - 21 * z + 10 * y)
    )
    return center + direction * (outer + wave)


def canopy_paint(position):
    x, y, z = position - center
    lit = np.clip(0.49 + 0.16 * x + 0.14 * y - 0.035 * z, 0.0, 1.0)
    color_variation = (
        0.93
        + 0.06 * math.sin(4.8 * x + 3.7 * y - 4 * z)
        + 0.035 * math.cos(13 * x - 6 * y)
    )
    return np.clip(
        (color("896659") * (1 - lit) + color("e2c8a1") * lit) * color_variation, 0, 1
    )


def envelope_normal(direction):
    tangent = np.cross(direction, [0, 1, 0] if abs(direction[1]) < 0.96 else [1, 0, 0])
    tangent /= np.linalg.norm(tangent)
    bitangent = np.cross(direction, tangent)

    def near(v):
        return envelope(v / np.linalg.norm(v))

    norm = np.cross(
        near(direction + 0.012 * tangent) - near(direction - 0.012 * tangent),
        near(direction + 0.012 * bitangent) - near(direction - 0.012 * bitangent),
    )
    norm /= np.linalg.norm(norm)
    if np.dot(norm, direction) < 0:
        norm = -norm
    return norm


def leaf_triangle(a, b, c):
    if np.dot(np.cross(b[0] - a[0], c[0] - a[0]), a[1]) < 0:
        b, c = c, b
    for v in [a, b, c]:
        part[0].append(v[0])
        part[1].append(v[1])
        part[2].append(v[2])


# The envelope above supplies bough reach, not a rendered shell. The interior
# cores sit behind the sprigs so the silhouette and the small openings are leaves.
oak_rng = random.Random(4583)
saved_detail_state = rng.getstate()
rng.seed(4583)
for i, (offset, radii2) in enumerate(lobes):
    p = center + offset * 0.90
    radii = np.sqrt(radii2) * (0.68 if offset[0] > 0.6 else 0.55)
    c = canopy_paint(p) * (0.83 if offset[0] < 0 else 0.94)
    blob(*p, *radii, c, 11, 7, 0.12)
rng.setstate(saved_detail_state)


def unit(v):
    return v / max(np.linalg.norm(v), 1e-7)


def linear_pigment(rgb):
    rgb = np.clip(rgb, 0, 1)
    return np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)



def smooth01(value):
    t = min(1.0, max(0.0, value))
    return t*t*(3.0-2.0*t)


def closed_bough_weight(p):
    x, y, z = p - center
    # The right bough is densely layered. Its lower-left/trunk-facing edge
    # stays open, with the independent outward shoots visible from below.
    return smooth01((0.97*x - 0.24*z + 0.68*y + 0.92) / 1.52)


def warm_wash(p):
    x, y, z = p - center
    sun = min(1.0,max(0.0,0.49 + 0.16*x + 0.14*y - 0.035*z))
    return (color("896659")*(1-sun) + color("e2c8a1")*sun) * (0.96 + 0.013*math.sin(4*x+2*y))


# The dense sun-facing bough has a continuous bed of overlapping leaves
# recessed below its finest tips. Only the lit portion gets this surface.
cap_grid = []
lon_count, lat_count = 64, 32
for j in range(lat_count + 1):
    lat = math.pi * j / lat_count
    ring = []
    for i in range(lon_count):
        lon = math.tau * i / lon_count
        direction = np.array([math.sin(lat)*math.cos(lon), math.cos(lat), math.sin(lat)*math.sin(lon)])
        p = envelope(direction)
        cover = closed_bough_weight(p)
        # Individual sprays break through the lit bed at varying depths.
        pocket = 0.045 * math.sin(3.4*p[0]+1.7*p[1]) * math.cos(3.8*p[2]-p[1])
        p -= direction*(0.20 + pocket + 0.32*(1-cover))
        normal = envelope_normal(direction)
        pigment = warm_wash(p)
        ring.append(((p,normal,linear_pigment(pigment)),cover))
    cap_grid.append(ring)
for j in range(lat_count):
    for i in range(lon_count):
        a,b=cap_grid[j][i-1],cap_grid[j][i]
        c,e=cap_grid[j+1][i],cap_grid[j+1][i-1]
        for tri in ((a,b,c),(a,c,e)):
            if min(v[1] for v in tri) < 0.16:
                continue
            if np.linalg.norm(np.cross(tri[1][0][0]-tri[0][0][0],tri[2][0][0]-tri[0][0][0])) > 1e-7:
                leaf_triangle(*(v[0] for v in tri))


def leaf_fan(p, axis, side, normal, length, width, tint):
    # The bent keel and four contour turns give each leaf a distinct underside,
    # a short foot and a tapered, lightly hooked end. All coordinates are 3D.
    cover = closed_bough_weight(p)
    # The broad interior leaves tuck under the wash. Fine tips skim the
    # surface in a few places and gently interrupt the smooth outer rim.
    tuck = 0.135 if length > 0.25 else 0.065
    p = p - unit(p-center)*cover*tuck
    size_factor = 1.0 - 0.23*cover
    length *= size_factor
    width *= size_factor
    tint = tint*(1.0-0.69*cover) + warm_wash(p)*0.69*cover
    keel = p + axis * length * 0.11 + normal * width * 0.13
    loop = [
        p - axis * length * 0.43,
        p - axis * length * 0.20 + side * width * 0.44,
        p + axis * length * 0.18 + side * width * 0.48,
        p + axis * length * 0.63 + side * width * 0.08,
        p + axis * length * 0.14 - side * width * 0.50,
        p - axis * length * 0.20 - side * width * 0.34,
    ]
    crease = unit(normal + side * 0.16)
    color_a = linear_pigment(tint)
    color_b = linear_pigment(tint * 0.96)
    for j in range(len(loop)):
        n, ink = (normal, color_a) if j < 3 else (crease, color_b)
        leaf_triangle((keel, n, ink), (loop[j-1], n, ink), (loop[j], n, ink))


shoots = []
shoot_count = 248
for k in range(shoot_count):
    polar = 1.0 - 2.0 * (k + 0.5) / shoot_count
    phi = k * 2.399963 + oak_rng.uniform(-0.095, 0.095)
    disk = math.sqrt(max(0.0, 1.0 - polar**2))
    ray = np.array([disk * math.cos(phi), polar, disk * math.sin(phi)])
    shoulder = envelope(ray)
    n = unit(0.70 * envelope_normal(ray) + 0.30 * ray)
    u = unit(np.cross(n, [0, 1, 0] if abs(n[1]) < 0.92 else [1, 0, 0]))
    v = np.cross(n, u)
    bright = float(np.clip((shoulder[0] + 0.1) / 3.5, 0, 1))
    # Shoots on the shaded side have uneven endpoints, with air between tips.
    inset = oak_rng.uniform(-0.035, 0.18) + (1.0-bright) * oak_rng.uniform(-0.08, 0.32)
    p = shoulder - ray * inset
    sprig_angle = oak_rng.uniform(0.0, math.tau)
    leader = unit(v * math.cos(sprig_angle) + u * math.sin(sprig_angle) + n*0.26)
    side = unit(np.cross(n, leader))
    crown_tone = oak_rng.choice(["b3795b","a88372","d5ac82","dfb991","d5b296"])
    tint = canopy_paint(p) * 0.88 + color(crown_tone)*0.12
    lower = np.clip((7.35 - p[1]) / 1.65, 0.0, 1.0)
    tint *= np.array([1 + 0.055*lower, 1 - 0.06*lower, 1 - 0.09*lower])
    tint *= oak_rng.uniform(0.87,1.075) * (1-bright) + oak_rng.uniform(0.96,1.035) * bright
    shoots.append((ray, p, n, leader, side, tint, bright))
    # Overlapping broad leaf fans give the lit hemisphere its connected wash;
    # the lower and left groups have shorter, sparser fans and visible gaps.
    for whorl in range(3):
        depth = (0.53 - 0.20*whorl) + oak_rng.uniform(-0.035, 0.035)
        base = p - n*depth + u*oak_rng.uniform(-0.19,0.19) + v*oak_rng.uniform(-0.16,0.16)
        span = (0.32 + 0.115*bright)*oak_rng.uniform(0.86,1.17)
        # Two opposing fans on a short bent branch. The last tips break free.
        for leaf in range(8):
            sign = -1 if leaf % 2 == 0 else 1
            t = (leaf//2) / 3
            stem = base + leader*(t-0.56)*span*0.95
            reach = unit(leader*(0.23+0.71*t)+side*sign*(0.92-0.61*t)+n*oak_rng.uniform(-0.19,0.25))
            across = unit(np.cross(n,reach))
            leaf_n = unit(n + side * sign * oak_rng.uniform(0.13,0.37) + v*oak_rng.uniform(-0.12,0.12))
            leaf_length = span*(1.48-.35*t)*oak_rng.uniform(.84,1.12)
            center_leaf = stem + reach*leaf_length*.38
            leaf_fan(center_leaf,reach,across,leaf_n,leaf_length,leaf_length*0.65,
                     tint*(0.83+.12*whorl+.065*t))

# Small terminal branches meet the recessed crown, visible through the outside
# leaves on the shaded side. They share the island wood material and shadows.
group("OakWood")
for k, (ray, p, n, leader, side, tint, bright) in enumerate(shoots):
    if k % 3 or (ray[0] > -0.24 and ray[1] > -0.50):
        continue
    start = p - ray*0.90
    joint = p - ray*0.36 - leader*.09
    beam(start, joint, 0.029, "785343", 5, 0.015)
    beam(joint, p+leader*.13, 0.015, "976c51", 4, 0.005)
    beam(joint, p+side*.17-leader*.12, 0.012, "916444", 4, 0.004)
group("AutumnOak")
rays = np.array([sprig[0] for sprig in shoots])
# Reuse the established shared RNG draws so the meadow, sheep, paths and
# lily pads after this block retain their original deterministic placement.
for k in range(1290):
    az = rng.uniform(0.0, math.tau)
    y = rng.uniform(-1.0,1.0)
    radius = math.sqrt(1.0-y*y)
    direction = np.array([radius*math.cos(az),y,radius*math.sin(az)])
    nearest = int(np.argmax(rays @ direction))
    ray, p, normal, leader, side, tint, bright = shoots[nearest]
    # The selected bough keeps the small leaves in groups, not uniform fuzz.
    anchor = 0.58*p + 0.42*envelope(direction)
    for j in range(rng.randint(3,6)):
        outward = rng.uniform(0.0,0.14)
        along = rng.uniform(-0.22,0.25)
        across = rng.uniform(-0.26,0.26)
        tilt = rng.uniform(-1.08,1.08)
        length = rng.uniform(0.112,0.242) * (1.08-.16*bright)
        width = length*rng.uniform(.43,.66)
        gain = rng.uniform(.84,1.13)
        position = anchor+normal*outward + leader*along + side*across
        direction_leaf = unit(leader*math.cos(tilt)+side*math.sin(tilt)+normal*.11)
        sheet = unit(np.cross(normal,direction_leaf))
        leaf_normal = unit(normal + sheet*(across+tilt*.17))
        leaf_fan(position,direction_leaf,sheet,leaf_normal,length,width,tint*(gain*(1-bright*.56)+bright*.56))

# The source-frame treetop is lower than the broad leaf tips in the first
# open-crown pass. Taper the adjustment in over the top 1.4 metres.
crown_points = parts["AutumnOak"][0]
# Original open tips peak at Y=10.115; allow for the tuck already applied.
remaining_trim = max(0.0,max(p[1] for p in crown_points)-9.865)
for i,p in enumerate(crown_points):
    lowered = p.copy()
    lowered[1] -= remaining_trim * smooth01((p[1]-8.23)/1.43)
    crown_points[i] = lowered


group("Meadow")
for i in range(1550):
    x = rng.uniform(-6, 6)
    z = rng.uniform(-4.15, 4.15)
    if (x / 5.9) ** 2 + (z / 4.1) ** 2 > 1 or (-3 < x < 1.8 and -1.6 < z < 2.0):
        continue
    y = surface(x, z)
    col = rng.choice(["93a35b", "8b9c57", "a9ab68", "94954e", "788c4b"])
    for j in range(2):
        r = rng.uniform(0.025, 0.055)
        h = rng.uniform(0.055, 0.15)
        face(
            [
                (x - r, y, z),
                (x + r, y, z + 0.012),
                (x + rng.uniform(-0.08, 0.08), y + h, z + rng.uniform(-0.10, 0.10)),
            ],
            col,
            [x, y - 1, z],
        )
    if rng.random() < 0.19:
        col = rng.choice(["f0e2b9", "d5bc9f", "cfb6db", "e4d999", "ad9bc3"])
        blob(x, y + 0.13, z, 0.037, 0.030, 0.032, col, 5, 2)
group("FoxglovesAndWildflowers")
for cx, cz in [
    (-3.45, 1.95),
    (-3.95, 1.1),
    (-2.9, 2.46),
    (0.35, 1.57),
    (1.48, 1.39),
    (2.15, 0.85),
]:
    for i in range(15):
        x = cx + rng.uniform(-0.4, 0.4)
        z = cz + rng.uniform(-0.37, 0.37)
        y = surface(x, z)
        ht = rng.uniform(0.19, 0.46)
        beam((x, y, z), (x + 0.025, y + ht, z), 0.011, "798351", 3)
        hue = rng.choice(["ab8bb4", "d5b7cd", "c2a3c6", "dfc0d7", "d8c78e"])
        for n in range(4):
            sx = 0.035 if n % 2 == 0 else -0.035
            blob(
                x + sx,
                y + ht * (0.64 + 0.11 * n),
                z + 0.015,
                0.042,
                0.050,
                0.041,
                hue,
                5,
                2,
                0.12,
            )
group("Sheep")
for index, (x, z, scale) in enumerate([(1.23, 2.49, 1.02), (2.83, 1.98, 1.14)]):
    sheep_start = len(part[0])
    y = surface(x, z)
    for a in [-0.21, 0.18]:
        for b in [-0.11, 0.09]:
            beam(
                (x + a * scale, y, z + b * scale),
                (x + a * scale, y + 0.255 * scale, z + b * scale),
                0.040 * scale,
                "5f594d",
                5,
            )
    blob(
        x,
        y + 0.35 * scale,
        z,
        0.38 * scale,
        0.21 * scale,
        0.19 * scale,
        "dbd4bf",
        10,
        5,
        0.05,
    )
    for j in range(17):
        u = rng.random() * math.tau
        v = rng.uniform(-0.65, 0.8)
        blob(
            x + 0.30 * scale * math.cos(u),
            y + (0.38 + 0.17 * v) * scale,
            z + 0.14 * scale * math.sin(u),
            0.10 * scale,
            0.095 * scale,
            0.095 * scale,
            "dfd7c3",
            6,
            3,
            0.06,
        )
    blob(
        x + 0.366 * scale,
        y + 0.33 * scale,
        z,
        0.15 * scale,
        0.13 * scale,
        0.12 * scale,
        "8e8373",
        7,
        4,
    )
    for q in [-1, 1]:
        blob(
            x + 0.31 * scale,
            y + 0.40 * scale,
            z + 0.10 * scale * q,
            0.10,
            0.042,
            0.052,
            "a79983",
            6,
            3,
        )
    # The first sheep presents its rump toward camera, the second grazes
    # in three-quarter profile. Both heads tilt down under their fleece.
    for side in [-1, 1]:
        box(
            x + 0.430 * scale,
            y + 0.357 * scale,
            z + side * 0.095 * scale,
            0.027,
            0.023,
            0.018,
            "594d40",
        )
    yaw = math.radians(77 if index == 0 else 157)
    cosine, sine = math.cos(yaw), math.sin(yaw)
    for k in range(sheep_start, len(part[0])):
        vx, vy, vz = part[0][k] - np.array([x, y, z])
        nx, ny, nz = part[1][k]
        part[0][k] = np.array(
            [x + vx * cosine + vz * sine, y + vy, z - vx * sine + vz * cosine]
        )
        part[1][k] = np.array([nx * cosine + nz * sine, ny, -nx * sine + nz * cosine])
group("PorchAndGarden")
# The small animal shelter has a dark interior, slatted front, pitched
# wood roof and raised deck. Keep its roof lower than the cottage sill.
shed_x, shed_z = -3.60, 1.20
deck_y = surface(shed_x, shed_z) + 0.12
deck_w, deck_d = 1.36, 1.27
for j in range(7):
    box(
        shed_x,
        deck_y,
        shed_z + (j - 3) * 0.183,
        deck_w,
        0.12,
        0.176,
        ["956c48", "9b704a", "a57650"][j % 3],
    )
box(shed_x,deck_y+.39,shed_z-.49,1.22,.75,.092,"3f352c")
box(shed_x,deck_y+.083,shed_z-.12,1.08,.035,.74,"574533")
for j in range(5):
    x=shed_x-.40+j*.19
    beam((x,deck_y+.17,shed_z-.34),(x,deck_y+.17,shed_z-.03),.079,
         ["725137","77573d","684c38"][j%3],7)
for side in [-1, 1]:
    box(shed_x+side*.594,deck_y+.19,shed_z,.065,.28,.99,"66503a")
    beam((shed_x+side*.594,deck_y+.20,shed_z-.45),
         (shed_x+side*.594,deck_y+.72,shed_z+.45),.033,"89694b",4)
    for end in [-1, 1]:
        box(
            shed_x + side * 0.59,
            deck_y + 0.42,
            shed_z + end * 0.50,
            0.083,
            0.84,
            0.086,
            "976c44",
        )
front_z = shed_z + 0.52
for j in range(5):
    box(shed_x-.475+j*.14,deck_y+.36,front_z,.046,.57,.051,
        ["af895e","a48055","b48d5e"][j%3])
for yoff in [.10,.64]:
    box(shed_x-.20,deck_y+yoff,front_z+.020,.81,.048,.059,"a47f56")
# The open bay at the right connects the dark storage space to the steps.
box(shed_x+.54,deck_y+.48,front_z,.076,.85,.077,"ab835a")
for side in [-1, 1]:
    for j in range(8):
        x1 = shed_x - 0.73 + j * 0.183
        x2 = x1 + 0.178
        face(
            [
                (x1, deck_y + 1.02, shed_z - 0.06),
                (x2, deck_y + 1.02, shed_z - 0.06),
                (x2, deck_y + 0.795, shed_z + side * 0.68),
                (x1, deck_y + 0.795, shed_z + side * 0.68),
            ],
            house_detail_rng.choice(["57483a","624e3d","5b493c","6a5140"]),
            (shed_x, deck_y, shed_z),
        )
    beam(
        (shed_x - 0.75, deck_y + 0.792, shed_z + side * 0.68),
        (shed_x + 0.75, deck_y + 0.792, shed_z + side * 0.68),
        0.033,
        "755b42",
        5,
    )
for j in range(3):
    box(
        shed_x + 0.46,
        deck_y - 0.025 - j * 0.053,
        front_z + 0.17 + j * 0.15,
        0.59,
        0.072,
        0.155,
        ["a87a51", "a77a50", "a0714c"][j],
    )
for i in range(8):
    x, z = rng.uniform(3.63, 4.55), rng.uniform(-0.65, 0.60)
    r = rng.uniform(0.13, 0.25)
    y = surface(x, z)
    blob(
        x,
        y + r * 0.64,
        z,
        r,
        r * 0.75,
        r,
        rng.choice(["c47e47", "d29d62", "b96d3a"]),
        8,
        4,
    )
    beam((x, y + r * 1.3, z), (x + 0.05, y + r * 1.6, z), 0.025, "77674c", 5)
# Use the actual irregular bank rather than a second ellipse for the rushes,
# exposed rootlets and floating pads. The outer lip has short turfed shelves
# alternating with low eroded bays.
shore_rng = random.Random(94852)


def water_margin(angle):
    vertex = (angle % math.tau) * len(outline) / math.tau
    index = int(vertex)
    blend = vertex - index
    a = outline[index]
    b = outline[(index + 1) % len(outline)]
    return a[0] * (1-blend) + b[0] * blend, a[2] * (1-blend) + b[2] * blend


def grass_blade(x, y, z, heading, width, height, bend, col):
    side_x, side_z = math.cos(heading) * width, math.sin(heading) * width
    lead_x, lead_z = -math.sin(heading) * bend, math.cos(heading) * bend
    face([(x-side_x, y, z-side_z), (x+side_x, y, z+side_z),
          (x+lead_x, y+height, z+lead_z)], col, (0, -2, 0))


group("BankFoliage")
for patch in range(250):
    az = shore_rng.uniform(0, math.tau)
    foot_x, foot_z = water_margin(az)
    retreat = shore_rng.uniform(0.004, 0.05)
    # Some fissures carry a trailing tuft, while most of the bank is exposed.
    trails = math.sin(az*13.0+0.6) + 0.55*math.cos(az*23.0) > 0.87
    for blade in range(shore_rng.randint(4, 9)):
        angle = az + shore_rng.gauss(0, 0.017)
        rim_x, rim_z = water_margin(angle)
        r = 1-retreat + shore_rng.uniform(-0.015, 0.012)
        x, z = rim_x*r, rim_z*r
        y = surface(x,z)
        heading = shore_rng.uniform(0, math.tau)
        col = shore_rng.choice(["667642","788345","899449","5c733f","939750"])
        grass_blade(x,y-0.020,z,heading,shore_rng.uniform(0.012,0.033),
                    shore_rng.uniform(0.058,0.25),shore_rng.uniform(0.035,0.12),col)
        if trails and blade < 4:
            length = shore_rng.uniform(0.06, 0.25) * (1.24 if foot_x < -3 else 1)
            dx, dz = math.cos(angle), math.sin(angle)
            face([(rim_x-0.027*dz, surface(rim_x,rim_z)+0.015, rim_z+0.027*dx),
                  (rim_x+0.028*dz, surface(rim_x,rim_z)+0.010, rim_z-0.028*dx),
                  (rim_x+0.085*dx, surface(rim_x,rim_z)-length, rim_z+0.085*dz)],
                 col,(0,0,0))

# Dappled undergrowth thickens the western inlet. The low canopy of bent
# stems changes its outer silhouette and leaves the timber shed visible.
for clump in range(370):
    angle = shore_rng.uniform(2.30, 3.82)
    x,z = water_margin(angle)
    r = shore_rng.uniform(0.85, 1.006)
    x,z = x*r,z*r
    y = surface(x,z)
    mass = 0.15 + 0.19 * (math.sin(3.5*angle + 0.7) ** 2)
    for stem in range(5):
        head = shore_rng.uniform(0,math.tau)
        grass_blade(x,y-0.034,z,head,shore_rng.uniform(0.021,0.050),
                    mass*shore_rng.uniform(0.5,1.35),shore_rng.uniform(-0.14,0.14),
                    shore_rng.choice(["516a35","586c38","4d6438","72804a"]))

# Gravel, root scars and reed fans follow the height of the real face.
# Anchoring them at the sloped toe leaves patches of warm earth exposed.
front_rng = random.Random(74205)
for patch in range(146):
    az = front_rng.uniform(.14,3.44)
    x,z = water_margin(az)
    dx,dz = math.cos(az), math.sin(az)
    rim = surface(x,z)
    h = .040 + max(.06,rim-.10)*front_rng.uniform(0,.84)
    half = front_rng.uniform(.039,.135)
    height = front_rng.uniform(.024,.065)
    # Tiny schist chips point in different directions on the exposed soil.
    r = 1.018 if h < rim*.48 else 1.007
    cx,cz=x*r,z*r
    p0=(cx-half*dz,h-.15*height,cz+half*dx)
    p1=(cx+.66*half*dz,h-.49*height,cz-.66*half*dx)
    p2=(cx+.39*half*dz,h+height,cz-.39*half*dx)
    p3=(cx+dx*.043,h+.24*height,cz+dz*.043)
    face([p0,p3,p2],front_rng.choice(["928161","aaa38b","8b805e","a48e67"]),(0,0,0))
    face([p3,p1,p2],"716956",(0,0,0))

for patch in range(92):
    az = front_rng.uniform(.16,3.59)
    x,z = water_margin(az)
    dx,dz=math.cos(az),math.sin(az)
    # Reeds rise out of the water; roots and trailing sedges descend from the sod.
    long = .30 + .18*(.5+.5*math.sin(9*az))
    count = front_rng.randint(5,12)
    for stem in range(count):
        along=front_rng.gauss(0,.095)
        cx,cz=x + dx*front_rng.uniform(.03,.14)-along*dz,z + dz*front_rng.uniform(.03,.14)+along*dx
        tint=front_rng.choice(["768448","778247","8b8b4d","626d39","99944d"])
        if patch % 3:
            grass_blade(cx,.025,cz,az + front_rng.uniform(-1.7,1.7),
                        front_rng.uniform(.010,.026),front_rng.uniform(.08,.31),
                        front_rng.uniform(.06,.20),tint)
        else:
            rim=surface(x,z)
            grass_blade(cx,rim+.025,cz,az + front_rng.uniform(-1.1,1.1),
                        front_rng.uniform(.012,.028),-long*front_rng.uniform(.28,1.08),
                        front_rng.uniform(.015,.12),tint)
    if patch % 4 == 0:
        # A tapered, forked root against the bank adds an irregular contact edge.
        top=(x+dx*.053,surface(x,z)-.03,z+dz*.053)
        mid=(x+dx*.067,surface(x,z)*.51,z+dz*.067)
        tip=(x+dx*.116,surface(x,z)*.12,z+dz*.116)
        beam(top,mid,.017,"786445",4,.010)
        beam(mid,tip,.010,"695b42",4,.004)

group("Meadow")
# Short leafy tips and seeds add intermediate-scale flecks on the terrace.
for clump in range(620):
    x = shore_rng.uniform(-5.7, 5.3)
    z = shore_rng.uniform(-1.2,4.14)
    if math.hypot(x/5.9,z/4.14) > .96 or (-2.7 < x < 1.9 and z < 1.8):
        continue
    t = (x + 3.20) / 3.55
    path_z = 2.07 + .89*t + .25*math.sin(t*math.pi)
    if 0 < t < 1 and abs(z-path_z) < .28:
        continue
    y = surface(x,z)
    for leaf in range(3):
        head = shore_rng.uniform(0,math.tau)
        col = shore_rng.choice(["889245","7e8d49","a4a059","c0b37c","748a45"])
        grass_blade(x,y+.005,z,head,shore_rng.uniform(.010,.031),
                    shore_rng.uniform(.025,.089),shore_rng.uniform(.03,.1),col)


group("LilyPads")
# Loose flotillas near the foreground inlet; short schools also gather off
# the left wall and the far-right stone. Water is visible between each raft.
pad_patches = [
    (-1.38,5.28,1.04,.90,18,.19), (.05,6.30,1.04,1.10,17,.22),
    (1.18,5.52,.89,.88,15,.20), (2.54,4.84,.88,.76,14,.19),
    (-5.9,3.92,.91,.68,12,.15), (-7.44,1.85,.60,.77,9,.14),
    (-6.5,.40,.48,.71,6,.12), (6.76,-2.50,.58,1.12,8,.13),
    (6.36,-6.0,.66,1.37,5,.11), (7.65,-3.70,.50,1.19,4,.13),
]
pad_centers = []
for cx,cz,rx,rz,count,mean_radius in pad_patches:
    for i in range(count*5):
        az = shore_rng.uniform(0,math.tau)
        spread = math.sqrt(shore_rng.random())
        x,z = cx+rx*spread*math.cos(az),cz+rz*spread*math.sin(az)
        bank = water_margin(math.atan2(z/4.14,x/5.95))
        if math.hypot(x/5.95,z/4.14) < math.hypot(bank[0]/5.95,bank[1]/4.14)+.040:
            continue
        size = mean_radius*shore_rng.uniform(.64,1.27)
        if any((x-px)**2+(z-pz)**2 < (.88*(size+pr))**2 for px,pz,pr in pad_centers):
            continue
        pad_centers.append((x,z,size))
        spin = shore_rng.uniform(0,math.tau)
        tone = color(shore_rng.choice(["9fa55d","a8ac6a","99a755","a8a45c","8b9e53"]))
        blades=[]
        for j in range(10):
            heading=spin+.20+j*.645
            radius=size*(1+.038*math.sin(heading*4))
            blades.append((x+math.cos(heading)*radius,
                           .048+.009*math.sin(heading-spin),z+math.sin(heading)*radius*.90))
        for j in range(9):
            tint = np.minimum(1,tone*(1.06 if j in (1,2) else .91 if j==6 else 1.0))
            face([(x,.055,z),blades[j],blades[j+1]],tint,(x,-1,z))
        count -= 1
        if count <= 0:
            break

# The original painting has a cool pocket beneath the store and the left
# shoreline. Blend pigment per vertex to carry that shadow from turf into
# the stems and exposed soil, keeping individual lit flecks in the grass.
for surface_name in ["TurfAndEarth","BankFoliage","Meadow"]:
    pos, _, pigment = parts[surface_name]
    for i, (x,y,z) in enumerate(pos):
        shade = min(1,max(0,(-x-2.18)/3.41))
        shade = shade*shade*(3-2*shade)
        near = max(0,min(1,(z-2.0)/2.14))
        varied = 1 + .053*math.sin(x*2.7+z*4.0) + .036*math.cos(x*5.4-z*.85)
        factor = np.array([1-.91*shade,1-.86*shade,1-.91*shade])
        pigment[i] = np.clip(pigment[i] * factor * (1-.27*near) * varied,0,1)

# A tapered smoke ribbon with an emissive, translucent override in Godot.
# The translucent smoke shader feathers the sides and the tip.
group("ChimneySmoke")
for i in range(30):
    t = i / 30
    t2 = (i + 1) / 30

    def smoke(q, side):
        return (
            -1.65 + 0.15 * math.sin(q * 8) + q * q * 0.12 + side * (0.068 + 0.115 * q),
            6.08 + q * 4.65,
            -0.63 + 0.08 * math.sin(q * 4),
        )

    face([smoke(t, -1), smoke(t, 1), smoke(t2, 1), smoke(t2, -1)], "eed8cb")


fit_mesh("ChimneySmoke", house_transform, house_normal)
# Shorter near bank and a bevel below the turf give the shoreline a low,
# broken edge. The rocks, groundcover and pads follow the same footprint.
for name in [
    "TurfAndEarth",
    "SlateAndCobbles",
    "Fence",
    "Meadow",
    "FoxglovesAndWildflowers",
    "BankFoliage",
    "Sheep",
    "PorchAndGarden",
    "LilyPads",
]:
    pos = parts[name][0]
    for i, (x, y, z) in enumerate(pos):
        t = max(0.0, min(1.0, z / 4.14))
        pos[i] = np.array([x, y, z * (1 - 0.18 * t * t)])


def export():
    data = bytearray()
    views = []
    access = []
    nodes = []
    meshes = []
    for name, (positions, normals, colors) in parts.items():
        attrs = {}
        for kind, items in [
            ("POSITION", positions),
            ("NORMAL", normals),
            ("COLOR_0", colors),
        ]:
            arr = np.asarray(items, dtype="<f4")
            ofs = len(data)
            data.extend(arr.tobytes())
            views.append(
                {
                    "buffer": 0,
                    "byteOffset": ofs,
                    "byteLength": arr.nbytes,
                    "target": 34962,
                }
            )
            item = {
                "bufferView": len(views) - 1,
                "componentType": 5126,
                "count": len(arr),
                "type": "VEC3",
            }
            if kind == "POSITION":
                item.update(min=arr.min(axis=0).tolist(), max=arr.max(axis=0).tolist())
            attrs[kind] = len(access)
            access.append(item)
        meshes.append(
            {"name": name, "primitives": [{"attributes": attrs, "material": 0}]}
        )
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    meta = {
        "asset": {"version": "2.0", "generator": "island/source/build_island.py"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": [
            {
                "name": "IslandPaint",
                "doubleSided": True,
                "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1},
            }
        ],
        "buffers": [{"byteLength": len(data)}],
        "bufferViews": views,
        "accessors": access,
    }
    js = json.dumps(meta, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    data += b"\0" * ((-len(data)) % 4)
    dst = out / "island_model.glb"
    dst.write_bytes(
        struct.pack("<4sII", "glTF".encode(), 2, 28 + len(js) + len(data))
        + struct.pack("<I4s", len(js), b"JSON")
        + js
        + struct.pack("<I4s", len(data), b"BIN\0")
        + data
    )
    print(
        "triangles",
        sum(len(v[0]) // 3 for v in parts.values()),
        "bytes",
        dst.stat().st_size,
    )


export()
