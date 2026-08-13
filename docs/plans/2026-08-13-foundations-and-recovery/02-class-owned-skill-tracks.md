# Step 2 — Automatic class-owned skill tracks (retire manual Attack points)

**Branch:** `class-owned-skill-tracks`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("define automatic class-owned skill
tracks and their migration from manual Attack points"), §1.3,
`docs/design-resolutions.md` §1.1, §1.4, §1.5, and
`docs/designs/class-system.md` → "Shared tactical attributes" (the skill
model) + "Advancement and perks" → *Approved replacement*.

## Goal

Levels advance class-owned skills automatically; the player no longer
allocates a generic skill-point currency. The manual Attack-spending flow is
**removed**, not kept alongside — class-system.md: *"It must remove the
manual Attack-spending flow rather than keeping two competing advancement
systems."*

Per the class-system design and approved design resolutions (`design-resolutions.md` §1.5):
1. Upon leveling up, skill point gains within specified tiers are determined by a **random roll** in the specified tier range:
   - `low` = 1–2 points (random roll)
   - `med` = 3–4 points (random roll)
   - `hi`  = 4–5 points (random roll)
2. Character primary attributes on a 1–10 scale govern initial character creation (Warrior: Str 6–8, Int 1–4; Scout: Str 4–6, Int 3–5), with base hit chance scaling `(agility * 10 * class_multiplier)%` (Warrior multiplier 1.5, Scout 1.0).
3. The single stored `attack` value splits into `melee` and `missile` skills, class tracks grow `guard` and `might`, and per-class `vitality` derives max health (`max_health = vitality × level × perk_modifiers`, replacing flat +10 per level).
4. On level up, a dedicated **Level Up Screen** displays the increased skills and presents a perk choice button when earned (or defer selection to choose from Unit Details).
5. `spellcasting`/`magic_resistance` stay design-only until the Mage slice owns a spell system (roadmap part 2).

## Design

### Which skills ship in this slice

The design's growth table gives both shipped classes tracks for might,
melee, missile, and guard (spellcasting is `n/a` for them). All four map to
effect channels that already exist in `main`:

| Skill | Tier (Warrior) | Tier (Scout) | Effect channel in `main` |
|---|---|---|---|
| `melee` | `med` (3–4) | `low` (1–2) | Hit chance with non-bow weapons. `get_effective_hit_chance()` feeds player-unit creation in `battle_controller.gd`. |
| `missile` | `med` (3–4) | `hi` (4–5) | Hit chance with bow attacks — ranged combat is shipped (Scouts equip bows with range 1–3/1–4); the same hit-chance path serves them. |
| `guard` | `low` (1–2) | `low` (1–2) | Subtracted from incoming attackers' hit chance (`clamp(hit_chance − defender guard, 5%, 95%)` in `battle_controller.gd`). Guard skill adds to armor defense in `get_effective_defense()`. |
| `might` | `med` (3–4) | `low` (1–2) | Added to raw damage before Resistance (`max(1, round((roll + raw_damage_bonus + might) × (1 − resistance / 100)))`). |

Deferred — no owning system, so no data, per index constraint 2:
`spellcasting`/`magic_resistance` (Mage slice, part 2), dodge and parry
(combat-system.md "Defending"), cover/flanking/attacks of opportunity,
scouting and line of sight.

### Class data

Extend `CLASS_DEFINITIONS` in `scripts/autoload/game_session.gd`. `vitality` and primary creation attribute ranges join `base_stats`; `attack` splits into `melee`/`missile`; `guard`/`might` start at 0. Skill growth specifies tier range data (`min_gain`, `max_gain`):

```gdscript
const CLASS_DEFINITIONS: Dictionary = {
    "warrior": {
        "allowed_weapon_categories": ["sword", "dagger", "axe"],
        "base_stats": {"max_health": 10, "vitality": 10, "melee": 60, "missile": 60, "guard": 0, "might": 0, "move_range": 3},
        "primary_attribute_ranges": {"strength": Vector2i(6, 8), "agility": Vector2i(6, 8), "vitality": Vector2i(6, 8), "intelligence": Vector2i(1, 4), "piety": Vector2i(1, 4), "luck": Vector2i(1, 10)},
        "class_multiplier": 1.5,
        "skills": {
            "melee": {"tier": "med", "min_gain": 3, "max_gain": 4},
            "missile": {"tier": "med", "min_gain": 3, "max_gain": 4},
            "guard": {"tier": "low", "min_gain": 1, "max_gain": 2},
            "might": {"tier": "med", "min_gain": 3, "max_gain": 4},
        },
    },
    "scout": {
        "allowed_weapon_categories": ["dagger", "bow"],
        "base_stats": {"max_health": 12, "vitality": 12, "melee": 65, "missile": 65, "guard": 0, "might": 0, "move_range": 3},
        "primary_attribute_ranges": {"strength": Vector2i(4, 6), "agility": Vector2i(6, 8), "vitality": Vector2i(4, 6), "intelligence": Vector2i(3, 5), "piety": Vector2i(1, 4), "luck": Vector2i(1, 10)},
        "class_multiplier": 1.0,
        "skills": {
            "melee": {"tier": "low", "min_gain": 1, "max_gain": 2},
            "missile": {"tier": "hi", "min_gain": 4, "max_gain": 5},
            "guard": {"tier": "low", "min_gain": 1, "max_gain": 2},
            "might": {"tier": "low", "min_gain": 1, "max_gain": 2},
        },
    },
}
```

Rules and rationale:

- Skill point gains on level up roll randomly within the tier range (`randi_range(min_gain, max_gain)`). Follow the injectable-roll pattern (`skill_gain_roll`) so tests can pin rolls deterministically.
- A skill's **starting value** is the class's `base_stats` entry at level 1; random tier rolls apply on each level-up from level 2 on.
- Initial base hit chance scales as `(agility × 10 × class_multiplier)%`.
- **Max health** becomes `vitality × level × perk_modifiers`, recomputed on level-up and migration.
- `get_effective_hit_chance(adventurer_id)` reads the equipped weapon's category: `bow` → `missile`, everything else → `melee`. The hit chance is clamped between 5% and 95% in combat resolution.
- `get_effective_defense(adventurer_id)` returns `stats.guard` + armor defense bonus.
- New `get_effective_might(adventurer_id)` returns the stored Might; `battle_controller.gd` adds it to player raw damage.

### Level-up application

In `_award_adventurer_xp()`:
1. Remove `progression.skill_points += LEVEL_UP_SKILL_POINTS` and `stats.max_health += LEVEL_UP_MAX_HEALTH_BONUS`.
2. After `level += 1`, recompute `stats.max_health = vitality × level`.
3. Roll random skill gain per class skill (`gain = skill_gain_roll.call(min_gain, max_gain)`) and apply `stats.<skill> += gain`.

### Removals (all of these, or the step is not done)

- `GameSession.spend_attack_points()` and its tests.
- The `LEVEL_UP_SKILL_POINTS` and `LEVEL_UP_MAX_HEALTH_BONUS` vars, their `_load_balance_config()` lines, config JSON keys, `game_config.gd` DEFAULTS, and `test_game_config.gd` rows.
- The `BASE_ATTACK` and `BASE_MAX_HEALTH` vars with their config plumbing. Class base values now live in `CLASS_DEFINITIONS`.
- `"skill_points": 0` from adventurer progression dicts.
- Level-up overlay spend UI: `SkillPointsLabel` and `AttackRow` (+/− buttons) in `scenes/ui/level_up.tscn` and `scripts/ui/level_up.gd`.
- Translation key `level_up.skill_points`.

### UI presentation

- **Level-up overlay** (`scripts/ui/level_up.gd`, `scenes/ui/level_up.tscn`):
  - Displays one skill-gain row per gained skill ("Melee 63 (+3)", "Might 3 (+4)", …) with before/after deltas.
  - Displays HealthGain row.
  - If a perk choice is earned, presents a prominent perk selection button allowing immediate selection (or deferral to choose from Unit Details).
- **Unit Details** (`scripts/ui/unit_details.gd`):
  - Skills section lists class skills with current value and tier growth rate ("Melee: 63 (+3–4 per level)").
  - Stats row displays Melee / Missile hit chances and Guard / Might stats.

### Save migration (CampaignSnapshot)

Extend the nested per-adventurer normalization pass:
1. Drop legacy `progression.skill_points` key.
2. Split attack into class tracks: for each of `melee`/`missile`, calculate minimum track threshold using baseline tier gains and set `value = max(stored_attack, track)`.
3. Normalize `guard`/`might` to `max(stored if present else 0, track)`.
4. Recompute `max_health = max(stored, vitality × level)`.
5. Retain opaque record IDs.

### Scenario factory and scenarios

Rework `scripts/tools/battle_scenarios/battle_state_factory.gd`:
- Base values load from `CLASS_DEFINITIONS`.
- `max_health = vitality × level`; skills calculate from base stats plus tier gains.
- Scenario schema uses `melee` and `guard` keys.

## Setup

```bash
git checkout main && git pull
git checkout -b class-owned-skill-tracks
make check   # green baseline
```

Capture baseline evidence:
```bash
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
make simulate RUNS=20
```

## TDD task list (red → green, in this order)

1. **GameSession automatic growth** (`tests/unit/test_game_session.gd`):
   - Leveling a Warrior once rolls skill gains within tier ranges (melee: 3–4, missile: 3–4, guard: 1–2, might: 3–4) using pinned `skill_gain_roll`, recomputes max health as `vitality × level`, and grants **no** skill points.
   - `get_effective_hit_chance()` follows equipped weapon category.
   - `get_effective_defense()` = armor defense + guard skill; `get_effective_might()` returns stored might.
   - Fresh warrior/scout records carry class base stats — no `skill_points`, no `attack` key.
   - Regression guard: level 3 pends perk choice; Level Up UI presents perk button.
2. **Battle integration** (`tests/unit/test_battle_controller.gd`): player units start with weapon-appropriate hit chance, and damage rolls add Might.
3. **Save migration** (`tests/unit/test_campaign_snapshot.gd`): legacy adventurer dicts load with `skill_points` removed, stats migrated to class tracks, and max health recalculated.
4. **Removals:** delete `spend_attack_points()`, obsolete config constants, and spend UI code.
5. **Level-up overlay** (`tests/unit/test_level_up.gd`): shows skill-gain rows with deltas, vitality health row, and perk selection button when earned.
6. **Unit Details** (`tests/unit/test_unit_details.gd`): skills section displays class skills and tier growth ranges.
7. **Scenario factory and schema:** update `battle_state_factory.gd` and scenario contracts.
8. **Translations & Docs:** update localization keys and `docs/dev/code-map.md`.

## Verification

```bash
make check
```

Balance gate:
```bash
make scenario SCENARIO=scenarios/battle/class-skill-progression.json SEED=20260813 ITERATIONS=20
```
**Gate:** no stalemates; win rate at levels 3 and 5 is ≥ level-1 win rate.

## Manual verification (user sign-off)

1. `make play` → **FN+F9** → **Orc Outpost Battle**. Win fight.
2. Level-up overlay shows random skill-gain rows within tier ranges (e.g. "Melee +3", "Might +4") and vitality health row.
3. Upon reaching level 3, confirm perk choice button appears on Level Up Screen.
4. Unit Details: confirm skills section lists class skills and growth tiers.

## Commit and merge

```bash
git add -A && git status
git commit -m "feat: replace manual skill points with automatic class-owned skill tracks"
# after user sign-off:
git checkout main && git merge class-owned-skill-tracks && git branch -d class-owned-skill-tracks
```

## Milestone (concretely verifiable)

- `grep -rn "skill_points\|spend_attack_points"` returns **nothing**.
- `make check` green.
- Win rate non-decreasing with level in `make scenario` class-skill-progression report.
- Signed-off screenshots: Level Up Screen (showing skill gains & perk button) and Unit Details.
