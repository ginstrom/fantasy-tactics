# Step 2 — Automatic class-owned skill tracks (retire manual Attack points)

**Branch:** `class-owned-skill-tracks`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("define automatic class-owned skill
tracks and their migration from manual Attack points"), §1.3, and
`docs/designs/class-system.md` → "Shared tactical attributes" (the skill
model) + "Advancement and perks" → *Approved replacement*.

## Goal

Levels advance class-owned skills automatically; the player no longer
allocates a generic skill-point currency. The manual Attack-spending flow is
**removed**, not kept alongside — class-system.md: *"It must remove the
manual Attack-spending flow rather than keeping two competing advancement
systems."*

Per the class-system design, this first slice must define, in class data:
each applicable skill's starting value, per-level gain, combat or campaign
effect, UI presentation, save migration, and balance coverage. The 2026-08-13
design update makes that concrete: the single stored `attack` value splits
into the `melee` and `missile` skills, class tracks grow `guard` and
`might`, and per-class `vitality` derives max health
(`max_health = vitality × level`, replacing the flat +10 per level — index
decision 3). `spellcasting`/`magic_resistance` stay design-only until the
Mage slice owns a spell system (roadmap part 2).

## Design

### Which skills ship in this slice

The design's growth table gives both shipped classes tracks for might,
melee, missile, and guard (spellcasting is `n/a` for them). All four map to
effect channels that already exist in `main`:

| Skill | Effect channel in `main` |
|---|---|
| `melee` | Hit chance with non-bow weapons. `get_effective_hit_chance()` feeds player-unit creation in `battle_controller.gd`; combat-system.md: "To-hit is governed by the melee attack skill." |
| `missile` | Hit chance with bow attacks — ranged combat is already shipped (Scouts equip bows with range 1–3/1–4); the same hit-chance path serves them. |
| `guard` | Subtracted from incoming attackers' hit chance (`hit_chance − target.defense / 100` in `battle_controller.gd`). Today `get_effective_defense()` is armor-only; the guard skill adds to it. |
| `might` | Added to raw damage before Resistance (`roll + raw_damage_bonus`). Player Might is effectively zero today; the class track supplies it. |

Deferred — no owning system, so no data, per index constraint 2:
`spellcasting`/`magic_resistance` (Mage slice, part 2), dodge and parry
(combat-system.md "Defending"), cover/flanking/attacks of opportunity,
scouting and line of sight. The data shape stays open for all of them:
skills are a per-class dictionary, not a hardcoded field list.

### Class data

Extend `CLASS_DEFINITIONS` in `scripts/autoload/game_session.gd` (stays a
code constant, like `base_stats` — this is class design data, not a
tunable). `vitality` joins `base_stats`; `attack` splits into
`melee`/`missile`; `guard`/`might` start at 0. Class keys here are type
identifiers — a stable design vocabulary — not instance identity; the
generated-id rule of index constraint 6 applies to adventurers and item
instances, not to class data.

```gdscript
const CLASS_DEFINITIONS: Dictionary = {
    "warrior": {
        "allowed_weapon_categories": ["sword", "dagger", "axe"],
        "base_stats": {"max_health": 10, "vitality": 10, "melee": 60, "missile": 60, "guard": 0, "might": 0, "move_range": 3},
        "skills": {
            "melee": {"gain_per_level": 3},
            "missile": {"gain_per_level": 3},
            "guard": {"gain_per_level": 1},
            "might": {"gain_per_level": 3},
        },
    },
    "scout": {
        "allowed_weapon_categories": ["dagger", "bow"],
        "base_stats": {"max_health": 12, "vitality": 12, "melee": 65, "missile": 65, "guard": 0, "might": 0, "move_range": 3},
        "skills": {
            "melee": {"gain_per_level": 1},
            "missile": {"gain_per_level": 4},
            "guard": {"gain_per_level": 1},
            "might": {"gain_per_level": 1},
        },
    },
}
```

Rules and rationale:

- Per-level gains follow the design table's bands — low 1–2, med 3–4, hi
  4–5 points: warrior melee/missile med, guard low, might med; scout melee
  low, missile hi, guard/might low. The concrete values above start at the
  low end of each band; the balance gate below decides whether they stand.
- A skill's **starting value** is the class's `base_stats` entry at level 1;
  `gain_per_level` applies on each level-up from level 2 on.
- Splitting `attack` copies the old value to both `melee` and `missile`
  (warrior 60/60, scout 65/65), so every level-1 combat number is exactly
  what it is today and the baseline evidence must not move.
- **Max health** becomes `vitality × level`, recomputed on level-up and on
  migration. Warrior vitality 10 reproduces today's 10/20/30…; scout
  vitality 12 gives 12/24/36 (was 12/22/32 with the flat +10) — covered by
  the balance gate.
- `get_effective_hit_chance(adventurer_id)` reads the equipped weapon's
  category: `bow` → `missile`, everything else → `melee`. The `/100`
  divisor and the 95% cap are unchanged (combat-system.md's 5% floor already
  lives in `battle_controller.gd`). Monsters keep their template
  `hit_chance` — their data is untouched (index constraint 4).
- `get_effective_defense(adventurer_id)` returns `stats.guard` plus the
  armor's defense.
- New `get_effective_might(adventurer_id)`; `battle_controller.gd` adds it
  to the player unit's raw damage at creation, alongside the weapon's
  `raw_damage_bonus` (sharpening).

### Level-up application

In `_award_adventurer_xp()`: remove the
`progression.skill_points += LEVEL_UP_SKILL_POINTS` and
`stats.max_health += LEVEL_UP_MAX_HEALTH_BONUS` lines; after `level += 1`,
recompute `stats.max_health = vitality × level` and apply the class's skill
gains (`stats.<skill> += gain_per_level` per skill), via a small effect
dispatch (plain `match`/`if` on the skill id — no framework).

### Removals (all of these, or the step is not done)

- `GameSession.spend_attack_points()` and its tests.
- The `LEVEL_UP_SKILL_POINTS` and `LEVEL_UP_MAX_HEALTH_BONUS` vars, their
  `_load_balance_config()` lines, the `progression.level_up_skill_points`
  and `progression.level_up_max_health_bonus` keys in
  `config/game_config.json`, the matching `game_config.gd` `DEFAULTS`
  entries, and the `test_game_config.gd` lockstep rows.
- The `BASE_ATTACK` and `BASE_MAX_HEALTH` vars with their
  `combat.base_attack` / `combat.base_max_health` config plumbing (same
  three-place removal). Class base values now live in `CLASS_DEFINITIONS`;
  `get_default_warrior()` / `get_default_scout()` both seed `stats` from
  their class definition (the scout already does; convert the warrior).
  `ATTACK_TO_HIT_CHANCE_DIVISOR` stays.
- `"skill_points": 0` from `get_default_warrior()` / `get_default_scout()`
  progression dicts (recruits inherit via `_seed_adventurer_baseline_stats()`).
- Level-up overlay spend UI: `SkillPointsLabel` and the `AttackRow`
  (+/− buttons) nodes in `scenes/ui/level_up.tscn` and their handlers in
  `scripts/ui/level_up.gd`.
- Translation key `level_up.skill_points` (`translations/en.tres` and
  `tests/unit/test_localization.gd`).

### UI presentation

- **Level-up overlay** (`scripts/ui/level_up.gd`, `scenes/ui/level_up.tscn`):
  keep Name/XP/Level/HealthGain rows and the perk flow unchanged — the
  HealthGain delta is now the vitality-derived max-health increase. Replace
  the spend row with one **skill-gain row per gained skill** ("Melee 63
  (+3)", "Might 3 (+3)", …). Follow the existing `health_before` pattern,
  generalized: `battlefield.gd` captures a small before-stats snapshot per
  member before `award_party_xp()` and passes it through
  `_queue_level_up()` / `show_for_adventurer()` so the deltas can be
  displayed after GameSession has already mutated the values.
  - `scripts/tools/battle_sim.gd`'s `_resolve_level_up()` needs **no change**
    (it only resolves perks and clicks Continue — verify, don't rewrite).
  - `tests/unit/test_first_campaign_ui_flow.gd` only presses
    `continue_button` — verify it still passes unchanged.
- **Unit Details** (`scripts/ui/unit_details.gd`): the skills section lists
  the class's skills with current value and growth, e.g.
  "Melee: 63 (+3 per level)" (rework the `unit_details.skills` translation
  key). The stats row shows Melee/Missile where it shows raw Attack today;
  derived hit chances continue to display as they do now.

### Save migration (CampaignSnapshot)

Extend the nested per-adventurer normalization pass introduced in step 1
(it already infers recruitment `template_id` there; the snapshot reaches
class constants via its `_GameSessionScript` preload), applying to every
adventurer and recruitment candidate:

1. Drop a legacy `progression.skill_points` key if present.
2. Split attack into the class tracks: for each of `melee`/`missile`,
   `track = base + gain_per_level × (level − 1)`;
   `value = max(stored_attack, track)`.
3. Normalize `guard`/`might` (absent in legacy saves) to
   `max(stored if present else 0, track)`.
4. Recompute `max_health = max(stored, vitality × level)`.

Record ids (generated per index constraint 6, or legacy opaque strings)
pass through verbatim — migration touches stats and progression only.
`max()` is the fairness rule: legacy players who spent points keep their
progress, hoarded points are replaced by track values, and nobody ever loses
a point or a hit point. Unknown class ids leave stats untouched. New saves
never contain `skill_points` or an `attack` stat, so `FORMAT_VERSION` stays
`1` — same pattern as the workshop/shop fields added after v1.

### Scenario factory and scenarios

`scripts/tools/battle_scenarios/battle_state_factory.gd` derives leveled
state from flat `BASE_ATTACK`/`BASE_MAX_HEALTH` defaults (its comment says
Attack growth is player-driven). Rework the level-derived block in
`_build_player_unit()`:

- Base values come from the class's `CLASS_DEFINITIONS` entry. Player
  templates resolve through `_read_player_template_base_stats()`, whose
  `template_id` is a class id — currently only `"warrior"` exists
  (`scenario_contract.gd`'s `KNOWN_PLAYER_TEMPLATES`), and no scout template
  is needed for this step's scenarios.
- `max_health = vitality × level`; each class skill is
  `base + gain_per_level × (level − 1)`; fix the stale comment (the
  "GameConfig's current tuning" rationale for reading live `BASE_*` vars
  dies with them — class base data is deliberately non-tunable).
- The modifier vocabulary follows the skill model: `baseline-offense.json`'s
  `attack` modifier becomes `melee` (the scenario's warrior fights with a
  melee weapon; the numbers carry over unchanged), and
  `baseline-defense.json`'s `defense` modifier becomes `guard` (`resistance`
  unchanged). Unit hit chance picks melee or missile by the spec's
  `weapon_id` category, mirroring `get_effective_hit_chance()`. Update
  `scenario_runner_main.gd` schema validation and
  `tests/unit/test_scenario_contract.gd` in the same red/green pass.

## Setup

```bash
git checkout main && git pull
git checkout -b class-owned-skill-tracks
make check   # green baseline
```

**Capture baseline evidence before writing any code** (needed for the
balance gate):

```bash
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
make simulate RUNS=20
```

Note the win/loss/stalemate summaries from the terminal output.

## TDD task list (red → green, in this order)

Write each failing test first, run it to confirm the failure, then
implement. Run focused subsets with
`godot --headless -s addons/gut/gut_cmdln.gd -gselect=<file> -gexit` while
iterating; finish each task group with `make check`.

1. **GameSession automatic growth** (`tests/unit/test_game_session.gd`):
   - Leveling a Warrior once raises melee/missile/guard/might by the class's
     `gain_per_level` values, recomputes max health as `vitality × level`,
     and grants **no** skill points; the Scout follows the Scout's track.
   - `get_effective_hit_chance()` follows the equipped weapon category:
     sword/dagger/axe → melee, bow → missile (equip a Scout with each).
   - `get_effective_defense()` = armor defense + guard skill;
     `get_effective_might()` returns the stored might.
   - Fresh `get_default_warrior()` / `get_default_scout()` records and
     `purchase_recruit()`-seeded records carry the class base stats — no
     `skill_points`, no `attack` key.
   - Regression guard: level 3 still pends exactly one perk choice and
     `choose_perk(BONUS_MOVE_PERK_ID)` still consumes it (cadence invariant).
   - Replace the existing
     `test_each_level_gained_adds_one_max_health_and_ten_skill_points` and
     both `test_spend_attack_points_*` tests (the function disappears).
2. **Battle integration** (`tests/unit/test_battle_controller.gd`): player
   units start with the weapon-appropriate hit chance, and damage rolls add
   Might. Set `stats.melee`/`stats.missile`/`stats.might` directly per
   testing.md's "jump state directly" convention — this also replaces the
   known `spend_attack_points(WARRIOR_ID, 40)` usage (~line 629) that forced
   hit chance.
3. **Save migration** (`tests/unit/test_campaign_snapshot.gd`):
   - Legacy adventurer dict with `skill_points` and an attack below the
     tracks loads with `skill_points` gone, melee/missile raised to their
     track values, guard/might at their track values, and max health
     `= max(stored, vitality × level)`.
   - Legacy adventurer whose stored attack exceeds the tracks keeps the
     excess on both melee and missile.
   - Current-format round-trip: exported snapshots contain no `skill_points`
     and no `attack` stat.
4. **Removals:** delete `spend_attack_points()`, `LEVEL_UP_SKILL_POINTS`,
   `LEVEL_UP_MAX_HEALTH_BONUS`, `BASE_ATTACK`, `BASE_MAX_HEALTH`, and their
   config keys + `DEFAULTS` + `test_game_config.gd` lockstep rows; fix every
   remaining caller (task 2 covers the known battle-controller one).
5. **Level-up overlay** (`tests/unit/test_level_up.gd` rewrite): shows one
   skill-gain row per gained skill with the correct deltas and the
   vitality-derived health row; has no spend buttons or skill-point label
   (assert the nodes are gone); perk flow and Continue unchanged. Update
   `scenes/ui/level_up.tscn`, `scripts/ui/level_up.gd`, and `battlefield.gd`'s
   before-stats plumbing.
6. **Unit Details** (`tests/unit/test_unit_details.gd`): skills section
   shows class skill values + growth (replace
   `test_skills_label_shows_unspent_skill_points`); stats row shows
   Melee/Missile.
7. **Scenario factory and schema**
   (`tests/unit/test_battle_state_factory.gd`,
   `tests/unit/test_scenario_contract.gd`): leveled units follow
   `vitality × level` and the class skill tracks; modifiers use the new
   `melee`/`guard` keys; update `scenarios/battle/baseline-offense.json` and
   `baseline-defense.json` to match.
8. **Translations:** rework `level_up.*` / `unit_details.skills`, delete
   `level_up.skill_points`; update `tests/unit/test_localization.gd` (it
   asserts the old key's exact output).
9. **Docs:** update `docs/dev/code-map.md` — the adventurer-record bullet
   (stats now melee/missile/guard/might with vitality-derived max health;
   progression no longer has `skill_points`) and the Progression formulas
   section (class-track and vitality rules next to the XP/hit-chance/perk
   rules).

## Verification

```bash
make check
```

Green, including all new tests. Then the balance gate:

1. Add `scenarios/battle/class-skill-progression.json` modeled on
   `baseline-party-viability.json`, matrixed over levels 1 / 3 / 5 for a
   2-member warrior party vs. goblin and orc (use `battle_state_factory`'s
   level support; if the scenario schema does not yet carry a per-unit
   `level` field, extend the schema in `scenario_runner_main.gd` validation
   and `test_scenario_contract.gd` first — red test, then schema change).
2. Run it pinned:
   ```bash
   make scenario SCENARIO=scenarios/battle/class-skill-progression.json SEED=20260813 ITERATIONS=20
   ```
   **Gate:** no stalemates; win rate at levels 3 and 5 is ≥ level-1 win rate
   (growth — hit chance, guard, might, vitality health — must help, not
   hurt). If the gate fails, adjust only the `gain_per_level` values and, if
   needed, the per-class `vitality` in `CLASS_DEFINITIONS`, then re-run.
3. Re-run the baseline evidence commands from Setup and confirm
   `baseline-party-viability`, `baseline-offense`, `baseline-defense`, and
   `make simulate` outcomes match the pre-change baseline at level 1
   (level-1 units have no growth and the stat split is value-preserving, so
   results must be identical modulo the scenario runner's RNG-free
   determinism).

Reports are local evidence — do not commit them.

## Manual verification (user sign-off)

1. `make play`, press **FN+F9** → **Orc Outpost Battle** (its kill+clear XP
   always crosses the level-2 threshold — see `docs/dev/code-map.md`).
2. Win the fight. The level-up overlay must show the skill-gain rows
   ("Melee +3", "Might +3", … for a Warrior) and the vitality-derived health
   row, **no** +/− buttons, **no** unspent-points row. Screenshot it.
3. Replay until a member reaches level 3: the overlay offers Bonus Move
   exactly as before (cadence unchanged). Choose it; battle continues.
4. Encampment → Units/Party Details → Unit Details: skills section shows the
   class skills and growth. Screenshot it. With a Scout equipped with a bow,
   confirm the missile skill drives their to-hit in a fight (Unit Details
   stats row before, hit rolls during).
5. Save (game menu), then check the save contains no skill points or attack
   stat:
   ```bash
   SAVE="$(find ~/.local/share/godot -name campaign-save.json | head -1)"
   grep -c skill_points "$SAVE" || true   # expect: 0
   grep -c '"attack"' "$SAVE" || true     # expect: 0
   ```
   Then Load and confirm the Unit Details stats are unchanged.
6. *Optional migration check:* with a save present, hand-add
   `"skill_points": 7` and an old-style `"attack": 60` to one adventurer's
   `progression`/`stats` in the JSON and lower their level-2 values; Load —
   the game must start, the legacy fields must be gone, and melee/missile
   must be at least their track values.

## Commit and merge

```bash
git add -A && git status   # confirm only intended paths are staged
git commit -m "feat: replace manual skill points with automatic class-owned skill tracks"
# after user sign-off:
git checkout main && git merge class-owned-skill-tracks && git branch -d class-owned-skill-tracks
```

## Milestone (concretely verifiable)

- `grep -rn "skill_points\|spend_attack_points\|LEVEL_UP_SKILL_POINTS\|LEVEL_UP_MAX_HEALTH_BONUS\|BASE_ATTACK\|BASE_MAX_HEALTH" scripts/ tests/ config/ translations/`
  returns **nothing**, and no adventurer/class base stats carry an `attack`
  key (monster `attack_damage`/`attack_name_key` fields are untouched).
- `make check` green.
- `make scenario` class-skill-progression report: win rate non-decreasing
  with level, zero stalemates; baseline scenario and sim outputs identical
  to the pre-change capture at level 1.
- Signed-off screenshots: new level-up overlay, Unit Details skills section.
