# Art Pipeline Guide — Dead Hours

How visual assets are generated, stored, and wired into the game.

---

## Art Style

**Genre:** Horror / Thriller
**Aesthetic:** Dark, desaturated, painterly, high-contrast dramatic lighting
**Reference:** Until Dawn concept art, The Last of Us key art

### Style Rules for AI Generation
- **Palette:** Desaturated with cold blue/teal shadows and warm amber/orange highlights
- **Lighting:** Single strong light source from one side, deep shadows on the opposite
- **Backgrounds:** No people, wide establishing shots, atmospheric fog/rain
- **Portraits:** Head and shoulders bust shot, near-black background, emotion-driven expression
- **Format:** PNG, 16:9 for backgrounds (1280×720), 1:1 for portraits (512×512)
- **Consistency:** Same painterly brush texture across all assets

---

## Asset Types

### 1. Character Portraits
Used in the **DialogueSystem** — displayed in the portrait panel during dialogue.

**Location:** `assets/images/portraits/{character}_{emotion}.png`

**Characters & Emotions Needed:**

| Character | Emotions | Status |
|-----------|----------|--------|
| Elena | scared, breathless, relieved | ✅ scared (fallback for all) |
| Danny | scared, pleading, weak, peaceful, broken, relieved, neutral | ✅ scared (fallback for all) |
| Garcia | neutral, serious, cold | ✅ neutral (fallback for all) |
| Priya | neutral, angry | ✅ neutral (fallback for all) |
| Dr. Chen | neutral, serious, sad, amazed | ✅ neutral (fallback for all) |
| Marcus | wrong (infected) | ❌ Not generated |
| Narrator | none (text only, grey color) | N/A |
| Unknown | none (text only, grey color) | N/A |
| Radio | none (text only, blue color) | N/A |
| Marcus (text) | none (text only, green color) | N/A |

**Config:** `assets/data/portraits.json` maps speakers → emotions → texture paths.

### 2. Background Images
Used in **CutsceneTemplate** and exploration scenes as the background layer.

**Location:** `assets/images/backgrounds/{key}.png`

| Key | Scene | Status |
|-----|-------|--------|
| ch1_bedroom | Apartment bedroom at 3:47 AM, rain | ✅ |
| ch1_hallway_peephole | Apartment hallway through peephole | ✅ |
| ch1_fire_escape | Exterior fire escape, 7 floors, rain | ✅ |
| ch1_stairwell | Dark stairwell, blood smear | ✅ |
| ch1_garage | Underground parking garage | ✅ |
| ch2_gas_station | Lone gas station on Route 9 at night | ✅ |
| ch3_riverside | Walled settlement at dusk | ✅ |
| route9_highway | Empty highway at night, abandoned cars | ✅ |

**Mapping:** `BackgroundManager.gd` maps checkpoint IDs → background keys. Update the `mappings` dictionary when adding new checkpoints.

### 3. Character Sprites (Exploration)
Used in **ExplorationScene** for player movement and NPC interactions.

**Location:** `assets/images/sprites/{character}/`
- `idle.png` — static pose
- `walk_down.png`, `walk_up.png`, `walk_left.png`, `walk_right.png` — 4-frame strips
- `run_down.png`, etc. — optional

**Status:** ❌ Not started — needed for exploration/puzzle phases

### 4. UI & Theme
**Location:** `theme/default_theme.tres` — dark narrative theme, mobile-optimized
**Icon:** `icon.svg` — app icon
**Status:** ✅ Complete

### 5. Special Effects
- Fade transitions: handled by `SceneManager` (ColorRect overlay)
- Screen shake: can be added to `Camera2D` in CutscenePlayer
- Vignette: can be added as a Shader on a CanvasLayer
- Blood splatter overlay: can be added as a ColorRect with a noise texture
- Glitch effect: can be added for infected POVs

**Status:** ❌ Not started

---

## AI Image Generation Prompts

### Character Portrait Template
```
Dark horror video game character portrait. [CHARACTER DESCRIPTION].
[EXPRESSION DESCRIPTION]. Lit by [LIGHTING DESCRIPTION].
[BACKGROUND DESCRIPTION]. Painterly digital art style, desaturated palette,
high contrast dramatic lighting, visible brush texture.
Head and shoulders bust shot on near-black background.
Horror thriller game aesthetic similar to Until Dawn concept art.
```

### Background Template
```
Dark horror video game background scene. [SCENE DESCRIPTION].
No people visible. Painterly digital art, desaturated palette [with COLOR accents],
high contrast, atmospheric [FOG/RAIN/etc], horror thriller aesthetic.
2D game background art, [COMPOSITION TYPE].
```

---

## Workflow

1. **Generate** the image using AI (Consistent style prompts above)
2. **Download** to the appropriate `assets/images/` subdirectory
3. **Register** in `portraits.json` (for portraits) or `BackgroundManager` mappings (for backgrounds)
4. **Test** in Godot — the DialogueSystem and CutsceneTemplate load assets automatically
5. **Iterate** — regenerate if the style doesn't match

## Adding New Assets

### New character portrait
1. Generate image with consistent prompt
2. Save to `assets/images/portraits/{character}_{emotion}.png`
3. Add entry to `assets/data/portraits.json` under that character's emotion map
4. The DialogueSystem will load it automatically based on dialogue `speaker` + `emotion`

### New background
1. Generate image
2. Save to `assets/images/backgrounds/{key}.png`
3. Add entry to `portraits.json` → `"backgrounds"` section
4. Add mapping in `BackgroundManager.gd` → `_infer_background_key()` dictionary
5. The CutsceneTemplate will load it automatically on checkpoint entry

### New character sprite (for exploration)
1. Create sprite sheet (idle + walk cycles) in Aseprite or generate
2. Export as PNG strips to `assets/images/sprites/{character}/`
3. Create an `AnimatedSprite2D` node with a `SpriteFrames` resource
4. Reference in `ExplorationScene.tscn`
