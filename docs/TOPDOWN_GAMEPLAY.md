# Top-Down Gameplay — Dead Hours

Dead Hours is now a **narrative-driven top-down action game**: painterly cutscenes and
choices carry the story, and the violent beats are playable missions seen from above
(Hotline Miami camera, pace and lethality).

Everything narrative already built stays: the checkpoint graph, flags, relationships,
the 7 endings, the DEEPTALES validator. Missions are just another checkpoint type.

---

## 1. Design rules

| Rule | Why |
| :--- | :--- |
| One hit kills, both ways | Tension is positioning, not health bars |
| Dash is the defensive verb | No blocking; escape is movement |
| Guns are loud, melee is silent | Gunfire alerts everyone in earshot → consequences |
| Enemies die permanently | Every body is a flag-able consequence |
| Missions are short (60–180s) | Fits a mobile session; restarts are cheap |
| The story remembers | Kills, alarms and time become story flags |

### Controls

**Desktop**

- `WASD` / arrows: move
- Mouse: aim
- Left click (or `J`): attack / shoot
- `Space` or `Shift`: dash
- `E`: interact (doors, lockers)
- `R`: restart after death

**Touch**

- Left half drag: virtual stick for movement
- Right half drag: aim stick; holding it fires, with auto-aim assist
- On-screen buttons: restart (top right), interact hint (bottom center)

---

## 2. File map

| Path | Purpose |
| :--- | :--- |
| `scenes/gameplay/TopDownMission.tscn` | The only mission scene; loads a level by id |
| `scripts/gameplay/topdown/TopDownMission.gd` | Level builder, camera, HUD, touch input, mission rules |
| `scripts/gameplay/topdown/TopDownPlayer.gd` | Movement, dash, aim, melee/hitscan weapons, death |
| `scripts/gameplay/topdown/TopDownEnemy.gd` | Patrol, vision cone, LOS, noise reaction, chase, one-hit kill |
| `assets/data/levels/*.json` | Level data (geometry, spawns, pickups, flags) |
| `tools/TopDownSmokeTest.tscn` | Headless QA: builds a level and exercises combat/exit |
| `tools/story_flow_probe.gd` | Headless QA: checkpoint → mission → back to story |

---

## 3. Level format

Levels live in `assets/data/levels/<mission_id>.json`. Rooms are rectangles; walls are
generated around them and door openings are carved out of those walls.

```jsonc
{
  "id": "ch1_fireescape",
  "title": "The Fire Escape",
  "subtitle": "Seven floors of rusted metal",
  "kicker": "DEAD HOURS · CHAPTER 1 · 04:12",
  "loading_art": "ch1_fire_escape",      // existing painterly background key
  "briefing": "…",
  "tip": "One hit kills. Theirs and yours.",
  "objective": "DESCEND THE FIRE ESCAPE",
  "world": { "width": 1440, "height": 2560 },
  "player": { "spawn": [520, 160], "weapon": "knife" },
  "rooms": [
    { "rect": [480, 100, 480, 320], "floor": "checker_red",
      "neon": "#ff2e88", "neon_side": "top", "label": "7F" }
  ],
  "doors": [ { "rect": [660, 410, 160, 20] } ],        // architectural openings
  "props": [
    { "type": "crate",  "rect": [500, 130, 56, 56] },
    { "type": "barrel", "pos": [900, 350], "radius": 20 },
    { "type": "door",   "rect": [660, 1204, 160, 16], "locked": false },
    { "type": "locker", "rect": [430, 660, 54, 92] }
  ],
  "enemies": [
    { "pos": [520, 760], "weapon": "fists",
      "patrol": [[520, 760], [520, 900]], "facing": [1, 0],
      "view_range": 430, "view_angle": 96 }
  ],
  "pickups": [ { "weapon": "pistol", "ammo": 7, "pos": [640, 920] } ],
  "exit": { "rect": [620, 2140, 240, 140], "label": "STREET" },
  "on_enemy_killed": [ { "add": { "corruption_level": 1 } } ],
  "on_alarm":        [ { "set": { "made_enemies": true } } ],
  "on_complete":     [ { "set": { "fire_escape_used": true } } ]
}
```

