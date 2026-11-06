# Dead Hours

A narrative-driven top-down action game for mobile (Android + iOS), built in Godot 4.4. Inspired by *Until Dawn* for the branching story and *Hotline Miami* for the playable violence: fast, one-hit-kill missions seen from above, wrapped in painterly cutscenes, choices and seven endings.

## Premise

The zombie outbreak begins at 3:47 AM. You wake to screaming. You have minutes to decide who lives, who dies, and who you become. Over three chapters — your apartment, a gas station, and a walled settlement called Riverside — every decision carves a path toward one of seven endings. Some are heroic. Some are quiet. Some are the kind you carry alone.

## Tech Stack

- **Engine:** Godot 4.4 (GDScript, GL Compatibility renderer)
- **Platform:** Android (APK + AAB) and iOS
- **Architecture:** Data-driven narrative engine — all story content lives in a single `story.json` file
- **Localization:** EN + pt-BR

## Project Structure

```
dead-hours/
├── project.godot              # Godot project config + autoloads
├── export_presets.cfg          # Android + iOS export presets
├── icon.svg                    # App icon
│
├── autoload/                   # Singleton managers (always loaded)
│   ├── GameManager.gd          #   Game state machine
│   ├── StoryManager.gd         #   Narrative engine — loads & drives story.json
│   ├── ChoiceManager.gd        #   Choice presentation + countdown timer
│   ├── FlagsManager.gd         #   Branching state — flags, trust, corruption
│   ├── SaveManager.gd          #   Save/load (3 slots + auto-save)
│   ├── AudioManager.gd         #   Music crossfade, SFX pool, voice lines
│   ├── SceneManager.gd         #   Scene transitions with fade
│   └── SettingsManager.gd      #   Audio volumes, language, haptics, accessibility
│
├── scenes/                     # Godot scene files (.tscn)
│   ├── core/                   #   GameScene, SplashScreen, CutsceneTemplate, ExplorationScene
│   ├── narrative/              #   DialogueSystem
│   └── ui/                     #   MainMenu, SettingsScreen, PauseMenu, GameOverScreen,
│                               #   SaveSelectScreen, CreditsScreen, ChoiceUI, HUD
│
├── scripts/                    # GDScript files
│   ├── core/                   #   GameScene, SplashScreen
│   ├── narrative/              #   CutscenePlayer, CutsceneTemplate, DialogueSystem
│   ├── gameplay/               #   ExplorationScene, TouchInputManager
│   │   └── topdown/            #     TopDownMission, TopDownPlayer, TopDownEnemy
│   ├── ui/                     #   All UI controllers
│   └── utils/                  #   StoryTools (graph analysis, path counting)
│
├── assets/
│   ├── data/
│   │   ├── story.json          #   ← THE STORY — all chapters, choices, endings
│   │   ├── story_schema.json   #   JSON Schema documenting the story format
│   │   └── levels/             #   Top-down mission levels (geometry + spawns + flags)
│   └── images/                 #   Painterly backgrounds, portraits, sprites
│
├── theme/
│   └── default_theme.tres      # Dark narrative UI theme (mobile-optimized)
│
├── locale/
│   ├── en.csv                  # English strings
│   └── pt_BR.csv               # Portuguese (Brazil) strings
│
├── addons/
│   └── story_validator/
│       └── StoryValidator.gd  # Editor tool — validates story.json for broken refs
│
└── docs/
    ├── STORY_AUTHORING_GUIDE.md  # Complete guide for writing story content
    ├── TOPDOWN_GAMEPLAY.md       # Mission format, controls, consequences, art direction
    └── ART_PIPELINE.md           # Art generation and asset workflow
```

## The Story Engine

The game is **data-driven**. All narrative content — chapters, checkpoints, dialogue, choices, consequences, endings — lives in [`assets/data/story.json`](assets/data/story.json). No code changes are needed to add or modify story content.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Checkpoint** | A single node in the story graph. Has a type (cutscene, choice, exploration, puzzle, mission, end). |
| **Choice** | A player decision at a `choice` checkpoint. Can have `requires` (conditions) and `effects` (flag changes). |
| **Flag** | A state variable tracked by `FlagsManager`. Gates choices and determines endings. |
| **Corruption** | A moral tracker. High corruption locks you out of heroic endings and enables selfish ones. |
| **Trust** | Per-character relationship score. High trust unlocks cooperative choices. |
| **Ending** | A terminal checkpoint (`type: "end"`) with a `end_type` (good, bad, neutral). |

