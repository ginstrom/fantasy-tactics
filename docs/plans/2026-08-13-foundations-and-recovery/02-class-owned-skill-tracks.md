# Step 2 — Automatic class-owned skill tracks (retire manual Attack points)

**Branch:** `class-owned-skill-tracks`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("define automatic class-owned skill
tracks and their migration from manual Attack points"), §1.3, and
`docs/designs/class-system.md` → "Advancement and perks" → *Approved
replacement*.

## Goal

Levels advance class-owned skills automatically; the player no longer
allocates a generic skill-point currency. The manual Attack-spending flow is
**removed**, not kept alongside — class-system.md: *"It must remove the
manual Attack-spending flow rather than keeping two competing advancement
systems."*

Per the class-system design, this first slice must define, in class data:
each applicable skill's starting value, per-level gain, combat or campaign
effect, UI presentation, save migration, and balance coverage.

## Design

### Which skills ship in this slice

Only skills whose effect system already exists in `main`. Today that is
exactly one: **attack (accuracy)** — raw `stats.attack` feeds
`get_effective_hit_chance()` (`min(attack / 100, 0.95)`). Dodge,
spellcasting, and scouting are deferred (their owning systems arrive in
roadmap parts 2–3; gap analysis constraint: do not convert deferred
attributes into mechanics). The data shape must stay open for them: skills
are a per-class dictionary, not a hardcoded attack field.

### Class data

Extend `CLASS_DEFINITIONS` in `scripts/autoload/game_session.gd` (stays a
code constant, like `base_stats` — this is class design data, not a tunable):

```gdscript
const CLASS_DEFINITIONS: Dictionary = {
    "warrior": {
        "allowed_weapon_categories": ["sword", "dagger", "axe"],
        "base_stats": {"max_health": 10, "attack": 60, "move_range": 3},
        "skills": {"attack": {"gain_per_level": 5}},
    },
    "scout": {
        "allowed_weapon_categories": ["dagger", "bow"],
        "base_stats": {"max_health": 12, "attack": 65, "move_range": 3},
        "skills": {"attack": {"gain_per_level": 5}},
    },
}
```

A skill's **starting value** is the class's `base_stats` value at level 1;
`gain_per_level` applies on each level-up from level 2 on. `+5` is the
starting proposal (half the old max-spend growth of +10/level); the balance
gate below decides whether it stands.

### Level-up application

In `_award_adventurer_xp()`: remove the
`progression.skill_points += LEVEL_UP_SKILL_POINTS` line; after
`level += 1` and the max-health increase, apply the class's skill gains.
For this slice that is `stats.attack += gain_per_level` per skill, via a
small effect dispatch (plain `match`/`if` on the skill id — no framework).

### Removals (all of these, or the step is not done)

- `GameSession.spend_attack_points()` and its tests.
- `LEVEL_UP_SKILL_POINTS` var, its `_load_balance_config()` line, the
  `progression.level_up_skill_points` key in `config/game_config.json`, the
  matching `game_config.gd` `DEFAULTS` entry, and the `test_game_config.gd`
  lockstep entry.
- `"skill_points": 0` from `get_default_warrior()` / `get_default_scout()`
  progression dicts (recruits inherit via `_seed_adventurer_baseline_stats()`).
- Level-up overlay spend UI: `SkillPointsLabel` and the `AttackRow`
  (+/− buttons) nodes in `scenes/ui/level_up.tscn` and their handlers in
  `scripts/ui/level_up.gd`.
- Translation key `level_up.skill_points` (`translations/en.tres` and
  `tests/unit/test_localization.gd`).

### UI presentation

- **Level-up overlay** (`scripts/ui/level_up.gd`, `scenes/ui/level_up.tscn`):
  keep Name/XP/Level/HealthGain rows and the perk flow unchanged. Replace the
  spend row with a **skill-gain row** showing the Attack delta this level
  granted (e.g. "Attack 65 (+5)"). Follow the existing `health_before`
  pattern: `battlefield.gd` captures `attack_before` per member before
  `award_party_xp()` and passes it through `_queue_level_up()` /
  `show_for_adventurer()` so the delta can be displayed after GameSession has
  already mutated the value.
  - `scripts/tools/battle_sim.gd`'s `_resolve_level_up()` needs **no change**
    (it only resolves perks and clicks Continue — verify, don't rewrite).
  - `tests/unit/test_first_campaign_ui_flow.gd` only presses `continue_button`
    — verify it still passes unchanged.
- **Unit Details** (`scripts/ui/unit_details.gd`): the skills row shows the
  class's skills with current value and growth, e.g. "Skills — Attack: 70
  (+5 per level)" (rework the `unit_details.skills` translation key; raw
  Attack/hit chance stay in the stats row as today).

### Save migration (CampaignSnapshot)

`CampaignSnapshot.from_dictionary()` currently validates adventurer lists at
id level only (`_normalize_id_list()`). Add a nested per-adventurer
normalization pass there (the snapshot already reaches class constants via
its `_GameSessionScript` preload), applying to every adventurer and
recruitment candidate:

1. Drop a legacy `progression.skill_points` key if present.
2. Recompute attack floor from the class track:
   `track_attack = base_stats.attack + gain_per_level * (level - 1)`;
   set `stats.attack = max(stored_attack, track_attack)`.

`max()` is the fairness rule: legacy players who spent points keep their
progress (stored exceeds track), legacy players who hoarded points are
brought up to the track (track exceeds stored), and nobody ever loses
Attack. Unknown class ids leave `stats.attack` untouched. New saves never
contain `skill_points`, so `FORMAT_VERSION` stays `1` — same pattern as the
workshop/shop fields added after v1.

### Scenario factory

`scripts/tools/battle_scenarios/battle_state_factory.gd` derives leveled
state (currently max health only; its comment explicitly says Attack growth
is player-driven). Update `_leveled_state()` to also apply the class track's
attack gain per level, and fix the comment. `tests/unit/test_battle_state_factory.gd`
covers this.

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
   - Leveling a Warrior once raises `stats.attack` by the class's
     `gain_per_level` and grants **no** skill points; same for a Scout with
     the Scout's track.
   - Fresh `get_default_warrior()` / `get_default_scout()` progression has no
     `skill_points` key; `purchase_recruit()`-seeded records match.
   - Regression guard: level 3 still pends exactly one perk choice and
     `choose_perk(BONUS_MOVE_PERK_ID)` still consumes it (cadence invariant).
   - Replace the existing `test_each_level_gained_adds_one_max_health_and_ten_skill_points`
     and both `test_spend_attack_points_*` tests (the function disappears).
2. **Save migration** (`tests/unit/test_campaign_snapshot.gd`):
   - Legacy adventurer dict with `skill_points` and an attack below the track
     loads with `skill_points` gone and attack raised to the track value.
   - Legacy adventurer whose stored attack exceeds the track keeps the excess.
   - Current-format round-trip: exported snapshot contains no `skill_points`.
3. **Removals:** delete `spend_attack_points()`, `LEVEL_UP_SKILL_POINTS`,
   config key + DEFAULTS + `test_game_config.gd` lockstep row; fix every
   remaining caller — known: `tests/unit/test_battle_controller.gd` (~line
   629, uses `spend_attack_points(WARRIOR_ID, 40)` to force hit chance →
   set `stats.attack` directly, per testing.md's "jump state directly"
   convention).
4. **Level-up overlay** (`tests/unit/test_level_up.gd` rewrite): shows the
   skill-gain row with the correct delta; has no spend buttons or skill-point
   label (assert the nodes are gone); perk flow and Continue unchanged.
   Update `scenes/ui/level_up.tscn`, `scripts/ui/level_up.gd`, and
   `battlefield.gd`'s `attack_before` plumbing.
5. **Unit Details** (`tests/unit/test_unit_details.gd`): skills row shows
   class skill value + growth (replace
   `test_skills_label_shows_unspent_skill_points`).
6. **Scenario factory** (`tests/unit/test_battle_state_factory.gd`): leveled
   units gain the class track's attack per level.
7. **Translations:** rework `level_up.attack` / `unit_details.skills`,
   delete `level_up.skill_points`; update `tests/unit/test_localization.gd`
   (it asserts the old key's exact output).
8. **Docs:** update `docs/dev/code-map.md` — the adventurer-record bullet
   (progression no longer has `skill_points`) and the Progression formulas
   section (add the class-track rule next to the XP/hit-chance/perk rules).

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
   (growth must help, not hurt). If the gate fails, adjust only the
   `gain_per_level` values in `CLASS_DEFINITIONS` and re-run.
3. Re-run the baseline evidence commands from Setup and confirm
   `baseline-party-viability` and `make simulate` outcomes match the
   pre-change baseline at level 1 (level-1 units have no growth, so results
   must be identical modulo RNG-free determinism of the scenario runner).

Reports are local evidence — do not commit them.

## Manual verification (user sign-off)

1. `make play`, press **FN+F9** → **Orc Outpost Battle** (its kill+clear XP
   always crosses the level-2 threshold — see `docs/dev/code-map.md`).
2. Win the fight. The level-up overlay must show the Attack gain row
   ("+5"), **no** +/− buttons, **no** unspent-points row. Screenshot it.
3. Replay until a member reaches level 3: the overlay offers Bonus Move
   exactly as before (cadence unchanged). Choose it; battle continues.
4. Encampment → Units/Party Details → Unit Details: skills row shows the
   class skill and growth. Screenshot it.
5. Save (game menu), then check the save contains no skill points:
   ```bash
   SAVE="$(find ~/.local/share/godot -name campaign-save.json | head -1)"
   grep -c skill_points "$SAVE" || true   # expect: 0
   ```
   Then Load and confirm the Unit Details stats are unchanged.
6. *Optional migration check:* with a save present, hand-add
   `"skill_points": 7` to one adventurer's `progression` in the JSON and
   lower their `attack` by 5; Load — the game must start, the field must be
   gone, and attack must be at least the track value.

## Commit and merge

```bash
git add -A && git status   # confirm only intended paths are staged
git commit -m "feat: replace manual skill points with automatic class-owned skill tracks"
# after user sign-off:
git checkout main && git merge class-owned-skill-tracks && git branch -d class-owned-skill-tracks
```

## Milestone (concretely verifiable)

- `grep -rn "skill_points\|spend_attack_points" scripts/ tests/ config/ translations/`
  returns **nothing**.
- `make check` green.
- `make scenario` class-skill-progression report: win rate non-decreasing
  with level, zero stalemates; baseline scenario output identical to the
  pre-change capture at level 1.
- Signed-off screenshots: new level-up overlay, Unit Details skills row.
