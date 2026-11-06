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
- `assets/images/backgrounds/*.png` (four paintings) — **Painterly Backgrounds Free**
  by GegX: painted forest (fog / night) and tavern interior (night / fog), used as
  mission briefing art. Licence: use in commercial and non-commercial projects,
  modified or not; no resale or redistribution as an image pack; no AI training.
  The pack is AI-generated and the author discloses it. Source:
  https://gegx.itch.io/painterly-backgrounds-free
  Downloaded but **not** wired in (visual mismatch with the urban neon-noir
  setting, kept out of the repo): Dark Fantasy Heroines Free, Painterly Monster
  Cards Free.
- `assets/images/sprites/zombies_painted/*.png` — **GegX FREE PACK - FRESH ZOMBIES
  v1.1** (fresh_zombie, shopper, heavy, old_man, teen; 4 directions, 12-frame
  walk). Licence: use in any project, commercial or free, no credit required;
  reselling or redistributing the assets themselves is not allowed. Full text
  in the pack README; source https://gegx.itch.io/fresh-zombies-painted .
  Downscaled from 192 px to 128 px per frame with the pack pivot (x 96, y 165)
  preserved; `assets/data/painted_zombies.json` holds the mapping.
- `assets/images/textures/*.png` — **PSX Retro Seamless Textures (free sample)**
  by REEBOO Labs, 31 seamless 64/128 px PS1 textures; we ship 7 of them,
  recoloured by the game's grade. Licence: royalty-free use in commercial and
  non-commercial games, no redistribution as an asset pack or texture library.
  Full text: `docs/licenses/reeboo_psx_retro_textures_LICENSE.txt`.
  Source: https://reebo0.itch.io/psx-retro-textures-free-sample
- `assets/audio/**` — music, ambience, voices and SFX are **original work**,
  synthesised from maths by `tools/make_audio.py`. No third-party samples, no
  attribution required. Rebuild with `python3 tools/make_audio.py`.
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
