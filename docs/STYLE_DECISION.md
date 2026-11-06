# Art Style Decision Document: Dead Hours vs. Visitor

**Author:** Fabio (Solo Indie Developer)  
**Date:** August 9, 2026  
**Status:** Approved Recommendation  
**Projects Affected:** *Dead Hours* (`dead-hours/`) and *Dead Hours: Visitor* (`visitor/`)

---

## 1. Executive Summary

This document evaluates the visual identity strategy for *Dead Hours* (a mobile narrative-choice horror game) in relation to *Dead Hours: Visitor* (a planned inspection/simulation horror game inspired by *No, I'm not a Human* and *Mandela Catalogue*).

The core decision is whether to:
1. **Maintain *Dead Hours* in its current painterly dark horror style**, OR
2. **Pivot *Dead Hours* to the analog horror / uncanny valley style** planned for *Visitor*.

### Final Recommendation
**Keep *Dead Hours* in the painterly dark horror style, and reserve the analog horror / uncanny valley style exclusively for *Visitor*.**

The two titles serve distinct gameplay mechanisms and narrative purposes. Distinct visual styles optimize each game's player experience while preserving existing art investment and creating a clear brand differentiation across the franchise.

---

## 2. Option Analysis

### Option A: Keep *Dead Hours* Painterly (Recommended)

#### Overview
*Dead Hours* uses a dark, desaturated, painterly aesthetic with high-contrast dramatic lighting (inspired by *Until Dawn* concept art and *The Last of Us* key art). Portraits feature 1:1 bust shots with visible brush textures, while backgrounds feature 16:9 wide atmospheric environments with heavy fog and rain.

#### Pros
1. **Preserves Existing Assets:** *Dead Hours* already has 13 fully generated and integrated assets (5 character portrait baselines for Elena, Danny, Garcia, Priya, Dr. Chen, plus 8 chapter background scenes: `ch1_bedroom`, `ch1_hallway_peephole`, `ch1_fire_escape`, `ch1_stairwell`, `ch1_garage`, `ch2_gas_station`, `ch3_riverside`, `route9_highway`). Pivoting would waste this production effort.
2. **Matches Narrative & Cinematic Gameplay:** *Dead Hours* relies on emotional character dialogue, relationship building, choices, and atmospheric cutscenes. High-contrast painterly art enhances emotional resonance, character expressiveness, and dramatic storytelling.
3. **Product Differentiation:** Differentiates *Dead Hours* from *Visitor* in store listings, preventing the games from looking like redundant assets or asset flips of one another.
4. **Production Speed:** AI image generation prompts (`ART_PIPELINE.md`) and mappings (`portraits.json`, `BackgroundManager.gd`) are already established and tuned for this style.

#### Cons
1. **Lack of Visual Brand Uniformity:** The two games in the same universe will have distinct artistic styles rather than a unified visual system.
2. **Standard Zombie Aesthetic:** Painterly dark horror is a recognized aesthetic in zombie narrative games, making it less unconventional than raw analog horror.

---

### Option B: Pivot *Dead Hours* to Analog Horror / Uncanny Valley Style

#### Overview
Adopting the style of *No, I'm not a Human* (Trioskaz) and *The Mandela Catalogue*: hand-drawn/rasterized static character portraits staring directly at the camera, green monochrome CRT UI, VHS tracking distortion, and subtle facial anomalies ("something wrong with this face").

#### Pros
1. **Franchise Visual Consistency:** Both *Dead Hours* and *Visitor* would share a signature, recognizable analog horror identity across the portfolio.
2. **Unconventional Zombie Take:** Frame the zombie threat around paranoia, uncanny transformation, and psychological terror rather than standard apocalypse survival art.

#### Cons
1. **Total Asset Scrappage:** Requires throwing away all 13 existing painterly assets and regenerating/re-tuning every portrait and background asset, creating unnecessary technical and schedule debt.
2. **Ludonarrative Mismatch:** Analog horror / uncanny valley faces work best when the core mechanic is **prolonged facial inspection** (staring at static, unblinking features to detect subtle flaws). In a multi-choice narrative game like *Dead Hours*, where scenes switch quickly between cutscenes, dialogue overlays, and exploration maps, static unblinking uncanny faces lose their impact and feel jarring during emotional dialogues.
3. **Reduced Character Empathy:** The uncanny valley effect makes characters feel unnatural and repulsive. In *Dead Hours*, the player needs to empathize with companions like Danny, Elena, or Priya during high-stakes choices. Making them uncanny damages player emotional connection.

---

## 3. Comparison & Decision Matrix

| Evaluation Criteria | Painterly Dark Horror (*Dead Hours*) | Analog Horror / Uncanny (*Visitor*) |
| :--- | :--- | :--- |
| **Primary Gameplay Mechanics** | Branching dialogue, moral choices, cutscenes | Face inspection, sign analysis, door decisions |
| **Player Emotion Target** | Empathy, dread, narrative investment | Paranoia, suspicion, clinical tension |
| **Character Interaction** | Conversational, emotional, relational | Observational, investigative, transactional |
| **Existing Asset Investment** | 13 assets ready & wired in Godot | 0 assets (concept phase) |
| **Best UI Integration** | Dark narrative theme (`default_theme.tres`) | Sickly green monochrome CRT terminal |
| **Ideal Mechanics Fit** | **Dead Hours** | **Visitor** |

---

## 4. Final Recommendation & Implementation Strategy

### Decision Strategy
1. **Dead Hours (`dead-hours/`)**:
   - **Style:** Painterly Dark Horror (*Until Dawn* / *TLOU* aesthetic).
   - **Scope:** Continue using the existing art pipeline (`ART_PIPELINE.md`). Complete remaining character emotion variants and exploration sprites in painterly style.
   - **UI:** Maintain dark narrative theme (`theme/default_theme.tres`).

2. **Dead Hours: Visitor (`visitor/`)**:
   - **Style:** Analog Horror / Uncanny Valley (*No, I'm not a Human* / *Mandela Catalogue* aesthetic).
   - **Scope:** Hand-drawn rasterized portraits, green monochrome UI (#00ff41 / #0a1a0a palette), CRT/VHS shader stack, static staring faces.
   - **Focus:** Staring at faces, detecting infection signs (bloodshot eyes, lack of blinking, subtle facial asymmetry, speech delays).

### Shared Lore & Cross-Promotion
While the art styles differ to match their respective gameplay loops, both games inhabit the **same shared universe**:
- *Dead Hours* covers the macro narrative of survivors escaping to or living in Riverside.
- *Visitor* covers a micro inspection booth role at Riverside's entry gate.
- Cross-game easter eggs and shared character lore can bridge the two titles without compromising their individual visual identities.