### Field notes

- `floor`: `checker`, `checker_red`, `concrete`, `dirt`.
- `neon`: any hex; the strip is drawn along `neon_side` (`top|bottom|left|right`).
- Rooms that share an edge become connected once a `doors` opening covers the seam.
- `props.door` is an interactive door on top of an opening (blocks movement and vision
  until opened with `E`). `locked: true` refuses with a HUD message.
- `props.locker` hides the player: enemies lose the target until you step out.
- `complete_on_clear: true` ends the mission when the last enemy dies, instead of
  requiring the exit zone.
- `weapon`: `fists`, `knife`, `bat`, `pistol`, `shotgun`.

### Automatic result flags

On completion the mission writes, per mission id:

- `<mission_id>_complete` (bool)
- `<mission_id>_kills` (int)
- `<mission_id>_alerted` (bool)
- `<mission_id>_time` (seconds)

Then it applies `on_complete` flag operations and calls
`StoryManager.advance_to_next_checkpoint()`.

---

## 4. Story wiring

A checkpoint becomes a mission with:

```json
{
  "type": "mission",
  "mission_id": "ch1_fireescape",
  "scene": "res://scenes/gameplay/TopDownMission.tscn"
}
```

`StoryManager` treats `mission` as `PLAYING`, changes scene, and the mission reads
`StoryManager.current_checkpoint.mission_id`. If a checkpoint's scene file does not
exist yet, `StoryManager` now falls back to `GameScene.tscn`, which renders that
checkpoint's dialogue and choices instead of leaving the player stuck in the previous
scene.

Live now:

| Checkpoint | Mission | Story role |
| :--- | :--- | :--- |
| `ch1_fireescape` | `ch1_fireescape` | Escape the building down the fire escape |
| `ch1_stairwell` | `ch1_stairwell` | Alternative descent; sets `made_enemies` if the alarm goes |
| `ch2_sneak_approach` | `ch2_sneak` | Reach the Route 9 back office; `garcia_hostile` on alarm |

Consequences already feed the ending logic:

- `corruption_level` grows with every kill (per-kill flag operation).
- `made_enemies` / `garcia_hostile` push Chapter 2 toward the hostile branch.
- `fire_escape_used`, `took_stairs`, `has_flashlight` stay as the story wrote them.

---

## 5. Art direction (neon noir)

The gameplay layer is **procedural neon noir** so it can ship without waiting on a
sprite pipeline, and so it can be replaced asset-by-asset later.

| Element | Treatment |
| :--- | :--- |
| Floors | Checker tiles, 64px cells, grout lines, deterministic grime |
| Neon | Magenta `#ff2e88`, cyan `#28e0d0`, amber `#ffb03a` wall strips + glow |
| Walls | Slate `#333d45` with a lit top edge |
| Void | `#0b0e11` with a faint 128px grid (building mass, not emptiness) |
| Blood | Layered dark red splatter decals, permanent per mission |
| Characters | Layered 3/4-top-down figures: shadow, walk cycle, jacket, arms, weapon, face, hair (`TopDownFigure.gd`) |
| Camera | Zoom 1.55, smoothing, 70px look-ahead toward aim, shake on shots |
| Vignette | Existing `shaders/vignette.gdshader`, intensity 0.32 |

Existing painterly assets are **not wasted**: every mission briefing is a full-screen
loading/briefing screen using the chapter background art (`ch1_fire_escape`,
`ch1_stairwell`, `ch2_gas_station`). Portraits and cutscenes are untouched.

### Controls

Touch is the primary scheme, desktop is the fallback.

| Input | Touch | Keyboard |
|---|---|---|
| Move | left stick (floating, fixed home ring) | WASD / arrows |
| Aim | right stick, holds last direction | mouse |
| Attack | ATTACK button (hold to keep firing) | LMB / J |
| Dash | DASH button, edge-triggered, greys out on cooldown | SPACE / SHIFT |
| Use (door, locker, pickup) | USE button, only appears when something is in range | E |

