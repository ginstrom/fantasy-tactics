# Step 4: Ranged composition counts and the Ruined Fortress three-star site

**Depends on:** Steps 1-3 merged (rebalanced Goblin/Orc stats, Kobold/
Hobgoblin stats, and 8-slot battlefield capacity all need to exist first).

**Produces:**
- `STAR_ENEMY_COMPOSITIONS` options gain a `count_min`/`count_max` range
  instead of a single fixed `count` (tiers 1 and 2 get `count_min ==
  count_max`, so their resolved behavior is unchanged).
- `STAR_ENEMY_COMPOSITIONS[3]` — which today holds unreachable placeholder
  data ("3 Goblins or 2 Orcs", see `game_session.gd:76-79` and
  `test_game_session.gd:498-502`) — is replaced with the real four-option
  spec: 4-8 Kobolds, 3-6 Goblins, 2-4 Orcs, or 1-3 Hobgoblins.
- A new `EXPEDITIONS["ruined_fortress"]` template at difficulty 3, so the
  site is a real, enterable World Map location (not yet reachable through
  normal vacancy refills — that's Step 5 — but directly enterable today via
  `GameSession.enter_encounter(GameSession.RUINED_FORTRESS_ID)`, same as
  the debug menu will use in Step 6).

## Setup

```bash
git checkout main && git pull
git checkout -b three-star-ruined-fortress
```

## Steps

- [ ] **Step 1: Write the failing tests for the new composition (RED)**

  Edit `tests/unit/test_game_session.gd` — replace the existing
  placeholder test (around line 498-502):

  ```gdscript
  func test_three_star_tier_offers_kobolds_goblins_orcs_or_hobgoblins() -> void:
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].count_min, 4)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].count_max, 8)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].enemy.name_key, "battle.enemy.kobold")
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].count_min, 3)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].count_max, 6)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].enemy.name_key, "battle.enemy.goblin")
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].count_min, 2)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].count_max, 4)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][2].enemy.name_key, "battle.enemy.orc")
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].count_min, 1)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].count_max, 3)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][3].enemy.name_key, "battle.enemy.hobgoblin")


  func test_tier_one_and_two_compositions_still_use_their_original_fixed_counts() -> void:
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[1][0].count_min, 1)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[1][0].count_max, 1)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][0].count_min, 2)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][0].count_max, 2)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][1].count_min, 1)
  	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[2][1].count_max, 1)


  func test_resolve_enemy_composition_rolls_the_kobold_count_within_its_range() -> void:
  	var session: Node = GameSessionScript.new()
  	autofree(session)
  	session.enemy_composition_roll = func(_option_count: int) -> int: return 0
  	session.enemy_count_roll = func(min_value: int, max_value: int) -> int:
  		assert_eq(min_value, 4)
  		assert_eq(max_value, 8)
  		return 6
  	var enemy: Dictionary = session._resolve_enemy_composition(3)
  	assert_eq(enemy.count, 6)
  	assert_eq(enemy.name_key, "battle.enemy.kobold")


  func test_resolve_enemy_composition_rolls_the_hobgoblin_count_within_its_range() -> void:
  	var session: Node = GameSessionScript.new()
  	autofree(session)
  	session.enemy_composition_roll = func(_option_count: int) -> int: return 3
  	session.enemy_count_roll = func(min_value: int, max_value: int) -> int:
  		assert_eq(min_value, 1)
  		assert_eq(max_value, 3)
  		return 2
  	var enemy: Dictionary = session._resolve_enemy_composition(3)
  	assert_eq(enemy.count, 2)
  	assert_eq(enemy.name_key, "battle.enemy.hobgoblin")
  ```

  Add tests for the new expedition template (anywhere near the other
  `get_expedition` tests):

  ```gdscript
  func test_ruined_fortress_is_a_three_star_site_at_its_documented_position() -> void:
  	var record: Dictionary = GameSession.get_expedition(GameSession.RUINED_FORTRESS_ID)
  	assert_eq(record.position, Vector2i(0, 4))
  	assert_eq(record.difficulty, 3)
  	assert_eq(record.kill_xp, 15)
  	assert_eq(record.clear_xp, 30)
  	assert_eq(record.name_key, "expedition.ruined_fortress.name")


  func test_ruined_fortress_is_not_seeded_as_an_active_encounter_on_a_fresh_campaign() -> void:
  	GameSession.reset()
  	for instance in GameSession.active_encounters:
  		assert_ne(instance.template_id, GameSession.RUINED_FORTRESS_ID)
  	assert_eq(GameSession.active_encounters.size(), 2, "A fresh campaign still starts with exactly the Goblin Camp and Orc Outpost")
  ```

