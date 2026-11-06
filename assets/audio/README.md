# Audio Assets Directory — Dead Hours

This directory contains all sound effects, music tracks, ambient loops, and voice lines for **Dead Hours**.

---

## Directory Structure

```
assets/audio/
├── music/               # Chapter soundtracks & ending stings
├── ambient/             # Loopable environmental audio
├── voice/               # Voice lines organized by chapter
│   ├── ch1/             # Chapter 1 voice clips
│   ├── ch2/             # Chapter 2 voice clips
│   └── ch3/             # Chapter 3 voice clips
├── sfx/                 # Sound effects (UI, combat, environment)
└── README.md            # Audio asset specification and manifest
```

---

## Recommended Audio Specifications

- **Music & Ambient Loops**: OGG Vorbis (`.ogg`), 44.1 kHz / 16-bit, stereo, seamlessly looped (`loop = true` in import settings).
- **Voice Lines**: OGG Vorbis (`.ogg`), 44.1 kHz, mono/stereo, normalized to -16 LUFS.
- **Sound Effects (SFX)**: WAV (`.wav`) or OGG (`.ogg`), 44.1 kHz / 16-bit, mono for positional sound, normalized to -12 LUFS.

---

## Audio Manifest & Requirements

### 1. Music Tracks (`assets/audio/music/`)

| Filename | Purpose | Mood / Tempo | Suggested Source / Prompt |
| :--- | :--- | :--- | :--- |
| `chapter1.ogg` | Chapter 1 Main Theme (The Outbreak) | Tense strings, 60 BPM heartbeat percussion, atmospheric dread | Custom composition / Soniss GDC / Freesound |
| `chapter2.ogg` | Chapter 2 Main Theme (Highway & Gas Station) | Cold synth drone, minimalist metallic synth, industrial tension | Cyberpunk/Dark Ambient asset packs |
| `chapter3.ogg` | Chapter 3 Main Theme (Safehouse / Final Stand) | Melancholic solo cello, fragile piano, emotional dread | Orchestral horror music pack |
| `sting_ending_hero.ogg` | Heroic Ending Sting | Hopeful string crescendo, resolving harmonic major chord | Orchestral cinematic stings |
| `sting_ending_coward.ogg` | Coward Ending Sting | Dissonant brass cluster, descending metallic slide, pitch bend | Dark horror sting pack |
| `sting_ending_silence.ogg` | Silence Ending Sting | Instant mute, 2s absolute silence, trailing faint analog static | Synthesized white noise & radio burst |

---

### 2. Ambient Loops (`assets/audio/ambient/`)

| Filename | Purpose | Mood / Characteristics | Suggested Source |
| :--- | :--- | :--- | :--- |
| `rain_loop.ogg` | Outdoor & window rain | Heavy steady rainfall, asphalt splatters, roof drips | Freesound.org / Boom Library Rain |
| `wind_loop.ogg` | Outdoor wind | Cold howling wind through alleyways and deserted streets | OpenGameArt / BBC Sound Effects |
| `cold_drone_loop.ogg` | Tension booster | Low-frequency sub-drone (40-60 Hz), eerie atmospheric resonance | Synthesized Serum/Vital sub-drone |
| `gas_station_hum.ogg` | Gas station interior/exterior | Fluorescent tube buzz, flickering generator electrical hum | Industrial ambient recording |
| `industrial_hum.ogg` | Warehouse / mechanical | Deep engine rumble, ventilation air displacement | Soniss GDC Free Pack |

---

### 3. Voice Lines (`assets/audio/voice/`)

#### Chapter 1 (`voice/ch1/`)
- `ch1_elena_01.ogg` — *"They're coming!"* (Frantic, whispered panic)
- `ch1_marcus_01.ogg` — *"Keep your voice down... they hear everything."* (Gravelly, cautious)
- `ch1_radio_01.ogg` — *"Emergency alert: Seek immediate shelter..."* (Distorted broadcast, high-pass filter)

#### Chapter 2 (`voice/ch2/`)
- `ch2_scavenger_01.ogg` — *"Step back! I'm not afraid to pull this trigger!"* (Desperate, aggressive)
- `ch2_marcus_02.ogg` — *"The pumps are dry. We need another way."* (Exhausted, determined)

#### Chapter 3 (`voice/ch3/`)
- `ch3_elena_02.ogg` — *"If we don't cross now, we never will."* (Resigned, emotional)
- `ch3_radio_02.ogg` — *"Final evacuation helicopter departing in five minutes..."* (Staticky, faint)

---

### 4. Sound Effects (`assets/audio/sfx/`)

#### Door Knocks & Impacts
- `door_knock_soft.wav` — Gentle wood tap (3-4 raps)
- `door_knock_heavy.wav` — Frantic heavy fist pounding on oak door
- `door_knock_panicked.wav` — Violent flesh-and-wood bang (zombie or fleeing survivor)

#### Zombie Sounds
- `zombie_groan_distant.wav` — Low guttural vocalization, reverb tail
- `zombie_groan_close.wav` — Wet raspy breathing, throat rattle
- `zombie_screech.wav` — Sudden high-pitched aggressive screech (jump scare)

#### Firearm & Combat SFX
- `gunshot_pistol.wav` — Sharp 9mm discharge, quick mechanical slide return
- `gunshot_shotgun.wav` — Heavy 12-gauge blast with deep sub-bass thump
- `gunshot_echo.wav` — Reverb tail for outdoor/corridor shooting

#### Weather & Environment
- `thunder_clap.wav` — Loud sudden thunder crack followed by rolling rumble
- `rain_drip.wav` — Single water drop impacting puddle or metal sill

#### Footsteps
- `footstep_concrete.wav` — Hard boot heel impact on wet pavement
- `footstep_mud.wav` — Soft wet squelch on soaked earth
- `footstep_wood.wav` — Creaking floorboard boot step

#### User Interface (UI)
- `ui_click.wav` — Soft tactile mechanical click
- `ui_hover.wav` — Very subtle high-frequency tick on option focus
- `ui_confirm.wav` — Satisfying wood/metal latch sound for menu selection
- `ui_back.wav` — Muffled reverse tick for back/cancel
- `choice_select.wav` — Low subtle brass swell / dramatic pulse when confirming narrative choice

---

## Suggested Sources for Asset Acquisition

1. **Free / Open Source**:
   - [Freesound.org](https://freesound.org/) (CC0 / CC-BY samples for SFX and Foley)
   - [Soniss GDC Audio Archives](https://soniss.com/gdcarchive) (Thousands of royalty-free commercial sound effects)
   - [OpenGameArt.org](https://opengameart.org/) (Community ambient audio and music)

2. **AI Voice Generation** (For prototyping or indie release):
   - [ElevenLabs](https://elevenlabs.io/) (High expressiveness horror & tense character voices)
   - [Coqui TTS / Piper](https://github.com/coqui-ai/TTS) (Local open-source TTS voice synthesis)

3. **In-Engine Asset Creation**:
   - Godot AudioStreamGenerator for procedural tone and static generation.
