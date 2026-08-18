# Step 8: Audio Architecture, Sound Effects, Music, and Mute Parity

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/audio-system-and-soundscape`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Implement a placeholder-only audio architecture and mute-parity pass after the owner has approved the Step-7 screenshots. Create a dedicated `AudioManager` autoload managing **Master**, **Music**, and **SFX** buses with persistent user volume settings. Use only repository-tracked placeholder or CC0 assets with source/licence metadata; polished custom music and sound production remain out of scope.

---

## Technical Design

### 1. Audio Manager Autoload (`scripts/autoload/audio_manager.gd`)
- Add `AudioManager` to Godot `[autoload]` in `project.godot`:
  - Manages audio buses: `"Master"`, `"Music"`, `"SFX"`.
  - Exposes volume controls: `set_bus_volume(bus_name: String, volume_linear: float) -> void` and `get_bus_volume(bus_name: String) -> float`.
  - Persists audio settings in user config.
- Methods:
  - `play_sfx(sfx_id: String, pitch_jitter: float = 0.05) -> void`: Plays a sound effect with slight randomized pitch variation to prevent acoustic fatigue.
  - `play_music(track_id: String, crossfade_duration: float = 1.0) -> void`: Crossfades background music between scenes.
  - `stop_music(fade_out: float = 1.0) -> void`.

### 2. Placeholder Asset and Bus Contract (`assets/audio/`, `default_bus_layout.tres`)
- Add the actual Godot bus-layout resource and include it in the staged-file list.
- Every imported placeholder asset has a short source/licence record under `assets/audio/README.md`; missing optional assets must fail softly (log once and preserve visual feedback).

### 3. Sound Effects Catalog (`assets/audio/sfx/`)
- **Tactical Combat SFX:**
  - `sfx_melee_swing`: Weapon swoosh on melee strike.
  - `sfx_bow_shot`: Bow string release for Scout ranged attack.
  - `sfx_hit_impact`: Heavy physical impact on landed attack.
  - `sfx_crit_impact`: Resonant metallic smash on critical hit.
  - `sfx_miss`: Whiff / dodge sound on missed strike.
  - `sfx_guard_block`: Shield clang when Guard absorbs/deflects damage.
  - `sfx_spell_heal`: Holy chime on Cleric heal.
  - `sfx_spell_bless`: Protective chime on Bless cast.
  - `sfx_unit_death`: Low sting / casualty thud on unit defeat.
  - `sfx_retreat_horn`: Horn call on tactical retreat.
- **Encampment & UI SFX:**
  - `sfx_ui_click`: Soft tactile click on button press.
  - `sfx_building_upgrade`: Hammer and construction sound on building upgrade.
  - `sfx_gold_coins`: Coin jingle on banking loot / shopping.
  - `sfx_level_up`: Triumphant jingle on adventurer level-up.

### 4. Music & Ambience Tracks (`assets/audio/music/`)
- `music_encampment`: Calming acoustic / ambient camp loop.
- `music_world_map`: Adventurous, restrained exploration theme.
- `music_battle`: Tense, rhythmic tactical combat track.
- `music_boss`: Placeholder climactic battle loop for the Ogre encounter.
- `music_victory`: Fanfare on campaign victory.
- `music_defeat`: Somber motif on party wipe.

### 5. Audio Settings Panel (`scenes/ui/audio_settings.tscn`, `scripts/ui/audio_settings.gd`)
- Add Volume Sliders (Master, Music, SFX) accessible from Game Menu (`scenes/ui/game_menu.tscn`) and Title Menu.
- Include Mute toggles per bus.

### 6. Visual Mute Parity Guarantee
- Ensure that every sound cue has a direct, synchronized visual equivalent:
  - Hits/crits/misses/blocks → Floating combat text.
  - Low HP / wounds → Portrait wound badges.
  - Spells / buffs → Visual status badges and combat log lines.
  - Loot gained / gold banked → Popups and inventory count increments.
  - Zero critical tactical information is conveyed solely through sound.

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/audio-system-and-soundscape
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **AudioManager Bus & Volume Control ([`tests/unit/test_audio_manager.gd`](../../../tests/unit/test_audio_manager.gd)):**
   - Test setting bus volume updates Godot `AudioServer` bus volume in decibels.
   - Test muting bus zeroes audio output.
   - Test volume settings persist across save/load.

2. **Sound Effect Triggers ([`tests/unit/test_audio_manager.gd`](../../../tests/unit/test_audio_manager.gd) & [`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test `play_sfx()` triggers appropriate sound on attack, crit, miss, heal, and unit death.
   - Test pitch jitter stays within specified range.

3. **Music State Transitions ([`tests/unit/test_audio_manager.gd`](../../../tests/unit/test_audio_manager.gd)):**
   - Test scene transitions (Encampment → World Map → Battle → Victory) request correct music tracks and crossfade smoothly.

4. **Settings UI Integration ([`tests/unit/test_game_menu.gd`](../../../tests/unit/test_game_menu.gd)):**
   - Test volume sliders in Game Menu adjust `AudioManager` bus values.

5. **Mute Parity Coverage ([`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd)):**
   - Assert all combat events produce UI/log output even when audio is muted.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. Open **Game Menu** (Esc or menu button) and adjust **Audio Settings**:
   - Move SFX slider and confirm button click sound adjusts in volume.
   - Move Music slider and confirm background music adjusts in volume.
3. In the **Encampment**:
   - Confirm soothing ambient music plays.
   - Upgrade a building and confirm upgrade sound effect plays.
4. Travel to the **World Map**:
   - Confirm music smoothly transitions to the World Map exploration theme.
5. Enter a **Battle**:
   - Confirm combat music starts.
   - Execute attacks: confirm distinct sounds for normal hits, critical hits, misses, and Cleric healing.
   - Knock out an enemy: confirm defeat sound effect.
6. **Mute Test:**
   - Mute Master volume in settings.
   - Play a complete battle and confirm that all hits, damage, crits, and deaths are 100% readable via floating text and combat log.

---

## Commit and Merge

```bash
git status --short
git add assets/audio default_bus_layout.tres scripts/autoload/audio_manager.gd scenes/ui/audio_settings.tscn scripts/ui/audio_settings.gd scenes/ui/game_menu.tscn scripts/ui/game_menu.gd scripts/battle/battle_controller.gd scripts/battle/battlefield.gd scripts/ui/encampment.gd scripts/world/world_map.gd project.godot translations/en.tres tests/unit/test_audio_manager.gd tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd tests/unit/test_game_menu.gd
git diff --cached --check
git commit -m "feat(audio): implement audio manager, bus volume controls, combat/UI SFX, and mute parity"

# After user sign-off:
git checkout main
git merge feat/audio-system-and-soundscape
git branch -d feat/audio-system-and-soundscape
```

---

## Milestone (Concretely Verifiable)

- `AudioManager` manages Master/Music/SFX buses with persistent user volume controls.
- Full sound effect coverage across combat, spells, UI, and building upgrades.
- Music smoothly accompanies Encampment, World Map, Combat, and Victory states.
- 100% visual feedback parity is maintained when muted.
- `make check` passes 100% green.