Both sticks and every button track their own touch index, so you can move,
aim and attack at the same time. The right stick only aims; it never
auto-fires. Every control has a home ring so the thumbs can find it without
looking. Layout is recomputed on resize and can be forced for QA with
`layout_size`. Verified by `res://tools/TouchControlsTest.tscn` (23 checks:
layout inside the viewport, dead zones, no auto-fire, dash/interact edge
consumption, multi-touch).

### Rooms and objects

Levels are built from flat rooms plus a `props` array. Every prop is a
`TopDownProp` with a hard outline, a couple of flat highlight bands and a
footprint collider, so the map reads like a Hotline Miami floor plan:

`sofa`, `bed`, `table`, `chair`, `bench`, `counter`, `fridge`, `tv`, `shelf`,
`cabinet`, `desk`, `dumpster`, `car`, `plant`, `rug`, `trash`, `streetlight`
(plus the existing `crate`, `barrel`, `locker`, `door`).

```json
{"type": "sofa", "rect": [380, 2400, 190, 74]}
{"type": "plant", "pos": [930, 390], "radius": 22}
{"type": "rug", "rect": [470, 180, 240, 180], "solid": false}
```

Solid props block movement, bullets and vision cones. Rugs, streetlights and
trash are decoration only. Doorways are kept clear; spawn points are checked
against footprints.

### Combat effects

`TopDownFX.gd` holds every impact beat, all procedural (no audio or texture
assets needed):

| Effect | Trigger | Notes |
|---|---|---|
| muzzle flash + powder puff | any firearm shot | star burst along the barrel, scales with weapon |
| shell casing | firearm shot | brass splinter with gravity and spin |
| tracer | every bullet | tapered line, 0.1 s fade |
| impact sparks / dust / bullet hole | bullet hits wall | small persistent scorch dot |
| glass break | impact kind `glass` | pale shards + frosty crack decal |
| blood spray + mist | melee hit, gunshot kill | directional, gravity-fed |
| blood pool / smear | death, level `effects.blood_smears` | grows over 0.8 s, stays for the run |
| corpse beat | enemy death | pool under the body, hit-stop 45 ms, small shake |
| explosion | fuel pump, propane tank | flash, shockwave ring, embers, smoke column, debris, scorch, alarm, chain reaction |
| damage vignette | player death | red edge flash |
| ambient fire | level `effects.fires` | looping flame + smoke column |

Explosives are level data: `{"type": "pump" | "tank", "rect": [...], "radius_fx": 170}`.
They are solid, block bullets, explode when shot or caught in a blast, damage
both sides, and chain to neighbours within 1.7x their radius.

Story hooks that drove this (`assets/data/story.json`): the gas station chapter
(fuel pumps), "a shot rings out, glass shatters" (`ch2_run_escape`), fires
visible in `ch1_barricade_survive`, and the blood smear down the stairwell in
`ch1_stairwell`.

### Surfaces and licensed assets

Floors use CC0 photographic textures (ambientCG) graded into the neon-noir
palette, tiled under the existing checker/grime/neon pass; walls use a matching
brick texture. Every third-party file is registered in `docs/ASSET_LICENSES.md`
and `assets/data/asset_sources.json` before it ships.

### Characters

`TopDownFigure.gd` draws every character out of layered shapes, driven by
`assets/data/characters.json`:

- **Player — Elena**: designed from her existing portrait palette (dark auburn
  ponytail, teal field jacket, rust accent). Walk cycle, weapon swing, hit flash,
  collapsed corpse.
- **Shambler**: stooped, one arm reaching, torn shirt, exposed ribs, dragging foot.
- **Runner**: lean, blood-soaked, arms back, faster and lunges further.
- **Bloated**: wide silhouette, bald, blotched skin, slow.

The infected also *behave* like zombies: shambling gait, body sway, head twitch,
and a telegraphed lunge (windup, then a burst of speed) when the player is just
out of reach. Vision cones are wall-clipped, so they read as sight, not light.

