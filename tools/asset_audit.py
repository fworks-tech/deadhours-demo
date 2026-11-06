#!/usr/bin/env python3
"""Quality audit for the top-down art. Measures what a player would notice:
clipped frames, empty cells, sliding feet, jittery walk cycles, thin
silhouettes, and visible texture seams.

    python3 tools/asset_audit.py           # report + exit code (1 = failures)

Writes docs/ASSET_AUDIT.md.
"""
import json, os, sys
from PIL import Image

CHARS = ["elena", "shambler", "runner", "bloated"]
OBJ_DIR = "assets/images/sprites/objects"
TEX_DIR = "assets/images/textures"
SHEET_DIR = "assets/images/sprites/topdown"
CELL = 128          # fallback, real value comes from the sheet metadata
ROWS = COLS = 8

results = []   # (area, name, metric, value, limit, ok)


def add(area, name, metric, value, limit, ok):
    results.append((area, name, metric, value, limit, bool(ok)))


def alpha_bbox(cell):
    a = cell.getchannel("A")
    return a.point(lambda v: 255 if v > 40 else 0).getbbox()


def audit_sheet(name):
    path = f"{SHEET_DIR}/{name}_sheet.png"
    if not os.path.exists(path):
        add("characters", name, "file present", 0, 1, False)
        return
    im = Image.open(path).convert("RGBA")
    meta = {}
    meta_path = f"{SHEET_DIR}/{name}_sheet.json"
    if os.path.exists(meta_path):
        meta = json.load(open(meta_path))
    cell = int(meta.get("frame_w", CELL))
    rows = int(meta.get("directions", ROWS))
    cols = int(meta.get("frames", COLS))
    add("characters", name, "sheet size", f"{im.width}x{im.height}",
        f"{cell * cols}x{cell * rows}", (im.width, im.height) == (cell * cols, cell * rows))

    empty, clipped, cover = 0, 0, []
    anchors = {}
    for d in range(rows):
        cxs, cys = [], []
        for f in range(COLS):
            crop = im.crop((f * cell, d * cell, (f + 1) * cell, (d + 1) * cell))
            a = crop.getchannel("A")
            px = list(a.getdata())
            opaque = [i for i, v in enumerate(px) if v > 40]
            if len(opaque) < 200:
                empty += 1
                continue
            cover.append(len(opaque) / float(cell * cell))
            bbox = alpha_bbox(crop)
            if bbox and (bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= cell or bbox[3] >= cell):
                clipped += 1
            xs = [i % cell for i in opaque]
            ys = [i // cell for i in opaque]
            cxs.append(sum(xs) / len(xs))
            cys.append(sum(ys) / len(ys))
        if cxs:
            anchors[d] = (sum(cxs) / len(cxs), sum(cys) / len(cys))

    add("characters", name, "empty frames", empty, "0", empty == 0)
    add("characters", name, "clipped frames", clipped, "0", clipped == 0)
    mean_cover = sum(cover) / len(cover) if cover else 0
    add("characters", name, "silhouette fill", f"{mean_cover:.1%}", "5-40%", 0.05 <= mean_cover <= 0.40)
    if anchors:
        half = cell * 0.5
        drift = max(((x - half) ** 2 + (y - half) ** 2) ** 0.5 for x, y in anchors.values())
        add("characters", name, "centroid offset (info)", f"{drift:.1f}px", "n/a", True)
        # ground contact is what a player reads as sliding: measure the feet band
        band = int(cell * 0.62)
        feet_x, feet_y = [], []
        for d in range(rows):
            sx = sy = n = 0
            for f in range(cols):
                crop = im.crop((f * cell, d * cell, (f + 1) * cell, (d + 1) * cell))
                pxz = crop.load()
                for y in range(band, cell):
                    for x in range(cell):
                        if pxz[x, y][3] > 40:
                            sx += x
                            sy += y
                            n += 1
            if n:
                feet_x.append(sx / n)
                feet_y.append(sy / n)
        if feet_x:
            spread = max(feet_x) - min(feet_x)
            yspread = max(feet_y) - min(feet_y)
            add("characters", name, "feet drift on turn (x/y)", f"{spread:.1f}/{yspread:.1f}px", "<=3px",
                spread <= 3 and yspread <= 3)
    jitter = 0.0
    for d in range(rows):
        xs = []
        for f in range(cols):
            crop = im.crop((f * cell, d * cell, (f + 1) * cell, (d + 1) * cell))
            opaque = [i for i, v in enumerate(crop.getchannel("A").getdata()) if v > 40]
            if opaque:
                xs.append(sum(i % cell for i in opaque) / len(opaque))
        if xs:
            jitter = max(jitter, max(xs) - min(xs))
    add("characters", name, "walk jitter (x)", f"{jitter:.1f}px", "<=4px", jitter <= 4.0)


def audit_objects():
    meta_path = f"{OBJ_DIR}/_meta.json"
    if not os.path.exists(meta_path):
        add("objects", "all", "baked set", 0, 1, False)
        return
    meta = json.load(open(meta_path))
    for key, info in meta.items():
        path = f"{OBJ_DIR}/{key}.png"
        if not os.path.exists(path):
            add("objects", key, "file present", 0, 1, False)
            continue
        im = Image.open(path).convert("RGBA")
        a = im.getchannel("A")
        px = list(a.getdata())
        cover = sum(1 for v in px if v > 40) / float(len(px))
        bbox = alpha_bbox(im)
        pad = 2
        edge_ok = bool(bbox) and bbox[0] >= pad and bbox[1] >= pad and bbox[2] <= im.width - pad and bbox[3] <= im.height - pad
        add("objects", key, "silhouette fill", f"{cover:.1%}", ">=4%", cover >= 0.04)
        add("objects", key, "padded (no crop)", "yes" if edge_ok else "no", "yes", edge_ok)
        expect = info.get("draw_size", [0, 0])
        aspect_ok = abs((im.width / im.height) - (expect[0] / max(expect[1], 1))) < 0.05
        add("objects", key, "aspect matches footprint", "yes" if aspect_ok else "no", "yes", aspect_ok)


def audit_textures():
    for name in sorted(os.listdir(TEX_DIR)) if os.path.isdir(TEX_DIR) else []:
        if not name.endswith(".png"):
            continue
        im = Image.open(f"{TEX_DIR}/{name}").convert("RGB")
        w, h = im.size
        left = [im.getpixel((0, y)) for y in range(h)]
        right = [im.getpixel((w - 1, y)) for y in range(h)]
        top = [im.getpixel((x, 0)) for x in range(w)]
        bottom = [im.getpixel((x, h - 1)) for x in range(w)]
        def diff(a, b):
            return sum(abs(p - q) for pa, pb in zip(a, b) for p, q in zip(pa, pb)) / (len(a) * 3.0)
        seam_x, seam_y = diff(left, right), diff(top, bottom)
        worst = max(seam_x, seam_y)
        add("textures", name, "tile seam error", f"{worst:.1f}", "<=24", worst <= 24)


audit_sheet_cover_nodes = None  # placeholder for clarity

for c in CHARS:
    audit_sheet(c)
audit_objects()
audit_textures()

fails = [r for r in results if not r[5]]
lines = ["# Asset Audit", "",
         "Generated by `python3 tools/asset_audit.py`. A failure is a ship blocker.", "",
         f"- Checks: **{len(results)}**", f"- Failures: **{len(fails)}**", ""]
area = None
for a, n, metric, val, limit, ok in results:
    if a != area:
        lines += ["", f"## {a.capitalize()}", "", "| Asset | Metric | Value | Limit | Result |", "|---|---|---|---|---|"]
        area = a
    lines.append(f"| {n} | {metric} | {val} | {limit} | {'PASS' if ok else 'FAIL'} |")
open("docs/ASSET_AUDIT.md", "w").write("\n".join(lines) + "\n")

for a, n, metric, val, limit, ok in results:
    if not ok:
        print(f"FAIL {a}/{n}: {metric} = {val} (limit {limit})")
print(f"AUDIT checks={len(results)} failures={len(fails)}")
sys.exit(1 if fails else 0)