- [ ] **Step 2: Run the suite and confirm these fail**

  Run: `make test`
  Expected: FAIL — `RUINED_FORTRESS_ID` doesn't exist yet, and
  `STAR_ENEMY_COMPOSITIONS`'s entries have no `count_min`/`count_max` keys
  yet (the old test this replaces would also now be gone, so there's no
  conflicting assertion left behind).

- [ ] **Step 3: Generalize the composition schema and add the real content (GREEN)**

  Edit `scripts/autoload/game_session.gd`.

  Add the new template id near the other id constants (after
  `ORC_OUTPOST_ID` around line 6):

  ```gdscript
  const RUINED_FORTRESS_ID := "ruined_fortress"
  ```

  Add the new template to `EXPEDITIONS` (after the `orc_outpost` entry's
  closing `},`, still inside the `EXPEDITIONS` dictionary, before its own
  closing `}`):

  ```gdscript
  	"ruined_fortress": {
  		"position": Vector2i(0, 4),
  		"name_key": "expedition.ruined_fortress.name",
  		"danger_key": "expedition.danger.extreme",
  		"difficulty": 3,
  		# XP: 15 per kill, 30 for clearing the site, continuing the +5/+10
  		# progression from the Goblin Camp (5/10) and Orc Outpost (10/20).
  		"kill_xp": 15,
  		"clear_xp": 30,
  		"enemy": {
  			"name_key": "battle.enemy.kobold",
  			"attack_name_key": "battle.enemy.kobold.attack",
  			"max_health": 6,
  			"attack_damage": 1,
  			"hit_chance": 0.25,
  			"count": 4,
  		},
  	},
  ```

  Replace `STAR_ENEMY_COMPOSITIONS` entirely (around line 68-80):

  ```gdscript
  const STAR_ENEMY_COMPOSITIONS: Dictionary = {
  	1: [
  		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 1},
  	],
  	2: [
  		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 2, "count_max": 2},
  		{"enemy": ORC_ENEMY_STATS, "count_min": 1, "count_max": 1},
  	],
  	3: [
  		{"enemy": KOBOLD_ENEMY_STATS, "count_min": 4, "count_max": 8},
  		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 3, "count_max": 6},
  		{"enemy": ORC_ENEMY_STATS, "count_min": 2, "count_max": 4},
  		{"enemy": HOBGOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 3},
  	],
  }
  ```

  Add the new injectable roll (next to `enemy_composition_roll`, around
  line 251):

  ```gdscript
  ## Injectable so tests can force a specific enemy count instead of
  ## depending on real randomness (see enemy_composition_roll for the same
  ## pattern). Called with the resolved composition option's
  ## (count_min, count_max).
  var enemy_count_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
  ```

  Update `_resolve_enemy_composition()` (around line 737-744) to roll the
  count instead of copying a fixed one:

  ```gdscript
  func _resolve_enemy_composition(difficulty: int) -> Dictionary:
  	var options: Array = STAR_ENEMY_COMPOSITIONS.get(difficulty, STAR_ENEMY_COMPOSITIONS[1])
  	var option: Dictionary = options[0]
  	if options.size() > 1:
  		option = options[enemy_composition_roll.call(options.size())]
  	var enemy: Dictionary = option.enemy.duplicate(true)
  	enemy["count"] = enemy_count_roll.call(option.count_min, option.count_max)
  	return enemy
  ```

  Add the new localization string to `translations/en.tres`, right after
  `"expedition.orc_outpost.name": "Orc Outpost",` (line 157):

  ```
  "expedition.ruined_fortress.name": "Ruined Fortress",
  ```

  (The design doc's `danger_key` field — `expedition.danger.low` /
  `.high` / `.extreme` — is stored but not currently read or displayed
  anywhere in the UI, matching the two existing danger keys, which also
  have no `translations/en.tres` entries today. This step keeps that
  existing gap rather than fixing it, since it's pre-existing and out of
  this plan's scope.)

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  There is no UI path to this site yet (Step 6 adds one). Verify
  programmatically instead: run `make editor`, open the Script tab, and use
  the built-in script console or a temporary `print()` in `_ready()` of any
  autoload-adjacent script to call:
  ```gdscript
  print(GameSession.get_expedition(GameSession.RUINED_FORTRESS_ID))
  ```
  and confirm it prints a dictionary with `position = (0, 4)`, `difficulty
  = 3`, `kill_xp = 15`, `clear_xp = 30`. Remove the temporary print before
  committing. (Full playable verification happens in Step 6, once there's a
  debug menu button for it.)

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/autoload/game_session.gd translations/en.tres tests/unit/test_game_session.gd
  git commit -m "feat: add the Ruined Fortress three-star site with ranged enemy counts"
  ```

## Merge back to main

Get the user's signoff on Step 5, then:

```bash
git checkout main
git merge three-star-ruined-fortress
git branch -d three-star-ruined-fortress
```
