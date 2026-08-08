# Step 2: Add Kobold and Hobgoblin combat stats

**Depends on:** Step 1 merged (so `GOBLIN_ENEMY_STATS`/`ORC_ENEMY_STATS` are
already at their rebalanced values, matching the tiering these two sit
between).

**Produces:** `GameSession.KOBOLD_ENEMY_STATS` and
`GameSession.HOBGOBLIN_ENEMY_STATS` constants, plus their localization
strings. `GameSession.ENEMY_LOOT_TABLES` already has `"kobold"` and
`"hobgoblin"` rows (see `game_session.gd:112-117`) — this step only adds
their *combat* stats. Neither monster is fightable yet; that's Step 4.

## Setup

```bash
git checkout main && git pull
git checkout -b add-kobold-and-hobgoblin
```

## Steps

- [ ] **Step 1: Write the failing test (RED)**

  Add to `tests/unit/test_game_session.gd` (near the other
  `GOBLIN_ENEMY_STATS`/`ORC_ENEMY_STATS` assertions, e.g. next to the
  existing `loot_id` checks around line 2213):

  ```gdscript
  func test_kobold_enemy_stats_are_the_weakest_tier() -> void:
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.max_health, 6)
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.attack_damage, 1)
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.hit_chance, 0.25)
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.name_key, "battle.enemy.kobold")
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.attack_name_key, "battle.enemy.kobold.attack")
  	assert_eq(GameSessionScript.KOBOLD_ENEMY_STATS.loot_id, "kobold")


  func test_hobgoblin_enemy_stats_are_the_strongest_tier() -> void:
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.max_health, 30)
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.attack_damage, 4)
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.hit_chance, 0.6)
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.name_key, "battle.enemy.hobgoblin")
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.attack_name_key, "battle.enemy.hobgoblin.attack")
  	assert_eq(GameSessionScript.HOBGOBLIN_ENEMY_STATS.loot_id, "hobgoblin")


  func test_kobold_and_hobgoblin_loot_ids_already_have_loot_table_rows() -> void:
  	assert_true(GameSessionScript.ENEMY_LOOT_TABLES.has(GameSessionScript.KOBOLD_ENEMY_STATS.loot_id))
  	assert_true(GameSessionScript.ENEMY_LOOT_TABLES.has(GameSessionScript.HOBGOBLIN_ENEMY_STATS.loot_id))
  ```

- [ ] **Step 2: Run it and confirm it fails**

  Run: `make test`
  Expected: FAIL with a parse/identifier error — `KOBOLD_ENEMY_STATS` and
  `HOBGOBLIN_ENEMY_STATS` don't exist on `GameSessionScript` yet.

- [ ] **Step 3: Add the constants and localization strings (GREEN)**

  Edit `scripts/autoload/game_session.gd` — insert immediately after
  `ORC_ENEMY_STATS` (after its closing `}` around line 60), before the
  `STAR_ENEMY_COMPOSITIONS` comment block:

  ```gdscript
  const KOBOLD_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.kobold",
  	"attack_name_key": "battle.enemy.kobold.attack",
  	"max_health": 6,
  	"attack_damage": 1,
  	"hit_chance": 0.25,
  	"loot_id": "kobold",
  }
  const HOBGOBLIN_ENEMY_STATS: Dictionary = {
  	"name_key": "battle.enemy.hobgoblin",
  	"attack_name_key": "battle.enemy.hobgoblin.attack",
  	"max_health": 30,
  	"attack_damage": 4,
  	"hit_chance": 0.6,
  	"loot_id": "hobgoblin",
  }
  ```

  Edit `translations/en.tres` — insert two new lines right after
  `"battle.enemy.orc.attack": "War Axe",` (line 161):

  ```
  "battle.enemy.kobold": "Kobold",
  "battle.enemy.kobold.attack": "Rusty Dagger",
  "battle.enemy.hobgoblin": "Hobgoblin",
  "battle.enemy.hobgoblin.attack": "Two-Handed Sword",
  ```

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  Since neither monster is fightable yet, verify from the editor instead of
  play-testing: run `make editor`, open the Script tab on
  `game_session.gd`, and confirm `KOBOLD_ENEMY_STATS`/`HOBGOBLIN_ENEMY_STATS`
  appear with no red squiggles (syntax is valid) — or simply rely on `make
  check` passing, which already proves the script parses and the constants
  are readable. No screenshot needed for this step.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/autoload/game_session.gd translations/en.tres tests/unit/test_game_session.gd
  git commit -m "feat: add Kobold and Hobgoblin combat stats"
  ```

## Merge back to main

Get the user's signoff (there's no player-visible change yet, so this can
just be "tests pass"), then:

```bash
git checkout main
git merge add-kobold-and-hobgoblin
git branch -d add-kobold-and-hobgoblin
```