Heads are drawn screen-aligned rather than with the body, so direction reads
correctly: facing south you see the face; east/west you see a profile; facing
north (away from the camera) you see the back of the head and the nape, with no
eyes or mouth. `view_dir` is the world aim/facing vector; the figure cancels its
own rotation for the head pass.

Swap a color, hairstyle or build in `characters.json` and every mission follows.
A generated sprite sheet can replace the figure later without touching gameplay:
the figure node is the only thing that knows how a body is drawn.

### Game-ready character sheets

The blockout figure is baked into a real asset by
`tools/bake_character_sheets.gd`:

- 8 directions x 8 walk frames, 128 px cells (2x world density), transparent PNG
- `assets/images/sprites/topdown/<char>_sheet.png` + `_sheet.json` (grid, pivot, fps)
- `TopDownFigure` loads the sheet automatically and falls back to the blockout
  draw if it is missing, so painted frames can drop straight in later
- weapons stay live: the sheet holds the body, the held weapon is drawn on top
  so pickups and ammo read immediately

Rebake after changing `characters.json`:
`xvfb-run -a godot --path . res://tools/BakeCharacterSheets.tscn`

Object art lives in `TopDownObjectArt.gd`, shared by the live nodes and
`tools/bake_object_sprites.gd`: doors (h/v, closed/open), lockers (closed/open)
and pickups (bat, knife, pistol, shotgun), 2x with padded canvases. Nodes prefer
the baked sprite and fall back to the shared draw, so art can be replaced one
file at a time.

Quality gate:

    python3 tools/asset_audit.py     # 63 checks, exit 1 on any failure

It fails on empty or clipped frames, silhouettes that exceed the cell, feet that
drift when the character turns, jittery walk cycles, cropped object sprites and
visible texture seams. Current status: **63 checks, 0 failures**
(`docs/ASSET_AUDIT.md`).

Preview the cast: `res://tools/CharacterPreview.tscn`.
Check the four facings: `res://tools/FacingPreview.tscn`.

### Art pipeline

`tools/art_pipeline.py` gained a `neon_noir` style pack (plus a `sprite` prompt kind)
so generated or hand-made top-down sprites, props and backgrounds can be produced with
the same manifest → fill → verify workflow:

```bash
python3 tools/art_pipeline.py prompts --style neon_noir
python3 tools/art_pipeline.py postprocess art.png --style neon_noir
```

---

## 6. Adding a mission

1. Write `assets/data/levels/<id>.json` (copy an existing level as a base).
2. Add a checkpoint in `assets/data/story.json` with `type: "mission"`,
   `mission_id: "<id>"`, `scene: "res://scenes/gameplay/TopDownMission.tscn"`.
3. Validate: `python3 tools/validate_story.py` (or the Godot addon).
4. Playtest: open `scenes/gameplay/TopDownMission.tscn` and set
   `default_mission_id` in the inspector, or run the story to that checkpoint.
5. QA headless:

```bash
godot --headless --path . res://tools/TopDownSmokeTest.tscn
TD_AUTOSTART=1 godot --headless --path . res://scenes/gameplay/TopDownMission.tscn --quit-after 300
```

`TD_AUTOSTART=1` skips the briefing so automated runs reach gameplay immediately.

---

## 7. Known gaps / next

1. Character sprites are drawn procedurally; a generated sprite sheet should replace
   the body drawing (the `sprite` art-pipeline kind is ready for it).
2. No SFX/music yet — the mission uses no audio. Next pass: footsteps, gunshots,
   melee hit, alarm sting, and a synth loop per mission.
3. Enemy steering is direct (no navmesh); wide rooms with L-shaped obstacles can
   snag an enemy. Rectangular room layouts avoid it today.
4. Difficulty knobs (enemy speed, view range, grace period) are per-level JSON fields;
   no global difficulty setting yet.
5. Thrown weapons and weapon pickups from corpses are not implemented.
