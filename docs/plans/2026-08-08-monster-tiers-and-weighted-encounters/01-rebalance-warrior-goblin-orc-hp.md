# Step 1: Rebalance Warrior/Goblin/Orc HP and damage

**Depends on:** nothing (first step).

**Produces:** Warrior base max health 10; Goblin 13 HP / 2 damage; Orc 22 HP
/ 3 damage. Hit chances (Goblin 0.3, Orc 0.5) and every other stat are
unchanged. See index.md's "Why these numbers" section for the derivation.

## Setup

```bash
git checkout main && git pull
git checkout -b rebalance-warrior-goblin-orc-hp
```

## Steps

- [ ] **Step 1: Update the failing test expectations first (RED)**

  Edit `tests/unit/test_game_session.gd`:

  Around line 392-394 (goblin_camp expedition's inline enemy):
  ```gdscript
  	assert_eq(record.enemy.max_health, 13)
  	assert_eq(record.enemy.attack_damage, 2)
  	assert_eq(record.enemy.hit_chance, 0.3)
  ```

  Around line 405-407 (orc_outpost expedition's inline enemy):
  ```gdscript
  	assert_eq(record.enemy.max_health, 22)
  	assert_eq(record.enemy.attack_damage, 3)
  	assert_eq(record.enemy.hit_chance, 0.5)
  ```

  Around line 518-526 (`test_get_expedition_returns_a_record_that_can_be_mutated_without_affecting_the_catalog`):
  ```gdscript
  	assert_eq(
  		second_record.enemy.max_health,
  		13,
  		"Mutating a nested dictionary in a returned record must not affect the catalog"
  	)
  ```

  Around line 768 (default warrior stats):
  ```gdscript
  	assert_eq(warrior.stats.max_health, 10)
  ```

  Around line 1387 (`test_each_level_gained_adds_one_max_health_and_ten_skill_points`):
  ```gdscript
  	assert_eq(warrior.stats.max_health, 11, "Leveling once should add exactly one max health")
  ```

  Around line 1492-1502 (`test_get_effective_max_health_reflects_leveling`):
  ```gdscript
  	assert_eq(session.get_effective_max_health("warrior_001"), 10)
  	...
  	assert_eq(session.get_effective_max_health("warrior_001"), 11)
  ```
  (Keep the surrounding leveling calls between the two assertions unchanged
  — only the two expected numbers change, from 3/4 to 10/11.)

  Edit `tests/unit/test_battle_controller.gd`:

  Around line 256 (`test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count`):
  ```gdscript
  	assert_eq(warrior.max_health, 10)
  ```

  Same test, around line 265-268 (the goblin it spawns against):
  ```gdscript
  	assert_eq(goblin.max_health, 13)
  	assert_eq(goblin.damage_min, 2)
  	assert_eq(goblin.damage_max, 2)
  	assert_eq(goblin.hit_chance, 0.3)
  ```

  Around line 288-291 (`test_ready_builds_one_orc_when_the_orc_outpost_resolves_to_orcs`):
  ```gdscript
  	assert_eq(orc.max_health, 22)
  	assert_eq(orc.damage_min, 3)
  	assert_eq(orc.damage_max, 3)
  	assert_eq(orc.hit_chance, 0.5)
  ```

  Around line 311-314 (`test_ready_builds_two_goblins_when_the_orc_outpost_resolves_to_goblins`, inside the `for index in 2:` loop):
  ```gdscript
  		assert_eq(goblin.max_health, 13)
  		assert_eq(goblin.damage_min, 2)
  		assert_eq(goblin.damage_max, 2)
  		assert_eq(goblin.hit_chance, 0.3)
  ```

  Around line 331-334 (`test_ready_builds_one_goblin_when_the_goblin_camp_is_selected`):
  ```gdscript
  	assert_eq(goblin.max_health, 13)
  	assert_eq(goblin.damage_min, 2)
  	assert_eq(goblin.damage_max, 2)
  	assert_eq(goblin.hit_chance, 0.3)
  ```

  Around line 354-355 (`test_ready_builds_the_player_unit_from_the_first_partys_effective_stats`):
  ```gdscript
  	assert_eq(warrior.max_health, 11, "One level up should have added one max health")
  	assert_eq(warrior.health, 11, "A fresh unit starts at full (derived) health")
  ```

  Edit `tests/unit/test_battlefield.gd`:

  Around line 139 (`test_portrait_panel_shows_one_row_per_fielded_party_member`):
  ```gdscript
  		assert_eq(health_label.text, "10/10")
  ```

  Around line 253 (`test_ready_lists_each_living_enemys_health`):
  ```gdscript
  		assert_eq(label.text, tr("battle.status.health") % [tr("battle.side.enemy"), 13, 13])
  ```

  Around line 526-527 (`test_a_level_up_from_kill_xp_raises_the_active_units_max_and_current_health`):
  ```gdscript
  	assert_eq(units.warrior.max_health, 11, "The active unit's max health must rise immediately on a mid-battle level-up")
  	assert_eq(units.warrior.health, 11, "The active unit's current health must rise by the same amount as max health")
  ```

- [ ] **Step 2: Run the suite and confirm these tests fail**

  Run: `make test`
  Expected: FAIL — every assertion touched above fails against the current
  (3/5-HP) production values. No other test should newly fail; if one does,
  its hardcoded value was missed and needs the same treatment (search again
  with `grep -n "max_health\|hit_chance\|attack_damage" tests/unit/*.gd` and
  compare against the numbers in this step).

- [ ] **Step 3: Update the production constants (GREEN)**

  Edit `scripts/autoload/game_session.gd`:

  Change the `goblin_camp` expedition's inline `enemy` sub-dict (around line
  18-25):
  ```gdscript
  		"enemy": {
  			"name_key": "battle.enemy.goblin",
  			"attack_name_key": "battle.enemy.goblin.attack",
  			"max_health": 13,
  			"attack_damage": 2,
  			"hit_chance": 0.3,
  			"count": 1,
  		},
  ```

  Change the `orc_outpost` expedition's inline `enemy` sub-dict (around line
  35-42):
  ```gdscript
  		"enemy": {
  			"name_key": "battle.enemy.orc",
  			"attack_name_key": "battle.enemy.orc.attack",
  			"max_health": 22,
  			"attack_damage": 3,
  			"hit_chance": 0.5,
  			"count": 1,
  		},
  ```

  Change `GOBLIN_ENEMY_STATS` (around line 45-52):
  ```gdscript
  const GOBLIN_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.goblin",
  	"attack_name_key": "battle.enemy.goblin.attack",
  	"max_health": 13,
  	"attack_damage": 2,
  	"hit_chance": 0.3,
  	"loot_id": "goblin",
  }
  ```

  Change `ORC_ENEMY_STATS` (around line 53-60):
  ```gdscript
  const ORC_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.orc",
  	"attack_name_key": "battle.enemy.orc.attack",
  	"max_health": 22,
  	"attack_damage": 3,
  	"hit_chance": 0.5,
  	"loot_id": "orc",
  }
  ```

  Change the Warrior's base HP default (around line 133):
  ```gdscript
  var BASE_MAX_HEALTH: int = 10
  ```

  Edit `scripts/autoload/game_config.gd` — change `DEFAULTS.combat.base_max_health`:
  ```gdscript
  		"base_max_health": 10,
  ```

  Edit `config/game_config.json` — change `combat.base_max_health`:
  ```json
  		"base_max_health": 10,
  ```

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  Run `make play`, use the F9 debug menu's "Goblin Camp Battle" scenario,
  and confirm in the battle HUD:
  - The Warrior's portrait shows `10/10` health.
  - The enemy health line shows the Goblin at `13/13`.

  Then try "Orc Outpost Battle" and confirm the Orc (or two Goblins,
  depending on the random roll — retry if needed to see the Orc) shows
  `22/22`.

  Fight the Orc Outpost battle to completion at least once without Super
  Power and confirm it feels like a real, multi-round fight rather than a
  one-shot in either direction (roughly matching the ~8-round estimate in
  index.md's table).

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/autoload/game_session.gd scripts/autoload/game_config.gd \
    config/game_config.json tests/unit/test_game_session.gd \
    tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd
  git commit -m "balance: rebalance Warrior/Goblin/Orc HP and damage around a 10 HP Warrior"
  ```

## Merge back to main

Get the user's manual-verification signoff on Step 5 above, then:

```bash
git checkout main
git merge rebalance-warrior-goblin-orc-hp
git branch -d rebalance-warrior-goblin-orc-hp
```
