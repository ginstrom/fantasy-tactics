# Step 8: Per-monster kill XP (addendum)

**Why this step exists:** the final whole-branch review of Steps 1-7 found
that kill XP is a flat per-*site* number (`EXPEDITIONS[id].kill_xp`),
unaffected by which monster died. That was harmless while every site fielded
exactly one enemy type, but the Ruined Fortress (Step 4) fields 1-8 enemies
of wildly different individual danger from the same site, so total reward
now runs *backwards*: the safest roll (8 Kobolds, 6 HP each) pays
`8 * 15 + 30 = 150` XP, while the deadliest roll (1 Hobgoblin, 30 HP, beats
a solo Warrior 5 rounds to 11) pays only `1 * 15 + 30 = 45`. This step moves
`kill_xp` onto each monster's own stat block — matching how gold/mana
crystal/gear loot already works per monster via `ENEMY_LOOT_TABLES` — so
reward scales with the specific enemy killed, not with `EXPEDITIONS`-level
site data or how many happened to spawn.

**Depends on:** Steps 1-7 merged (needs `KOBOLD_ENEMY_STATS`/
`HOBGOBLIN_ENEMY_STATS` and the Ruined Fortress to exist).

**Produces:** `kill_xp` moves from `EXPEDITIONS[id]` to each
`*_ENEMY_STATS` const (Kobold 3, Goblin 5, Orc 10, Hobgoblin 20 — Goblin and
Orc keep their current numbers unchanged; only where the number *lives*
changes). `clear_xp` is untouched — it stays a flat, one-time,
per-site completion bonus, since that's not what caused the inversion (it's
already identical no matter which composition rolled). A defeated `Unit`
now carries its own `kill_xp`, and `Battlefield._award_kill_xp()` reads it
from the specific unit that died instead of from the site.

**New reward range for the Ruined Fortress** (kill_xp only; loot gold/mana
crystals/gear are unaffected, already per-monster):

| Composition (count range) | Kill XP range | + 30 clear XP | Total |
|---|---|---|---|
| 4-8 Kobolds | 12-24 | +30 | 42-54 |
| 3-6 Goblins | 15-30 | +30 | 45-60 |
| 2-4 Orcs | 20-40 | +30 | 50-70 |
| 1-3 Hobgoblins | 20-60 | +30 | 50-90 |

Reward now rises with danger tier instead of running backwards, and the
worst-case jackpot drops from 150 to 90 — no longer enough to vault a fresh
level-1 adventurer (0 XP) past the level-5 threshold (140) in one battle.

