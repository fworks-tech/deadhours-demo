#!/usr/bin/env python3
"""Download the CC0 ambientCG surfaces used by the top-down layer and grade them
into the neon-noir palette. Regenerates assets/images/textures/*.png and
assets/data/asset_sources.json. Requires network access.

    python3 tools/grade_textures.py
"""
import io, json, os, subprocess, zipfile
from PIL import Image, ImageEnhance

PICKS = [
    ("concrete floor", "floor_concrete", (0.30, 0.33, 0.36)),
    ("wood floor", "floor_wood", (0.34, 0.28, 0.26)),
    ("tiles floor", "floor_tile", (0.30, 0.31, 0.33)),
    ("carpet", "floor_carpet", (0.34, 0.26, 0.30)),
    ("bricks", "wall_brick", (0.30, 0.27, 0.28)),
]
SIZE = 128


def curl(url, out=None, timeout=60):
    args = ["curl", "-sL", "--max-time", str(timeout), url]
    if out:
        args += ["-o", out, "-w", "%{http_code}"]
    return subprocess.run(args, capture_output=True, timeout=timeout + 20).stdout


def main():
    os.makedirs("assets/images/textures", exist_ok=True)
    os.makedirs("assets/data", exist_ok=True)
    sources = []
    for query, out, tint in PICKS:
        try:
            api = curl("https://ambientcg.com/api/v2/full_json?type=Material&limit=3&q="
                       + query.replace(" ", "%20"), timeout=25)
            assets = json.loads(api).get("foundAssets", [])
            if not assets:
                print("no hit:", query)
                continue
            asset = assets[0]
            aid = asset["assetId"]
            zpath = f"/tmp/{aid}.zip"
            if curl(f"https://ambientcg.com/get?file={aid}_1K-JPG.zip", zpath).decode() != "200":
                print("download failed:", aid)
                continue
            with zipfile.ZipFile(zpath) as z:
                names = [n for n in z.namelist() if n.lower().endswith((".jpg", ".png"))]
                color = [n for n in names if "color" in n.lower()] or names
                data = z.read(color[0])
            im = Image.open(io.BytesIO(data)).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
            im = ImageEnhance.Color(im).enhance(0.35)
            im = ImageEnhance.Brightness(im).enhance(0.55)
            im = ImageEnhance.Contrast(im).enhance(1.15)
            r, g, b = im.split()
            r = r.point(lambda v: int(v * tint[0] * 2.1))
            g = g.point(lambda v: int(v * tint[1] * 2.1))
            b = b.point(lambda v: int(v * tint[2] * 2.1))
            Image.merge("RGB", (r, g, b)).save(f"assets/images/textures/{out}.png")
            sources.append({
                "file": f"res://assets/images/textures/{out}.png",
                "asset": aid, "name": asset.get("displayName", aid),
                "author": "ambientCG (Lennart Demes)", "license": "CC0 1.0",
                "url": f"https://ambientcg.com/view?id={aid}", "source_query": query,
            })
            print("ok", out, "<-", aid)
        except Exception as exc:  # keep going: a missing texture falls back to flat colour
            print("err", query, exc)
    json.dump({"note": "External CC0 texture sources. Verify licenses before shipping.",
               "textures": sources}, open("assets/data/asset_sources.json", "w"), indent=2)
    print("sources:", len(sources))


if __name__ == "__main__":
    main()
