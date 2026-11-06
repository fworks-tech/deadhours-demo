# AGENTS.md

Guide for AI agents (and humans) working on the Dead Hours codebase. Read this before touching anything.

---

## Project Identity

**Dead Hours** is a 2D mobile narrative-driven choice game in Godot 4.x. It's a zombie survival story where player choices ripple across 3 chapters toward 7 endings. The architecture is **data-driven** — all story content lives in `assets/data/story.json` and the engine reads it at runtime.

---

## Architecture Rules

### The Golden Rule

> **Story content goes in `story.json`. Code goes in `.gd` files. Never mix them.**

If you need to add a new chapter, dialogue line, choice, or ending: edit `assets/data/story.json`. Do NOT write GDScript to hardcode story content.

If you need to change how the engine processes story: edit the autoload managers. Do NOT put story data in code.

### The Nine Autoloads

These are the backbone. Understand them before changing anything.

| Autoload | Role | What It Does | What It Does NOT Do |
|---------|------|-------------|---------------------|
| `GameManager` | State machine | Tracks game phase (splash, menu, playing, cutscene, choice, paused, epilogue) | Does NOT track story progress or flags |
| `StoryManager` | Narrative engine | Loads `story.json`, enters checkpoints, evaluates choices, advances story | Does NOT manage flags or UI |
| `ChoiceManager` | Choice flow | Presents choices, handles countdown timer, feeds selection to StoryManager | Does NOT render UI (that's ChoiceUI) |
| `FlagsManager` | State tracking | Stores all story flags (trust, corruption, items, met characters). Evaluates `requires` conditions | Does NOT decide which ending you get (that's emergent from flags) |
| `SaveManager` | Persistence | Saves/loads to `user://saves/`. Auto-saves at every choice point | Does NOT store story data (that's in story.json) |
| `AudioManager` | Audio | Music crossfade, SFX pooling, voice line playback | Does NOT load audio files (scenes reference them) |
| `SceneManager` | Transitions | Fade in/out between scenes | Does NOT manage the scene tree (that's Godot's job) |
| `SettingsManager` | Config | Persists settings to `user://settings.cfg` | Does NOT apply settings to UI (that's each UI script's job) |

### Data Flow

```
story.json
    ↓ (loaded once at startup)
StoryManager
    ↓ (enter_checkpoint)
    ↓ runs on_enter flag ops
FlagsManager
    ↓ (if type == "choice")
    ↓ evaluates requires per choice
ChoiceManager
    ↓ (player selects)
    ↓ applies effects
FlagsManager
    ↓ (enters next checkpoint)
StoryManager → repeat until type == "end"
    ↓
SaveManager (unlocks ending, auto-saves)
    ↓
SceneManager (transition to GameOverScreen)
```

### Scene Hierarchy

```
SplashScreen.tscn
    ↓ SceneManager.change_scene()
MainMenu.tscn
    ↓ SceneManager.change_scene()
GameScene.tscn
    ├── Camera2D
    ├── ContentLayer (dynamically loads checkpoint scenes)
    │   ├── CutsceneTemplate.tscn (for type: cutscene)
    │   ├── ExplorationScene.tscn (for type: exploration/puzzle)
    │   └── DialogueSystem.tscn (fallback if no scene file exists)
    └── HUD (CanvasLayer)
        ├── ChoiceUI (instance)
        └── PauseMenu (instance, hidden by default)
```

### Fallback System

If a checkpoint references a `.tscn` scene file that doesn't exist yet, `GameScene.gd` falls back to running the dialogue and choices directly from the JSON data using `DialogueSystem.tscn`. This means **you can write story content and test the full branching flow before any scene files are built**.

---

## File Conventions

### Naming

- **Autoloads:** `PascalCase.gd` in `autoload/` (e.g. `StoryManager.gd`)
- **Scripts:** `PascalCase.gd` matching their scene name in matching `scripts/` subdir
- **Scenes:** `PascalCase.tscn` in matching `scenes/` subdir
- **Story checkpoints:** `ch{num}_{description}` (e.g. `ch1_start`, `ch1_choice1`, `ch1_door_left`)
- **Choices:** `ch{num}_c{n}_{description}` (e.g. `ch1_c1_open`, `ch2_c1_honest`)
- **Flags:** snake_case, grouped by domain:
  - `met_*` — characters encountered
  - `trust_*` — relationship scores (integers)
  - `has_*` — inventory items (booleans)
  - `chapter*_complete` — progression markers
  - `corruption_level` — moral tracker (integer)
  - `secrets_discovered` — exploration reward counter

### Story JSON Format (Quick Reference)

```json
{
  "id": "ch1_choice1",
  "chapter": 1,
  "scene": "res://scenes/cutscenes/Ch1Door.tscn",
  "type": "choice",
  "speaker": "player",
  "dialogue": [
    { "speaker": "elena", "emotion": "scared", "text": "They're coming!", "voice": "res://assets/audio/voice/ch1_elena_01.ogg" }
  ],
  "choices": [
    {
      "id": "ch1_c1_open",
      "text": "Open the door",
      "character": "player",
      "requires": { "has_key": true },
      "requires": { "trust_alice": { ">=": 2 } },
      "effects": [ { "set": { "met_elena": true } }, { "add": { "trust_elena": 2 } } ],
      "next": "ch1_elena_enter"
    }
  ],
  "on_enter": [ { "set": { "chapter1_started": true } } ],
  "next": "ch2_start",
  "end_type": "good"
}
```

Full documentation: [`docs/STORY_AUTHORING_GUIDE.md`](docs/STORY_AUTHORING_GUIDE.md)

---

## What to Do When...

### Adding a new chapter
1. Add a new key to `chapters` in `story.json` (e.g. `"4": { ... }`)
2. Link the previous chapter's final checkpoint `next` to `"ch4_start"`
3. Add all flags used in the chapter to `_default_flags` in `FlagsManager.gd`
4. Run StoryValidator to verify no broken references

### Adding a new choice
1. Find or create a `type: "choice"` checkpoint
2. Add a choice object to the `choices` array with `id`, `text`, `effects`, `next`
3. Create the target checkpoint it leads to
4. If the choice is conditional, add `requires` (simple equality or operator object)
5. Run StoryValidator

### Creating a new ending
1. Add a checkpoint with `type: "end"` and `end_type` ("good" / "bad" / "neutral")
2. Link a prior choice to it via `next`
3. Update `total_endings` in the root of `story.json`
4. Run StoryValidator

### Adding a new flag
1. Add it to `_default_flags` in `FlagsManager.gd` with its default value
2. Use it in `requires`, `effects`, or `on_enter` in `story.json`
3. The engine handles the rest

### Adding a new scene file
1. Create the `.tscn` in the appropriate `scenes/` subdirectory
2. Reference it from a checkpoint's `scene` field in `story.json`
3. The scene script should connect to `StoryManager` signals for flow control
4. If using `CutscenePlayer`, provide a `timeline` array in the checkpoint

### Changing how choices are evaluated
Edit `FlagsManager.evaluate_requirements()` and `StoryManager.can_show_choice()`. These two methods are the gatekeeping layer.

### Changing the UI theme
Edit `theme/default_theme.tres`. All UI scenes use this theme resource.

---

## Validation

### StoryValidator (`addons/story_validator/StoryValidator.gd`)
Run in the Godot editor. Checks for:
- Missing `next` references (checkpoint leads nowhere)
- Orphaned checkpoints (nothing leads to them)
- Missing scene files (checkpoint references a `.tscn` that doesn't exist)
- Duplicate checkpoint IDs
- Choices without `next`
- Endings without `end_type`
- Mismatched `total_endings` count

### StoryTools (`scripts/utils/StoryTools.gd`)
Static utilities for debugging:
- `get_all_checkpoints()` — list every checkpoint ID
- `get_reachable_checkpoints()` — checkpoints reachable from `ch1_start`
- `get_orphan_checkpoints()` — unreachable checkpoints
- `count_paths_to_ending(ending_id)` — how many distinct paths reach an ending

---

## Code Style

- GDScript 2.0 syntax (Godot 4.x): typed variables, signals, match statements
- 4-space indentation (tabs, per Godot convention)
- Comments at the top of each file explaining its role
- Signal-based communication between autoloads and scenes
- No hardcoded story strings in GDScript — all text lives in `story.json` or localization CSVs

---

## Testing

The game can be tested without scene files. Because `GameScene.gd` falls back to running dialogue + choices from the JSON directly, you can:
1. Write story content in `story.json`
2. Press Play in Godot
3. Navigate the full branching tree via dialogue + choice buttons
4. Verify all endings are reachable

Once story flow is validated, create the `.tscn` scene files for visual polish.

---

## Don'ts

- **Don't** hardcode dialogue in GDScript
- **Don't** create flags in `story.json` without registering them in `FlagsManager._default_flags()`
- **Don't** reference scene files in `story.json` without eventually creating them (use the fallback for prototyping, then build the scene)
- **Don't** change `StoryManager`'s public API without updating `SaveManager` (save/load depends on `get_save_data()` / `load_from_save()`)
- **Don't** forget to run StoryValidator after editing `story.json`
- **Don't** commit `story.json` with broken `next` references

---

## Current State

| Component | Status |
|-----------|--------|
| Story engine (StoryManager) | ✅ Complete |
| Flag system (FlagsManager) | ✅ Complete |
| Choice system (ChoiceManager) | ✅ Complete |
| Save/load (SaveManager) | ✅ Complete |
| Audio (AudioManager) | ✅ Complete |
| Settings (SettingsManager) | ✅ Complete |
| Scene transitions (SceneManager) | ✅ Complete |
| Dialogue system | ✅ Complete |
| Cutscene player | ✅ Complete |
| Touch input | ✅ Complete |
| HUD | ✅ Complete |
| All UI screens | ✅ Complete |
| Story content (3 chapters) | ✅ Complete |
| Story validator | ✅ Complete |
| Export presets | ✅ Complete |
| Theme resource | ✅ Complete |
| Localization (EN + pt-BR) | ✅ Complete |
| Character portraits (5 characters) | ✅ Generated — need more emotions |
| Background images (8 scenes) | ✅ Generated |
| BackgroundManager (autoload) | ✅ Complete |
| Art pipeline documentation | ✅ Complete |
| Character sprites (exploration) | ❌ Not started |
| Scene files (.tscn) | ⚠️ Templates created — need visual assets |
| Character sprites/animations | ❌ Not started |
| Audio assets | ❌ Not started |
| Background art | ❌ Not started |
