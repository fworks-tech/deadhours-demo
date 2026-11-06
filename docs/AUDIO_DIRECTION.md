# Audio Direction & Design Document — 'Dead Hours'

## Executive Overview
**Dead Hours** is a narrative-driven mobile horror game. The audio design plays a vital role in establishing atmosphere, building psychological tension, communicating narrative urgency, and heightening player choices.

This document serves as the official audio direction guide for composers, sound designers, voice directors, and technical implementers.

---

## 1. Chapter Audio Profiles

### Chapter 1: The Outbreak Begins
- **Narrative Theme**: Confusion, sudden collapse of normalcy, claustrophobic survival.
- **Ambient Layer**: Heavy rainfall drumming against windowpanes and slick asphalt (`rain_loop.ogg`), distant rolling thunder (`thunder_clap.wav`), persistent water drips.
- **Music Theme**: Low, ominous string swells (violins and cellos playing minor second intervals) resting over a rhythmic 60 BPM heartbeat percussion pulse (`chapter1.ogg`).
- **Dynamic Behavior**: As tension rises during dialogue choices, the heartbeat percussion increases in volume and tempo, ducking low-frequency ambient rain.

### Chapter 2: Highway & Gas Station
- **Narrative Theme**: Isolation, desolate open space, lingering threat, environmental hostility.
- **Ambient Layer**: Cold howling wind whistling across open highways (`wind_loop.ogg`), buzzing high-pitch electrical flickering from gas station fluorescent signs (`gas_station_hum.ogg`), distant metal creaking.
- **Music Theme**: Cold sub-bass synth drone (45 Hz) coupled with sparse metallic percussion and resonant pads (`chapter2.ogg`).
- **Dynamic Behavior**: When entering the gas station interior, high-frequency wind fades out by 6 dB while the electrical transformer hum increases, intensifying claustrophobia.

### Chapter 3: Safehouse & Final Stand
- **Narrative Theme**: Climax, bittersweet reflection, moral weight of final choices, fragile hope amidst ruin.
- **Ambient Layer**: Muffled indoor silence, soft rain patter on the roof, dry wood creaks, faint distant zombie vocalizations.
- **Music Theme**: Somber solo cello carrying a mournful melody that occasionally resolves into major key hope motifs before dissolving into dissonance (`chapter3.ogg`).
- **Dynamic Behavior**: Choice selection triggers subtle cello harmonic holds, emphasizing the gravity of the decision.

---

## 2. Ending Stings

Each story ending culminates in a distinct 3–5 second audio sting to mark the emotional conclusion:

1. **Hero Ending (`sting_ending_hero.ogg`)**:
   - *Composition*: Soaring string ensemble in a warm C-major triad transition, resolving into an open acoustic resonance before fading into soft rain.
   - *Emotion*: Catharsis, sacrifice, closure.

2. **Coward Ending (`sting_ending_coward.ogg`)**:
   - *Composition*: Harsh, dissonant brass cluster with pitch bend downward, accompanied by an eerie metallic scraping tail.
   - *Emotion*: Guilt, hollow survival, paranoia.

3. **Silence / Tragic Ending (`sting_ending_silence.ogg`)**:
   - *Composition*: Complete, abrupt audio cutoff across all buses (0ms decay), followed by 2.0 seconds of absolute silence, then a faint, staticky analog radio hiss fading to zero.
   - *Emotion*: Shock, void, sudden termination.

---

## 3. Comprehensive Sound Effects (SFX) Palette

Sound effects are categorized into five core categories and pooled via `AudioManager`:

### Door Knocks & Impacts
- `door_knock_soft.wav`: 3 light wooden taps. Used for cautious friendly contact.
- `door_knock_heavy.wav`: Rapid heavy fist pounding. Used during escape sequences.
- `door_knock_panicked.wav`: Violent flesh-and-wood thuds. Used when infected hit barriers.

### Zombie Vocalizations
- `zombie_groan_distant.wav`: Reverb-drenched guttural groan. Signals ambient threat.
- `zombie_groan_close.wav`: Wet raspy breath and throat rattle. Used in immediate danger.
- `zombie_screech.wav`: High-pitched screech/gurgle. Used for jump scares and attacks.

### Firearms & Weapons
- `gunshot_pistol.wav`: Sharp 9mm gun discharge with crisp mechanical top end.
- `gunshot_shotgun.wav`: Deep 12-gauge blast with heavy low-end impact.
- `gunshot_echo.wav`: Reverberating tail for outdoor or long corridor shooting.

### Environmental & Weather
- `thunder_clap.wav`: Sudden thunder crack with lingering low-frequency rumble.
- `rain_drip.wav`: Single water droplet hitting metal or wet ground.

### Footsteps & Surface Dynamics
- `footstep_concrete.wav`: Firm boot heel strike on hard wet pavement.
- `footstep_mud.wav`: Soft wet squelch on mud/grass.
- `footstep_wood.wav`: Creaking floorboard step for interior movement.