**Known, accepted side effect:** the Orc Outpost's two-Goblin composition
option currently awards the *site's* flat `kill_xp` (10) per kill — i.e. a
Goblin killed there pays double what the same Goblin pays at the Goblin
Camp (5). That was already an inconsistency (a Goblin is a Goblin
regardless of which site it's fought at); this step fixes it as a natural
consequence of making kill_xp per-monster. The Orc Outpost's two-Goblin
clear now pays `5 + 5 = 10` kill XP instead of `10 + 10 = 20` (see Step 3's
test update below) — its clear_xp (20) is unchanged, and its one-Orc option
is unaffected either way since Orc kill_xp stays 10.

## Setup

```bash
git checkout main && git pull
git checkout -b per-monster-kill-xp
```

## Steps

- [ ] **Step 1: Update failing test expectations first (RED)**

  Edit `tests/unit/test_game_session.gd`.

  Find `test_kobold_enemy_stats_are_the_weakest_tier` (added in Step 2) and
  add one line to it:
  ```gdscript
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.kill_xp, 3)
  ```

  Find `test_hobgoblin_enemy_stats_are_the_strongest_tier` (added in Step 2)
  and add one line to it:
  ```gdscript
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.kill_xp, 20)
  ```

  Add two new assertions next to the existing `loot_id` checks (near
  `GameSessionScript.GOBLIN_ENEMY_STATS.loot_id`/`ORC_ENEMY_STATS.loot_id`):
  ```gdscript
  func test_goblin_and_orc_enemy_stats_carry_their_kill_xp() -> void:
  	assert_eq(GameSessionScript.GOBLIN_ENEMY_STATS.kill_xp, 5)
  	assert_eq(GameSessionScript.ORC_ENEMY_STATS.kill_xp, 10)
  ```

  Find `test_ruined_fortress_is_a_three_star_site_at_its_documented_position`
  (added in Step 4) and delete its `kill_xp` assertion line (it currently
  reads `assert_eq(record.kill_xp, 15)`) — this field is moving off
  `EXPEDITIONS` entirely in this step, so asserting it here would fail
  against a now-nonexistent key. Leave the rest of that test (`position`,
  `difficulty`, `clear_xp`, `name_key`) unchanged.

  Edit `tests/unit/test_battlefield.gd`.

  Find `test_defeating_two_enemies_in_one_battle_awards_kill_xp_for_each`
  (it forces the Orc Outpost to its two-Goblin option via
  `_setup_orc_outpost_battle(func(_option_count: int) -> int: return 0)`).
  Change its final assertion from:
  ```gdscript
  	assert_eq(
  		GameSession.get_adventurer("warrior_001").progression.xp,
  		20.0,
  		"Defeating both enemies in one battle should award kill_xp (10) twice, not once"
  	)
  ```
  to:
  ```gdscript
  	assert_eq(
  		GameSession.get_adventurer("warrior_001").progression.xp,
  		10.0,
  		"Each Goblin should award its own kill_xp (5) regardless of which site it's fought at, not the site's flat kill_xp"
  	)
  ```
  (`test_defeating_the_goblin_awards_its_five_point_kill_xp` and
  `test_defeating_the_orc_awards_its_ten_point_kill_xp` keep their existing
  `5.0`/`10.0` expectations unchanged — Goblin and Orc's kill_xp values
  aren't changing, only where they're read from.)

- [ ] **Step 2: Run the suite and confirm these fail**

  Run: `make test`
  Expected: FAIL — `KOBOLD_ENEMY_STATS.kill_xp`/`HOBGOBLIN_ENEMY_STATS.kill_xp`/
  `GOBLIN_ENEMY_STATS.kill_xp`/`ORC_ENEMY_STATS.kill_xp` don't exist yet;
  `test_ruined_fortress_is_a_three_star_site_at_its_documented_position`
  still has the old `kill_xp` line at this point if you haven't deleted it
  yet (delete it as part of this red step, not the green step); the
  two-Goblin test still asserts the old `20.0`.

- [ ] **Step 3: Move kill_xp onto each monster (GREEN, part 1)**

  Edit `scripts/autoload/game_session.gd`.

  Add `"kill_xp": 5,` to `GOBLIN_ENEMY_STATS` (after `"hit_chance": 0.3,`):
  ```gdscript
  const GOBLIN_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.goblin",
  	"attack_name_key": "battle.enemy.goblin.attack",
  	"max_health": 13,
  	"attack_damage": 2,
  	"hit_chance": 0.3,
  	"kill_xp": 5,
  	"loot_id": "goblin",
  }
  ```

  Add `"kill_xp": 10,` to `ORC_ENEMY_STATS`:
  ```gdscript
  const ORC_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.orc",
  	"attack_name_key": "battle.enemy.orc.attack",
  	"max_health": 22,
  	"attack_damage": 3,
  	"hit_chance": 0.5,
  	"kill_xp": 10,
  	"loot_id": "orc",
  }
  ```

  Add `"kill_xp": 3,` to `KOBOLD_ENEMY_STATS`:
  ```gdscript
  const KOBOLD_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.kobold",
  	"attack_name_key": "battle.enemy.kobold.attack",
  	"max_health": 6,
  	"attack_damage": 1,
  	"hit_chance": 0.25,
  	"kill_xp": 3,
  	"loot_id": "kobold",
  }
  ```

  Add `"kill_xp": 20,` to `HOBGOBLIN_ENEMY_STATS`:
  ```gdscript
  const HOBGOBLIN_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.hobgoblin",
  	"attack_name_key": "battle.enemy.hobgoblin.attack",
  	"max_health": 30,
  	"attack_damage": 4,
  	"hit_chance": 0.6,
  	"kill_xp": 20,
  	"loot_id": "hobgoblin",
  }
  ```

  Remove the now-redundant `"kill_xp": N,` line (and its preceding `# XP:
  ...` comment line) from each of the three `EXPEDITIONS` entries
  (`goblin_camp`, `orc_outpost`, `ruined_fortress`), keeping `"clear_xp"`.
  For example, `goblin_camp` changes from:
  ```gdscript
  		"difficulty": 1,
  		# XP: 5 for a Goblin kill, 10 for clearing its site (see the campaign
  		# progression design doc). BattleController/Battlefield read these
  		# rather than hard-coding the values a second time.
  		"kill_xp": 5,
  		"clear_xp": 10,
  ```
  to:
  ```gdscript
  		"difficulty": 1,
  		# Clear XP: 10 for clearing its site (see the campaign progression
  		# design doc). Kill XP now lives on each enemy's own *_ENEMY_STATS
  		# const instead — see GOBLIN_ENEMY_STATS.kill_xp.
  		"clear_xp": 10,
  ```
  Apply the equivalent edit to `orc_outpost` (comment: "Clear XP: 20 for
  clearing its site. Kill XP lives on GOBLIN_ENEMY_STATS/ORC_ENEMY_STATS
  depending on which composition resolves.") and `ruined_fortress` (comment:
  "Clear XP: 30 for clearing the site. Kill XP lives on each composition
  option's own enemy stats — see the reward table in
  docs/plans/2026-08-08-monster-tiers-and-weighted-encounters/08-per-monster-kill-xp.md.").

- [ ] **Step 4: Thread kill_xp through Unit and BattleController (GREEN, part 2)**

  Edit `scripts/battle/unit.gd` — add a new field and constructor parameter
  (a trailing param, so no existing call site that relies on defaults
  breaks):
  ```gdscript
  var defense: int
  var resistance: int
  # XP awarded to the party when this unit is the one defeated (see
  # GameSession.*_ENEMY_STATS.kill_xp). 0 and unused for player-side units.
  var kill_xp: int = 0


  func _init(
  	p_grid_position: Vector2i,
  	p_color: Color,
  	p_side: int = 0,
  	p_move_range: int = 1,
  	p_max_health: int = 3,
  	p_damage_min: int = 1,
  	p_damage_max: int = 1,
  	p_hit_chance: float = 1.0,
  	p_attack_name: String = "Attack",
  	p_adventurer_id: String = "",
  	p_defense: int = 0,
  	p_resistance: int = 0,
  	p_kill_xp: int = 0
  ) -> void:
  	grid_position = p_grid_position
  	color = p_color
  	side = p_side
  	move_range = p_move_range
  	moves_remaining = p_move_range
  	max_health = p_max_health
  	health = p_max_health
  	damage_min = p_damage_min
  	damage_max = p_damage_max
  	hit_chance = p_hit_chance
  	attack_name = p_attack_name
  	adventurer_id = p_adventurer_id
  	defense = p_defense
  	resistance = p_resistance
  	kill_xp = p_kill_xp
  ```

  Edit `scripts/battle/battle_controller.gd` — the enemy-spawning loop in
  `_ready()` currently reads (around line 84-90):
  ```gdscript
  	var enemy_count: int = enemy_stats.get("count", 1)
  	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
  		units.append(UnitScript.new(
  			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
  			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.attack_damage, enemy_stats.hit_chance,
  			tr(enemy_stats.attack_name_key)
  		))
  ```
  Change the `UnitScript.new(...)` call to also pass kill_xp (positionally
  after the existing 9 args, with the existing implicit
  adventurer_id/defense/resistance defaults now spelled out explicitly,
  since GDScript positional calls can't skip over defaults to reach a later
  one):
  ```gdscript
  	var enemy_count: int = enemy_stats.get("count", 1)
  	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
  		units.append(UnitScript.new(
  			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
  			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.attack_damage, enemy_stats.hit_chance,
  			tr(enemy_stats.attack_name_key), "", 0, 0, enemy_stats.get("kill_xp", 0)
  		))
  ```

  Edit `scripts/battle/battlefield.gd` — `_award_kill_xp()` currently reads
  (around line 159-163):
  ```gdscript
  func _award_kill_xp(unit) -> void:
  	if _kill_xp_awarded_units.has(unit):
  		return
  	_kill_xp_awarded_units.append(unit)
  	_award_party_xp(_current_expedition().get("kill_xp", 0))
  ```
  Change the last line to read the killed unit's own kill_xp instead of the
  site's:
  ```gdscript
  func _award_kill_xp(unit) -> void:
  	if _kill_xp_awarded_units.has(unit):
  		return
  	_kill_xp_awarded_units.append(unit)
  	_award_party_xp(unit.kill_xp)
  ```
  (`_award_clear_xp()`, a few lines below, is untouched — it still reads
  `_current_expedition().get("clear_xp", 0)`, since `clear_xp` stays
  site-level.)

- [ ] **Step 5: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 6: Manual verification**

  This step has no new clickable UI, so automated verification is the
  primary evidence. As a spot check, run `make simulate RUNS=20` (or the
  project's headless battle runner) and confirm it still completes cleanly
  with no new "stalemate" or error outcomes — a wrong `kill_xp` type
  (e.g. accidentally reading a String) would typically surface as a runtime
  type error during a kill, not a silent wrong number, so a clean simulator
  run is meaningful evidence here.

- [ ] **Step 7: Commit**

  ```bash
  git add scripts/autoload/game_session.gd scripts/battle/unit.gd \
    scripts/battle/battle_controller.gd scripts/battle/battlefield.gd \
    tests/unit/test_game_session.gd tests/unit/test_battlefield.gd
  git commit -m "balance: move kill XP onto each monster so Ruined Fortress reward scales with danger, not headcount"
  ```

## Merge back to main

Get the user's signoff, then:

```bash
git checkout main
git merge per-monster-kill-xp
git branch -d per-monster-kill-xp
```

## Follow-up: design doc

After this merges, `docs/plans/first-playable-campaign/game-design.md`'s
loot/XP paragraphs (updated in Step 7 of the main plan) should gain one
sentence noting kill XP is now looked up per monster type rather than per
site, and the Ruined Fortress's reward-scales-with-danger table above
should replace any lingering "15 XP per kill" framing. Fold this into
whichever session does the final documentation pass rather than treating it
as blocking this step's merge.
