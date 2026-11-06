#!/usr/bin/env python3
"""Align baked character sheets so the figure does not slide when it turns.

For every direction row it finds the feet band (lower third of the cell) and
translates that row so the band's centroid lands on the same spot in every
direction. Offsets are written back into the sheet metadata.

    python3 tools/align_sheets.py [--check]
"""
import json, sys
from PIL import Image

SHEET_DIR = "assets/images/sprites/topdown"
CHARS = ["elena", "shambler", "runner", "bloated"]
BAND = 0.62        # bottom band start as a fraction of the cell
check_only = "--check" in sys.argv
worst = 0.0

for name in CHARS:
    path = f"{SHEET_DIR}/{name}_sheet.png"
    meta_path = f"{SHEET_DIR}/{name}_sheet.json"
    im = Image.open(path).convert("RGBA")
    meta = json.load(open(meta_path))
    cell, cols, rows = meta["frame_w"], meta["frames"], meta["directions"]
    band = int(cell * BAND)

    anchors = []
    for d in range(rows):
        sx = sy = n = 0
        for f in range(cols):
            crop = im.crop((f * cell, d * cell, (f + 1) * cell, (d + 1) * cell))
            px = crop.load()
            for y in range(band, cell):
                for x in range(cell):
                    if px[x, y][3] > 40:
                        sx += x
                        sy += y
                        n += 1
        anchors.append((sx / n, sy / n) if n else (cell / 2.0, cell * 0.85))

    tx = sum(a[0] for a in anchors) / len(anchors)
    ty = sum(a[1] for a in anchors) / len(anchors)
    offsets = []
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for d in range(rows):
        dx, dy = int(round(tx - anchors[d][0])), int(round(ty - anchors[d][1]))
        offsets.append([dx, dy])
        worst = max(worst, abs(dx), abs(dy))
        row = im.crop((0, d * cell, cell * cols, (d + 1) * cell))
        out.paste(row, (dx, d * cell + dy), row)
        print(f"{name} dir{d}: shift {dx:+d},{dy:+d}")

    if max(abs(v) for off in offsets for v in off) <= 1 and not check_only:
        print(f"{name}: already aligned, skipping")
        continue
    meta["align_offsets"] = offsets
    meta["pivot"] = [cell * 0.5, cell * 0.5]
    if not check_only:
        out.save(path)
        json.dump(meta, open(meta_path, "w"), indent=2)
    print(f"{name}: max shift {worst}px")

print(f"ALIGN worst_shift={worst}px")
