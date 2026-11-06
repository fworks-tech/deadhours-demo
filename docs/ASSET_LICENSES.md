# Asset Licenses — Dead Hours

Every external asset in the project must be listed here with its license and
source. If a license is unclear, the asset does not ship.

## Third-party (CC0 1.0)

| File | Asset | Author | License | Source |
|---|---|---|---|---|
| `assets/images/textures/floor_concrete.png` | Concrete 048 | ambientCG (Lennart Demes) | CC0 1.0 | https://ambientcg.com/view?id=Concrete048 |
| `assets/images/textures/floor_wood.png` | Wood Floor 051 | ambientCG (Lennart Demes) | CC0 1.0 | https://ambientcg.com/view?id=WoodFloor051 |
| `assets/images/textures/floor_tile.png` | Tiles 141 | ambientCG (Lennart Demes) | CC0 1.0 | https://ambientcg.com/view?id=Tiles141 |
| `assets/images/textures/floor_carpet.png` | Carpet 016 | ambientCG (Lennart Demes) | CC0 1.0 | https://ambientcg.com/view?id=Carpet016 |
| `assets/images/textures/wall_brick.png` | Bricks 113 A | ambientCG (Lennart Demes) | CC0 1.0 | https://ambientcg.com/view?id=Bricks113A |

CC0 1.0 (public domain dedication): no attribution required, commercial use
allowed, modification allowed. Attribution is kept here anyway.

**Processing:** downloaded as 1K color maps, reduced to 128x128 px for tiling,
desaturated to 35%, brightness 0.55, contrast 1.15, then tinted per surface so
they sit inside the neon-noir grade. Reprocess with
`python3 tools/grade_textures.py` (regenerates from the original downloads).

**Machine-readable list:** `assets/data/asset_sources.json`.

## Project assets (original)

Everything else — character sheets, portraits, backgrounds, props, UI,
shaders — is original work generated for Dead Hours and belongs to the project:

- `assets/images/sprites/topdown/*_sheet.png` — baked from `TopDownFigure.gd`
  by `tools/bake_character_sheets.gd` (8 directions x 8 frames, 128 px cells).
- `assets/images/portraits/`, `assets/images/backgrounds/` — painterly set.
- `assets/images/sprites/objects/*.png` — doors, lockers and weapon pickups,
  baked from `TopDownObjectArt.gd` by `tools/bake_object_sprites.gd` (10 sprites,
  2x, padded canvases, `_meta.json` with footprints).
- `assets/data/*.json` — game data.

## Deliberately rejected

- **Kenney.nl** packs: CC0 and a good fit, but the site blocks automated
  downloads (HTTP 403). Safe to add by hand later; drop the pack in
  `assets/external/` and register it here first.
- **OpenGameArt "Top down home furniture"**: usable but CC-BY 3.0 and pixel-art
  sized (8-64 px), which fights the current flat-shape furniture read.
- **LimeZu / itch.io interiors**: free versions are non-commercial or require
  the paid tier; not used without a purchased license.