### Story Flow

```
SplashScreen → MainMenu → GameScene
                                ↓
                    StoryManager loads checkpoint
                                ↓
                    ┌───────────┴───────────┐
                    │                       │
              cutscene/choice              mission
                    │                       │
              DialogueSystem          TopDownMission
              ChoiceUI                (top-down action)
                    │                       │
                    └───────────┬───────────┘
                                ↓
                        next checkpoint
                                ↓
                        ... until type: "end"
                                ↓
                        GameOverScreen
```

## Quick Start

### For Story Authors

1. Read [`docs/STORY_AUTHORING_GUIDE.md`](docs/STORY_AUTHORING_GUIDE.md) — it covers everything.
2. Open `assets/data/story.json` in any text editor.
3. Add/edit chapters, checkpoints, choices, and dialogue.
4. Run the **StoryValidator** in Godot's editor (Output panel) to check for broken references.

### For Developers

1. Open the `dead-hours/` folder in Godot 4.4.
2. All autoloads are registered in `project.godot`.
3. The main scene flow is: `SplashScreen → MainMenu → GameScene` (and `GameScene → TopDownMission` at mission checkpoints).
4. The `GameScene` loads checkpoints from `StoryManager` and instantiates the appropriate scene type.
5. If a referenced scene file doesn't exist yet, the game falls back to `GameScene` and runs dialogue + choices from the JSON directly — so you can test story flow before building scene files.

### Running the Game

```bash
# From Godot editor
# 1. Open dead-hours/project.godot
# 2. Press F5 (Play)
# 3. The splash screen loads → main menu → new game → story begins
```

### Exporting

Export presets are in `export_presets.cfg`:
- **Android Debug** — APK for testing
- **Android Release** — AAB for Play Store
- **iOS Debug** — for device testing
- **iOS Release** — for App Store

## Top-Down Missions

Three story beats are playable missions:

| Mission | Level | Beat |
|---------|-------|------|
| The Fire Escape | `ch1_fireescape` | Descend seven floors of the building |
| The Stairwell | `ch1_stairwell` | Alternate descent; the alarm sets `made_enemies` |
| Route 9 | `ch2_sneak` | Sneak into the gas station back office |

**Desktop:** WASD move · mouse aim · left click attack · Space dash · E interact · R restart
**Touch:** left stick move · right stick aim/fire · on-screen restart

One hit kills (both ways), guns alert the whole floor, kills raise `corruption_level`,
and every mission writes `_complete`, `_kills`, `_alerted` and `_time` flags before
returning to the story. Full reference: [`docs/TOPDOWN_GAMEPLAY.md`](docs/TOPDOWN_GAMEPLAY.md).

Existing painterly backgrounds are used as mission briefing/loading screens, so the
narrative art direction is preserved while the action layer runs in neon noir.

## Story Stats

| Metric | Count |
|--------|-------|
| Chapters | 3 |
| Total checkpoints | 51 |
| Choice points | 13 |
| Total choices | 40 |
| Endings | 7 |
| Flags tracked | 60+ |

## Endings

| ID | Type | How to Reach |
|----|------|-------------|
| `ending_hero` | Good | Hold the gate at Riverside (or fight the horde outside) |
| `ending_survivor` | Neutral | Evacuate Riverside through the north tunnel |
| `ending_martyr` | Good | Draw the horde away alone (requires low corruption) |
| `ending_drifter` | Bad | Steal a vehicle and leave (requires high corruption) |
| `ending_coward` | Bad | Sneak inside during the attack and hide |
| `ending_cure` | Good | Save Danny → his blood becomes the cure |
| `ending_silence` | Hidden | Survive but carry the guilt of those you left behind |

## Credits

- **Narrative Engine & Game Design:** Fabio Ritzel Borges
- **Built with:** Godot 4.4 + Base44 Superagent

## License

Proprietary — All rights reserved.
