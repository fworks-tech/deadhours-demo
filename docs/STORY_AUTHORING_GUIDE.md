# Story Authoring Guide

Welcome to the **Narrative Authoring Guide**. This comprehensive documentation explains how to design, write, structure, validate, and publish interactive narrative content for the game using Godot 4.x.

---

## Table of Contents

1. [Overview & Architecture](#1-overview--architecture)
2. [The `story.json` Format](#2-the-storyjson-format)
3. [Checkpoint Types & Use Cases](#3-checkpoint-types--use-cases)
4. [Dialogue Format](#4-dialogue-format)
5. [Cutscene Timeline Format](#5-cutscene-timeline-format)
6. [The Flag System & State Management](#6-the-flag-system--state-management)
7. [Choices & Decision Points](#7-choices--decision-points)
8. [Conditional Choices & Requirements](#8-conditional-choices--requirements)
9. [Branching Paths & Forward Consequences](#9-branching-paths--forward-consequences)
10. [Endings & Epilogues](#10-endings--epilogues)
11. [Complete Example Checkpoint](#11-complete-example-checkpoint)
12. [Using the Story Validator Tool](#12-using-the-story-validator-tool)
13. [Step-by-Step Tutorials](#13-step-by-step-tutorials)
    - [Step-by-Step: Adding a New Chapter](#step-by-step-adding-a-new-chapter)
    - [Step-by-Step: Adding a New Choice with Consequences](#step-by-step-adding-a-new-choice-with-consequences)
    - [Step-by-Step: Creating a New Ending](#step-by-step-creating-a-new-ending)
14. [Narrative Design Best Practices](#14-narrative-design-best-practices)
15. [Scenes, Endings & Localization (Engine Behavior)](#15-scenes-endings--localization-engine-behavior)

---

## 1. Overview & Architecture

*BranchingPaths* uses a data-driven narrative engine driven by `assets/data/story.json`.

```
                  ┌──────────────────────┐
                  │  assets/data/        │
                  │  story.json          │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │    StoryManager      │
                  └─────┬──────────┬─────┘
                        │          │
         ┌──────────────┘          └──────────────┐
         ▼                                        ▼
┌──────────────────┐                     ┌──────────────────┐
│   FlagsManager   │                     │  ChoiceManager   │
└──────────────────┘                     └──────────────────┘
```

- **`StoryManager`** (`res://autoload/StoryManager.gd`): Drives narrative flow, loads JSON, and tracks current checkpoint position.
- **`FlagsManager`** (`res://autoload/FlagsManager.gd`): Manages game state, variables, character trust levels, and inventory items.
- **`ChoiceManager`** (`res://autoload/ChoiceManager.gd`): Handles choice evaluation, presentation, and player decision selection.
- **`StoryValidator`** (`res://addons/story_validator/StoryValidator.gd`): Validates JSON syntax, missing links, and orphan nodes in the editor.
- **`StoryTools`** (`res://scripts/utils/StoryTools.gd`): Provides static graph analytics, path counting, and debug visualization exports.

---

## 2. The `story.json` Format

The master story database is stored at `res://assets/data/story.json`. It is structured as follows:

```json
{
  "game_title": "BranchingPaths",
  "version": "1.0",
  "total_endings": 6,
  "chapters": {
    "1": {
      "id": "ch1",
      "title": "Chapter 1: The Arrival",
      "summary": "You arrive at the old estate in the fog.",
      "checkpoints": {
        "ch1_start": { ... },
        "ch1_choice1": { ... }
      }
    }
  }
}
```

### Key Root Fields

| Field | Type | Description |
|-------|------|-------------|
| `game_title` | `string` | Display title of the project. |
| `version` | `string` | Story schema or content release version. |
| `total_endings` | `integer` | Total number of achievable game conclusions across all chapters. |
| `chapters` | `object` | Dictionary mapping chapter numeric keys (`"1"`, `"2"`) to chapter objects. |

---

## 3. Checkpoint Types & Use Cases

Checkpoints are narrative nodes that define what the player sees and experiences at each step.

| Type | Purpose | Behavior |
|------|---------|----------|
| **`cutscene`** | Scripted sequences | Plays dialogue and camera moves; automatically advances via `next` when completed. |
| **`choice`** | Player decision points | Displays interactive buttons; player choice determines next checkpoint and triggers flag effects. |
| **`exploration`** | Interactive environments | Switches to gameplay state; player can inspect objects or trigger triggers before advancing. |
| **`puzzle`** | Minigames & challenges | Switches to gameplay state; requires player to solve a challenge to unlock the `next` checkpoint. |
| **`end`** | Game conclusion | Displays epilogue screen and unlocks ending achievement in save data. |

---

## 4. Dialogue Format

Dialogue arrays consist of individual line dictionaries:

```json
"dialogue": [
  {
    "speaker": "alice",
    "emotion": "worried",
    "text": "I don't think we should open that door...",
    "voice": "res://assets/audio/voice/ch1_alice_01.wav"
  },
  {
    "speaker": "narrator",
    "emotion": "neutral",
    "text": "The wind howls through the broken windows."
  }
]
```

### Dialogue Fields

- **`speaker`**: Character key identifier (`"alice"`, `"bob"`, `"narrator"`, `"player"`).
- **`emotion`**: Portrait emotion key (`"neutral"`, `"curious"`, `"worried"`, `"angry"`, `"cold"`, `"relieved"`).
- **`text`**: Spoken string (supports localization string lookup).
- **`voice`**: *(Optional)* Path to audio file (`res://assets/audio/voice/...`).

---

## 5. Cutscene Timeline Format

For animated cutscenes driven by `CutscenePlayer.gd`, timeline shots control camera and character node animations:

```json
"timeline": [
  {
    "camera": {
      "position": [100, 200],
      "zoom": [1.5, 1.5],
      "duration": 1.2
    },
    "characters": [
      {
        "node": "Alice",
        "position": [200, 300],
        "animation": "look_around",
        "visible": true
      }
    ],
    "dialogue": [
      {
        "speaker": "alice",
        "emotion": "surprised",
        "text": "Did you hear that?"
      }
    ],
    "wait": 0.5,
    "fade": {
      "color": "black",
      "duration": 0.8
    }
  }
]
```

---

## 6. The Flag System & State Management

Game state is tracked via **flags** in `FlagsManager`. Flags can be `boolean`, `integer`, or `string`.

Flag operations can be applied on entering a checkpoint (`on_enter`) or upon selecting a choice (`effects`):

```json
"on_enter": [
  { "set": { "met_alice": true, "trust_alice": 5 } },
  { "add": { "secrets_discovered": 1 } },
  { "sub": { "corruption_level": 1 } },
  { "toggle": [ "has_flashlight" ] },
  { "clear": [ "temporary_flag" ] }
]
```

### Supported Flag Operations

| Operation | Format | Example | Description |
|-----------|--------|---------|-------------|
| **`set`** | `{ "set": { "flag": value } }` | `{ "set": { "met_alice": true } }` | Sets flag to exact value. |
| **`add`** | `{ "add": { "flag": amount } }` | `{ "add": { "trust_alice": 1 } }` | Increments integer flag. |
| **`sub`** | `{ "sub": { "flag": amount } }` | `{ "sub": { "trust_alice": 1 } }` | Decrements integer flag. |
| **`toggle`** | `{ "toggle": [ "flag" ] }` | `{ "toggle": ["has_flashlight"] }` | Inverts boolean flag value. |
| **`clear`** | `{ "clear": [ "flag" ] }` | `{ "clear": ["temp_state"] }` | Resets flag to default value. |

---

## 7. Choices & Decision Points

Choice checkpoints present interactive touch targets:

```json
"ch1_choice1": {
  "id": "ch1_choice1",
  "chapter": 1,
  "scene": "res://scenes/cutscenes/Ch1Door.tscn",
  "type": "choice",
  "speaker": "player",
  "dialogue": [
    {
      "speaker": "alice",
      "emotion": "curious",
      "text": "You came. I wasn't sure you would."
    }
  ],
  "choices": [
    {
      "id": "ch1_c1_enter",
      "text": "Enter the estate with Alice",
      "character": "player",
      "effects": [
        { "set": { "met_alice": true } },
        { "add": { "trust_alice": 1 } }
      ],
      "next": "ch1_inside"
    },
    {
      "id": "ch1_c1_refuse",
      "text": "Refuse and demand answers first",
      "character": "player",
      "effects": [
        { "set": { "met_alice": true } },
        { "sub": { "trust_alice": 1 } }
      ],
      "next": "ch1_refuse"
    }
  ]
}
```

---

## 8. Conditional Choices & Requirements

Choices can be gated using the `requires` field. If requirements are not met, the choice is hidden from the player.

### Standard Equality Requirements
```json
"requires": {
  "has_key": true,
  "met_alice": true
}
```

### Operator Comparison Requirements
You can use key-operator objects: `==`, `!=`, `>`, `<`, `>=`, `<=`, `in`.

```json
"requires": {
  "trust_alice": { ">=": 2 },
  "corruption_level": { "<": 5 },
  "player_role": { "==": "detective" }
}
```

---

## 9. Branching Paths & Forward Consequences

Early choices set flags that ripple forward into subsequent chapters:

```
               [ch1_choice1]
              /      |      \
             /       |       \
     [enter]      [refuse]    [silent]
     trust+1      trust-1     trust+1
        │            │           │
        └────────────┼───────────┘
                     ▼
               [ch1_choice2]
              /             \
      Requires: enter      Requires: refuse
             │                      │
             ▼                      ▼
     [Inside Estate]        [Outside Window]
```

### Example Forward Gate in Chapter 2
```json
{
  "id": "ch2_confrontation",
  "choices": [
    {
      "id": "ch2_ask_alice_help",
      "text": "Ask Alice to help you open the vault",
      "requires": {
        "met_alice": true,
        "trust_alice": { ">=": 2 }
      },
      "next": "ch2_vault_coop"
    },
    {
      "id": "ch2_force_vault",
      "text": "Use the crowbar to break into the vault",
      "requires": {
        "has_crowbar": true
      },
      "next": "ch2_vault_forced"
    }
  ]
}
```

---

## 10. Endings & Epilogues

Endings are defined with `type: "end"` and a required `end_type` property (`"good"`, `"bad"`, `"neutral"`, `"secret"`):

```json
"ch2_end_good": {
  "id": "ch2_end_good",
  "chapter": 2,
  "scene": "res://scenes/cutscenes/Ch2EndingGood.tscn",
  "type": "end",
  "end_type": "good",
  "dialogue": [
    {
      "speaker": "narrator",
      "emotion": "relieved",
      "text": "With Alice by your side, you escaped the estate before nightfall."
    }
  ],
  "on_enter": [
    { "set": { "ending_good_unlocked": true } }
  ]
}
```

---

## 11. Complete Example Checkpoint

Here is a fully loaded checkpoint demonstrating all available fields:

```json
"ch1_master_example": {
  "id": "ch1_master_example",
  "chapter": 1,
  "scene": "res://scenes/cutscenes/Ch1MasterScene.tscn",
  "type": "choice",
  "speaker": "player",
  "dialogue": [
    {
      "speaker": "alice",
      "emotion": "worried",
      "text": "The lock is jammed! What should we do?",
      "voice": "res://assets/audio/voice/ch1_alice_jammed.wav"
    }
  ],
  "on_enter": [
    { "set": { "reached_master_door": true } },
    { "add": { "secrets_discovered": 1 } }
  ],
  "choices": [
    {
      "id": "c_use_key",
      "text": "Use the iron key",
      "character": "player",
      "requires": {
        "has_key": true
      },
      "effects": [
        { "set": { "unlocked_main_door": true } },
        { "add": { "trust_alice": 1 } }
      ],
      "next": "ch1_inside"
    },
    {
      "id": "c_kick_door",
      "text": "Kick the door open",
      "character": "player",
      "requires": {
        "corruption_level": { "<": 3 }
      },
      "effects": [
        { "add": { "corruption_level": 1 } },
        { "sub": { "trust_alice": 1 } }
      ],
      "next": "ch1_refuse"
    }
  ],
  "next": "ch1_inside"
}
```

---

## 12. Using the Story Validator Tool

To validate `story.json` inside the Godot Editor:

1. Open **Godot Engine**.
2. Go to the **Script Editor** panel.
3. Open `addons/story_validator/StoryValidator.gd`.
4. Click **File -> Run** (or press `Ctrl + Shift + X`).
5. Check the **Output Panel** at the bottom of Godot.

### What StoryValidator Checks
- ✖ Duplicate checkpoint IDs
- ✖ Missing `next` references (checkpoints pointing to non-existent IDs)
- ✖ Missing scene `.tscn` files on disk
- ✖ Endings missing `end_type`
- ✖ Choices with missing or blank `next` targets
- ⚠️ Orphan checkpoints (checkpoints unreachable from story entry points)

---

## 13. Step-by-Step Tutorials

### Step-by-Step: Adding a New Chapter

1. Open `assets/data/story.json`.
2. Locate the `"chapters"` object.
3. Add a new numeric key for your chapter (e.g., `"3"`):

```json
"3": {
  "id": "ch3",
  "title": "Chapter 3: The Revelation",
  "summary": "You enter the inner sanctuary.",
  "checkpoints": {
    "ch3_start": {
      "id": "ch3_start",
      "chapter": 3,
      "scene": "res://scenes/cutscenes/Ch3Intro.tscn",
      "type": "cutscene",
      "dialogue": [
        {
          "speaker": "narrator",
          "emotion": "neutral",
          "text": "The heavy iron doors creak open."
        }
      ],
      "next": "ch3_choice1"
    }
  }
}
```
4. Connect the previous chapter's final checkpoint `next` field to `"ch3_start"`.
5. Run **StoryValidator** to confirm the link is valid.

---

### Step-by-Step: Adding a New Choice with Consequences

1. Open `assets/data/story.json` at your desired checkpoint.
2. Ensure checkpoint `type` is `"choice"`.
3. Append a new object to the `"choices"` array:

```json
{
  "id": "ch1_c2_secret_door",
  "text": "Examine the secret bookshelf lever",
  "requires": {
    "has_flashlight": true,
    "secrets_discovered": { ">=": 1 }
  },
  "effects": [
    { "set": { "found_secret_room": true } },
    { "add": { "trust_alice": 2 } }
  ],
  "next": "ch1_secret_room"
}
```
4. Define the target checkpoint `"ch1_secret_room"` in `checkpoints`.
5. Run **StoryValidator** to verify.

---

### Step-by-Step: Creating a New Ending

1. Decide on the ending condition and requirements.
2. Create a new checkpoint entry with `"type": "end"`:

```json
"ch2_end_secret": {
  "id": "ch2_end_secret",
  "chapter": 2,
  "scene": "res://scenes/cutscenes/Ch2SecretEnding.tscn",
  "type": "end",
  "end_type": "secret",
  "dialogue": [
    {
      "speaker": "narrator",
      "emotion": "neutral",
      "text": "You uncovered the hidden truth that lay buried for centuries."
    }
  ],
  "on_enter": [
    { "set": { "found_truth": true } }
  ]
}
```
3. Link a prior choice or checkpoint to `"ch2_end_secret"`.
4. Update `total_endings` count in root `story.json`.
5. Run **StoryValidator** to confirm no missing references.

---

## 14. Narrative Design Best Practices

1. **Avoid Illusion of Choice**: Always give choices meaningful flag consequences (`trust`, items, path branches).
2. **Keep Checkpoint IDs Standardized**: Use `ch{num}_{description}` naming convention (e.g. `ch1_start`, `ch1_choice1`, `ch1_door_left`).
3. **Always Run StoryValidator**: Validate before committing changes to avoid runtime broken links during playtests.
4. **Name Flags Consistently**: Group flags by domain (e.g. `met_*`, `trust_*`, `has_*`, `ending_*`).
5. **Provide Alternate Paths**: Avoid soft-locking player progress when gating choices by providing a fallback option.

---

## 15. Scenes, Endings & Localization (Engine Behavior)

How the engine consumes what you write — read this before wiring scenes or
writing endings.

### 15.1 The `scene` field (scene-aware checkpoints)

A checkpoint MAY declare which scene file hosts it:

```json
"ch2_rooftop": {
  "id": "ch2_rooftop",
  "type": "cutscene",
  "scene": "res://scenes/chapters/ch2_rooftop.tscn",
  "dialogue": [ ... ]
}
```

- **With a `scene` field** that differs from the current scene: the engine
  transitions to it automatically on checkpoint entry. The scene's
  `CutsceneTemplate` reads `StoryManager.current_checkpoint` on `_ready` and
  plays the checkpoint's dialogue — you never call the dialogue system
  yourself.
- **Without a `scene` field**: the checkpoint plays in the current scene
  (dialogue replays via `checkpoint_entered`). Use this for chains of beats
  that share one stage.
- Chapter scene files are plain cutscene stages: `Camera2D` + `Background`
  sprite + invisible `Alice`/`Bob`/`Player` sprites (CutsceneTemplate's
  contract — rename the sprites' textures, keep the node names) + a
  `DialogueSystem` instance.

### 15.2 Choices render anywhere

Choices are presented by `ChoiceManager`, which owns a root-level `ChoiceUI`
overlay. No scene needs to instance ChoiceUI — a `choice` checkpoint entered
from ANY scene shows the overlay on top. Choice buttons are styled by the
project theme, so they match each game's palette automatically.

### 15.3 Endings are data-driven

When the player reaches an `"type": "end"` checkpoint, the engine:

1. Unlocks the ending and saves,
2. Records `end_type` plus optional `ending_title` and `narration` from the
   checkpoint,
3. Transitions to `GameOverScreen`, which displays YOUR title and narration
   when provided, falling back to the built-in good/bad/neutral text.

```json
"ending_hero": {
  "id": "ending_hero",
  "type": "end",
  "end_type": "good",
  "ending_title": "The Long Dawn",
  "narration": "Elena watches the sun rise over a city that finally sleeps."
}
```

### 15.4 Localization workflow

All player-facing strings go through `tr()` with the English string as the
key. After writing or editing story data, sync the locale CSVs:

```bash
python3 tools/extract_strings.py --write
```

The tool merges new strings into `locale/en.csv` + `locale/pt_BR.csv`
without losing existing translations. Fill the empty `pt_BR` cells; Godot
falls back to English until you do.

---

## 16. The Author CLI (preferred workflow)

Hand-editing `story.json` works, but the author CLI is the supported path:

```bash
python3 tools/author_cli.py init .        # one-time: import existing data -> story_source.jsonc
# ... write your story in story_source.jsonc (// comments allowed) ...
python3 tools/author_cli.py validate .    # graph, flags, portraits, balance
python3 tools/author_cli.py compile .     # -> assets/data/*.json + locale sync
python3 tools/author_cli.py stats .       # words/branches/endings/flags
python3 tools/author_cli.py diagram .     # Mermaid flow chart
```

**Shorthand:** dialogue entries may be plain strings — `"Elena: Three knocks."`
becomes `{"speaker": "Elena", "text": "Three knocks."}`; a bare string is
narration. Checkpoint `id`/`chapter` fields are filled in at compile.

**Safety:** compile records hashes of the compiled files. If you hand-edit
`assets/data/story.json` afterwards, compile refuses until you move those
edits into the source (or accept `--force`). `init` also refuses to
overwrite an existing source file.

Everything a source file can contain is documented in the engine sections
above — the CLI just gives you comments, shorthand, and guardrails on top.