### User Interface (UI) Clicks
- `ui_click.wav`: Subtle retro tactile click.
- `ui_hover.wav`: Soft high-frequency tick when navigating buttons.
- `ui_confirm.wav`: Solid wood/metal latch engagement sound.
- `ui_back.wav`: Soft reverse muffled click.
- `choice_select.wav`: Dramatic low-frequency bass swell when confirming a narrative branch.

---

## 4. Voice Acting Strategy for Indie Solo Developer

When developing a narrative horror title with a small team or as a solo developer, voice acting strategy requires balancing budget, production timeline, quality, and immersion.

### Comparison Matrix

| Approach | Pros | Cons | Recommendation |
| :--- | :--- | :--- | :--- |
| **Full Human Voice Acting** | High emotional range, authenticity, maximum player immersion | High cost ($100-$300/hr), complex direction/retakes, scheduling delays | Recommended for key characters if budget permits |
| **AI Text-to-Speech (TTS)** (e.g. ElevenLabs) | Fast iteration, low cost, consistent availability, easy localization | Potential loss of organic nuance, licensing considerations | Recommended for rapid prototyping & placeholder lines |
| **Semi-Voiced / Hybrid** (Key lines + SFX grunts) | Excellent balance of budget, polish, and narrative weight | Requires careful editing at line transitions | **RECOMMENDED FOR 'DEAD HOURS'** |

### Recommended Approach for 'Dead Hours'
1. **Production / Alpha Phase**: Use AI TTS (ElevenLabs / Coqui) generated from dialogue strings to prototype timing, text speed synchronization, and subtitle placement.
2. **Release / Polish Phase**:
   - Utilize human voice actors (or premium AI voice models with custom voice clones) for **pivotal narrative moments** (e.g., Chapter openings, climax choices, and ending monologue lines).
   - Use audio grunts, gasps, breaths, and short vocal stings (`scared_gasp.wav`, `sigh.wav`) for ambient text-box dialogues.

---

## 5. Audio Bus Layout & Technical Routing

`Dead Hours` uses a 5-bus hierarchy in Godot 4.x (`default_bus_layout.tres`). All audio nodes route into designated sub-buses, allowing global volume mixing, dynamic ducking, and master limiters.

### Bus Architecture Diagram

```
                             [ AUDIO SOURCES ]
                                     │
      ┌──────────────────┬───────────┼───────────┬──────────────────┐
      │                  │           │           │                  │
┌───────────┐      ┌───────────┐ ┌───────────┐ ┌───────────┐  ┌───────────┐
│ Chapter   │      │ Ambient   │ │ Voice     │ │ SFX Pool  │  │ UI SFX    │
│ Music     │      │ Loops     │ │ Lines     │ │ (Combat/  │  │ Clicks    │
│ Tracks    │      │ (Rain,    │ │ (Dialogue)│ │ Doors)    │  │           │
│           │      │  Wind)    │ │           │ │           │  │           │
└─────┬─────┘      └─────┬─────┘ └─────┬─────┘ └─────┬─────┘  └─────┬─────┘
      │                  │             │             │              │
      ▼                  ▼             ▼             ▼              ▼
┌───────────┐      ┌───────────┐ ┌───────────┐ ┌────────────────────────┐
│ Music Bus │      │Ambient Bus│ │ Voice Bus │ │        SFX Bus         │
│ (-2.0 dB) │      │ (-4.0 dB) │ │ (+1.5 dB) │ │       (0.0 dB)         │
└─────┬─────┘      └─────┬─────┘ └─────┬─────┘ └────────────┬───────────┘
      │                  │             │                    │
      └──────────────────┼─────────────┴────────────────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │  Master Bus   │
                 │   (0.0 dB)    │
                 └───────┬───────┘
                         │
                         ▼
                 [ AUDIO OUTPUT ]
```

### Bus Specifications & Processing

1. **Master Bus**:
   - Peak Target: -1.0 dB
   - Effect: AudioLimiter (prevents clipping during intense multi-SFX scenes).

2. **Music Bus**:
   - Default Gain: -2.0 dB
   - Routing: Master Bus
   - Features: Crossfade support managed by `AudioManager` (2-second fade duration).

3. **Ambient Bus**:
   - Default Gain: -4.0 dB
   - Routing: Master Bus
   - Features: Multi-track concurrent playing (e.g. `rain` + `wind` simultaneously).

4. **Voice Bus**:
   - Default Gain: +1.5 dB
   - Routing: Master Bus
   - Features: High-pass filter at 100 Hz to remove low-frequency rumble; triggers `subtitle_synced` signal.

5. **SFX Bus**:
   - Default Gain: 0.0 dB
   - Routing: Master Bus
   - Features: 8-player AudioStreamPlayer pool with pitch-variance randomization (+/- 0.05).
