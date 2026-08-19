# Placeholder Audio Assets

Every `.wav` file under `sfx/` and `music/` is a **synthesized placeholder
tone, generated in-house** by a one-off local Python script (stdlib `wave`
module only, no external dependencies or network access). Each clip is a
short sequence of sine/square-wave tones with a linear fade-in/fade-out
envelope, distinguishable from its neighbors by pitch, duration, and
wave shape — not intended to sound good, only to exist as a valid,
decodable audio asset Godot can import and play.

- **Source:** none — generated locally, not downloaded.
- **Licence:** none needed; no third-party content, no attribution
  required. Treat these as fully owned, royalty-free placeholders.
- **Format:** mono 16-bit PCM WAV, 22050 Hz sample rate.
- **Intent:** placeholder only. This synthesized set is meant to be
  replaced by a real composed/recorded asset pass later — see
  `docs/plans/2026-08-18-core-loop-and-engagement/08-audio-system-and-soundscape.md`.

## Catalog

### `sfx/` — sound effects (`AudioManager.play_sfx(id)`)

| id | description |
|---|---|
| `sfx_melee_swing` | Weapon swoosh on melee strike |
| `sfx_bow_shot` | Bow string release for Scout ranged attack |
| `sfx_hit_impact` | Heavy physical impact on landed attack |
| `sfx_crit_impact` | Resonant metallic smash on critical hit |
| `sfx_miss` | Whiff / dodge sound on missed strike |
| `sfx_guard_block` | Shield clang when Guard absorbs/deflects damage |
| `sfx_spell_heal` | Holy chime on Cleric heal |
| `sfx_spell_bless` | Protective chime on Bless cast |
| `sfx_unit_death` | Low sting / casualty thud on unit defeat |
| `sfx_retreat_horn` | Horn call on tactical retreat |
| `sfx_ui_click` | Soft tactile click on button press |
| `sfx_building_upgrade` | Hammer and construction sound on building upgrade |
| `sfx_gold_coins` | Coin jingle on banking loot / shopping |
| `sfx_level_up` | Triumphant jingle on adventurer level-up |

### `music/` — music/ambience tracks (`AudioManager.play_music(id)`)

| id | description |
|---|---|
| `music_encampment` | Calming acoustic / ambient camp loop |
| `music_world_map` | Adventurous, restrained exploration theme |
| `music_battle` | Tense, rhythmic tactical combat track |
| `music_boss` | Climactic battle loop for the Ogre encounter |
| `music_victory` | Fanfare on campaign victory |
| `music_defeat` | Somber motif on party wipe |

## Regenerating

The generator script itself is not part of this repository (it was a
throwaway, run-once local tool). Any future regeneration only needs to
reproduce the id → filename contract above using Godot-importable mono WAV
files; the exact synthesis approach is not load-bearing.
