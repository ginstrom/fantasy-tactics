# Campaign Loop Follow-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement every item in `docs/plans/campaign-loop-follow-up.md`: the persistent encampment left-nav, the World Map path-setting regression, XP-to-next-level display, the goblin/orc star-based battle balancing rework, the Parties button reposition, and the deferred Guild Hall / full-party-battles cleanup items.

**Architecture:** Godot 4 / GDScript. Two autoloads (`GameManager` for navigation, `GameSession` for durable state) with thin `Control`/`Node2D` screen scripts on top — see `docs/dev/code-map.md`. Tests are GUT (`tests/unit/test_*.gd`), run via `make test` (or `godot --headless -s addons/gut/gut_cmdln.gd -gexit`; use `-gselect=<file>` to scope a run).

**Tech Stack:** Godot 4, GDScript, GUT test framework.

## Global Constraints

- Every player-facing string is a translation key resolved via `tr()`, defined in `translations/en.tres` — never a literal in a scene or script.
- Testable randomness follows the existing `Callable`-member pattern (see `battle_controller.gd`'s `hit_roll`): a `var some_roll: Callable = func(...): return real_random(...)`, overridable per-test.
- Screens never invent or cache `GameSession` data locally; they read it fresh in `refresh()`.
- Do not remove or weaken an existing passing test unless this plan's task explicitly says to change it, and say why.
- After every task: run the file-scoped GUT command given in that task, then `make test` before committing.
- No emojis, no comments explaining *what* code does — only non-obvious *why*, matching this codebase's existing style.

---

## Milestone A: World Map path-setting regression

### Task 1: Fix "clicking the unit cancels the path" and cover the fixed behavior

**Files:**
- Modify: `scripts/world/world_map.gd`
- Test: `tests/unit/test_world_map.gd`

**Interfaces:**
- Produces: a new public `var repathing: bool = false` on `WorldMap`, and updated semantics for `_has_route_affordance()` (now also true while `repathing` is true) and `cancel_route_setting()` (now also clears `repathing`). No other file reads these.

Today, `_handle_tile_click()`'s branch for "clicked the party's own tile, already selected, already has a committed route" calls `GameSession.clear_deployed_party_route()` immediately — the reported regression. The fix: re-clicking the party while it already has a route must leave the route untouched and flip on a `repathing` flag that re-enables the hover-preview affordance (normally locked out once a route is committed), so the player sees the old route stay drawn while a new one previews. A subsequent right-click cancels the attempt (old route intact); a subsequent left-click elsewhere replaces the route via the existing "build + commit" branch (already unconditional on `tile_pos != party_position`, so no change needed there) and this flag resets.

- [ ] **Step 1: Write the failing/updated tests**

Replace the existing `test_clicking_the_party_with_a_route_again_cancels_it` (its assertions describe exactly the bug) with:

```gdscript
func test_reclicking_the_party_with_a_route_preserves_it_and_enables_repathing() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(
		GameSession.get_deployed_party_route(), [Vector2i(1, 0), Vector2i(2, 0)],
		"Reclicking the party must not clear its existing route"
	)
	assert_true(world_map.party_selected, "Party should remain selected")
	assert_true(world_map.repathing, "Reclicking a routed party should enter repathing mode")


func test_repathing_mode_previews_a_new_route_alongside_the_old_one() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(Vector2i(0, 2))
	await get_tree().process_frame

	assert_eq(world_map.hover_route, [Vector2i(0, 1), Vector2i(0, 2)])
	# Old committed route (1 segment + target + label = 3) plus the new hover
	# preview (2 segments + target + label = 3) must both be visible at once.
	assert_eq(world_map.get_node("Routes").get_child_count(), 6)


func test_right_click_during_repathing_cancels_the_attempt_and_keeps_the_old_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(Vector2i(0, 2))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(1, 0)])
	assert_false(world_map.repathing)


func test_left_click_elsewhere_during_repathing_replaces_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(Vector2i(0, 2))

	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(0, 1), Vector2i(0, 2)])
	assert_false(world_map.repathing, "Committing a new route ends repathing mode")
```

Keep `test_canceling_a_route_reenables_the_hover_affordance` as-is — it only asserts on `hover_route`, and will keep passing once `_has_route_affordance()` also honors `repathing` (see Step 3).

- [ ] **Step 2: Run to verify the new tests fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit`
Expected: the 4 new tests FAIL (old behavior clears the route / never sets `repathing`); `test_reclicking_...` fails because `GameSession.get_deployed_party_route()` is `[]` instead of `[Vector2i(1,0), Vector2i(2,0)]`.

- [ ] **Step 3: Implement the fix**

In `scripts/world/world_map.gd`, add the new state var near `hover_route`:

```gdscript
var hover_route: Array[Vector2i] = []
var repathing: bool = false
```

Update `_has_route_affordance()`:

```gdscript
func _has_route_affordance() -> bool:
	if not party_selected or not GameSession.has_deployed_party():
		return false
	return GameSession.get_deployed_party_route().is_empty() or repathing
```

Update `cancel_route_setting()`:

```gdscript
func cancel_route_setting() -> void:
	hover_route = []
	repathing = false
```

Replace the route-clearing branch inside `_handle_tile_click()`:

```gdscript
		if not GameSession.get_deployed_party_route().is_empty():
			GameSession.clear_deployed_party_route()
			hover_route = []
			_draw_routes()
			_update_highlights()
			return
```

with:

```gdscript
		if not GameSession.get_deployed_party_route().is_empty():
			# Reclicking a routed party must not discard it — it stays visible
			# while a new one can be previewed/committed (see repathing).
			repathing = true
			return
```

Finally, reset `repathing = false` at the two points a route actually changes: the "take next route step" branch and the "build + commit a new route" branch, both already inside `_handle_tile_click()`:

```gdscript
	if tile_pos == get_route_destination():
		if GameSession.take_next_route_step():
			party_position = GameSession.get_deployed_party_position()
			hover_route = []
			repathing = false
			_draw_markers()
			_draw_routes()
			_update_highlights()
			board_changed.emit()
		return

	var route := build_route(party_position, tile_pos)
	if not route.is_empty() and GameSession.set_deployed_party_route(route):
		hover_route = []
		repathing = false
		_draw_markers()
		_draw_routes()
		_update_highlights()
```

- [ ] **Step 4: Run to verify all world map tests pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit`
Expected: PASS, including the unmodified pre-existing tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/world_map.gd tests/unit/test_world_map.gd
git commit -m "fix: keep the old world map route visible while repathing"
```

---

## Milestone B: XP-to-next-level display

### Task 2: Show XP and the threshold for the next level on Unit Details

**Files:**
- Modify: `scripts/ui/unit_details.gd`, `translations/en.tres`
- Test: `tests/unit/test_unit_details.gd`, `tests/unit/test_localization.gd`

**Interfaces:**
- Consumes: `GameSession.get_level_xp_threshold(level: int) -> float` (already exists).
- Produces: no new public interface — `unit_details.stats`'s format arity grows from 4 to 5 (`[xp, xp_to_next_level, raw_attack, hit_chance_percent, effective_max_health]`).

- [ ] **Step 1: Update the failing tests**

In `tests/unit/test_unit_details.gd`, update the two `StatsLabel` assertions:

```gdscript
func test_stats_label_shows_xp_raw_and_effective_attack_and_health() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Center/VBox/StatsLabel").text,
		tr("unit_details.stats") % [0, 20, 60, 60, 3],
		"A fresh level-1 Warrior has 0/20 XP to level 2, 60 raw Attack, 60% effective hit chance, and 3 max health"
	)
	assert_true(screen.get_node("Center/VBox/StatsLabel").visible)


func test_stats_label_reflects_leveling_xp_attack_and_health_changes() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 25.5)
	GameSession.spend_attack_points(GameSession.WARRIOR_ID, 4)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Center/VBox/StatsLabel").text,
		tr("unit_details.stats") % [25, 50, 64, 64, 4],
		"25.5 XP displays floored as 25/50 to level 3; 4 spent points raise raw and effective Attack to 64; leveling once raises health to 4"
	)
```

In `tests/unit/test_localization.gd`, update the literal-copy check at line 149-151:

```gdscript
	assert_eq(
		tr("unit_details.stats") % [25, 50, 64, 64, 4],
		"XP: 25 / 50 — Attack: 64 raw / 64% hit chance — Health: 4"
	)
```

- [ ] **Step 2: Run to verify these fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit`
Expected: FAIL — format string still takes 4 args, so `%` with a 5-element array errors/mismatches.

- [ ] **Step 3: Update the translation string**

In `translations/en.tres`, change:

```
"unit_details.stats": "XP: %d — Attack: %d raw / %d%% hit chance — Health: %d",
```

to:

```
"unit_details.stats": "XP: %d / %d — Attack: %d raw / %d%% hit chance — Health: %d",
```

- [ ] **Step 4: Update `unit_details.gd`**

In `_show_adventurer()`, replace:

```gdscript
	var xp_display: int = int(floor(adventurer.progression.xp))
	var raw_attack: int = adventurer.stats.attack
	var hit_chance_percent := int(round(GameSession.get_effective_hit_chance(adventurer_id) * 100.0))
	var effective_max_health: int = GameSession.get_effective_max_health(adventurer_id)
	stats_label.text = tr("unit_details.stats") % [xp_display, raw_attack, hit_chance_percent, effective_max_health]
```

with:

```gdscript
	var xp_display: int = int(floor(adventurer.progression.xp))
	var xp_to_next_level: int = int(GameSession.get_level_xp_threshold(adventurer["level"] + 1))
	var raw_attack: int = adventurer.stats.attack
	var hit_chance_percent := int(round(GameSession.get_effective_hit_chance(adventurer_id) * 100.0))
	var effective_max_health: int = GameSession.get_effective_max_health(adventurer_id)
	stats_label.text = (
		tr("unit_details.stats")
		% [xp_display, xp_to_next_level, raw_attack, hit_chance_percent, effective_max_health]
	)
```

- [ ] **Step 5: Run to verify all pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit` then `-gselect=test_localization.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/unit_details.gd translations/en.tres tests/unit/test_unit_details.gd tests/unit/test_localization.gd
git commit -m "feat: show XP needed for the next level on Unit Details"
```

---

## Milestone C: Battle balancing — the star system

### Task 3: Add the star-tier enemy-composition system to `GameSession`

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `GameSession.enemy_composition_roll: Callable` (test-overridable, signature `func(option_count: int) -> int`), `GameSession.STAR_ENEMY_COMPOSITIONS: Dictionary` (keyed by star tier `1/2/3`, each an `Array` of `{"enemy": Dictionary, "count": int}`), and `GameSession._resolve_enemy_composition(difficulty: int) -> Dictionary` returning an `enemy`-shaped dict (existing shape, e.g. `{name_key, attack_name_key, max_health, attack_damage, hit_chance, count}`). `enter_encounter()`'s behavior changes: it now re-resolves and overwrites the targeted active instance's `enemy` field every call.
- Consumes: nothing new.

Per the design doc: 1 star = 1 goblin (deterministic); 2 stars = 2 goblins **or** 1 orc (random); 3 stars = 3 goblins **or** 2 orcs (random, not yet used by any expedition but defined for future content). The template `EXPEDITIONS` dicts keep a fixed, deterministic "documented" `enemy` value each (used by direct/no-instance lookups); the random pick only ever applies to a live *active instance*, resolved at `enter_encounter()` time so a test can force it deterministically (mirroring `battle_controller.hit_roll`).

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_game_session.gd`, update the two enemy-count tests (Goblin Camp is now 1-star/1-goblin; Orc Outpost's static template default becomes 1 orc — the 2-star tier's "orc" option):

```gdscript
func test_get_expedition_includes_the_enemy_count_for_the_goblin_camp() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)

	assert_eq(record.enemy.count, 1, "The goblin camp is a one-star site: a single goblin")


func test_get_expedition_includes_the_enemy_count_for_the_orc_outpost() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var record: Dictionary = session.get_expedition(GameSessionScript.ORC_OUTPOST_ID)

	assert_eq(record.enemy.count, 1, "The orc outpost's documented template default is a single orc")
```

Add new tests covering the random resolution (append near the existing expedition tests):

```gdscript
## Task: star-tier enemy composition. A one-star site has only one possible
## composition, so it must never consult the roll callable at all.
func test_one_star_site_always_resolves_to_a_single_goblin_regardless_of_the_roll() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int:
		fail_test("A one-star site must not roll for its composition")
		return 0

	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	assert_eq(record.enemy.count, 1)
	assert_eq(record.enemy.name_key, "battle.enemy.goblin")


func test_two_star_site_forced_to_option_zero_resolves_to_two_goblins() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0

	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)
	assert_eq(record.enemy.count, 2)
	assert_eq(record.enemy.name_key, "battle.enemy.goblin")


func test_two_star_site_forced_to_option_one_resolves_to_one_orc() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1

	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	var record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)
	assert_eq(record.enemy.count, 1)
	assert_eq(record.enemy.name_key, "battle.enemy.orc")


func test_reentering_an_active_instance_rerolls_its_composition() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	assert_eq(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).enemy.count, 2)

	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)

	assert_eq(GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).enemy.count, 1)


func test_three_star_tier_defines_three_goblins_or_two_orcs_for_future_use() -> void:
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].count, 3)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][0].enemy.name_key, "battle.enemy.goblin")
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].count, 2)
	assert_eq(GameSessionScript.STAR_ENEMY_COMPOSITIONS[3][1].enemy.name_key, "battle.enemy.orc")
```

- [ ] **Step 2: Run to verify failures**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit`
Expected: FAIL — `enemy_composition_roll`/`STAR_ENEMY_COMPOSITIONS` don't exist yet; counts are still 2/3.

- [ ] **Step 3: Implement in `scripts/autoload/game_session.gd`**

Add shared enemy species stat blocks and the star-tier composition table near the top-level consts (after `EXPEDITIONS`):

```gdscript
const GOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.goblin",
	"attack_name_key": "battle.enemy.goblin.attack",
	"max_health": 3,
	"attack_damage": 1,
	"hit_chance": 0.3,
}
const ORC_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.orc",
	"attack_name_key": "battle.enemy.orc.attack",
	"max_health": 5,
	"attack_damage": 2,
	"hit_chance": 0.5,
}
# Star tier -> possible enemy compositions for an active instance at that
# tier (see docs/plans/campaign-loop-follow-up.md's battle balancing
# section). Tier 1 has one deterministic option; tiers 2-3 randomly resolve
# to one of two options each time an instance is entered (see
# enemy_composition_roll/_resolve_enemy_composition/enter_encounter) so
# three orcs can no longer gang up on a level-1 party. Goblins-first
# ordering in each tier's option list matches the design doc's phrasing.
const STAR_ENEMY_COMPOSITIONS: Dictionary = {
	1: [
		{"enemy": GOBLIN_ENEMY_STATS, "count": 1},
	],
	2: [
		{"enemy": GOBLIN_ENEMY_STATS, "count": 2},
		{"enemy": ORC_ENEMY_STATS, "count": 1},
	],
	3: [
		{"enemy": GOBLIN_ENEMY_STATS, "count": 3},
		{"enemy": ORC_ENEMY_STATS, "count": 2},
	],
}
```

Update the two `EXPEDITIONS` templates' `enemy` fields to their new documented defaults (Goblin Camp: 1 goblin; Orc Outpost: 1 orc, the 2-star tier's orc option):

```gdscript
		"enemy": {
			"name_key": "battle.enemy.goblin",
			"attack_name_key": "battle.enemy.goblin.attack",
			"max_health": 3,
			"attack_damage": 1,
			"hit_chance": 0.3,
			"count": 1,
		},
```

(for `goblin_camp`, replacing its existing `"count": 2`), and

```gdscript
		"enemy": {
			"name_key": "battle.enemy.orc",
			"attack_name_key": "battle.enemy.orc.attack",
			"max_health": 5,
			"attack_damage": 2,
			"hit_chance": 0.5,
			"count": 1,
		},
```

(for `orc_outpost`, replacing its existing `"count": 3"`).

Add the roll callable as an instance var, near `selected_encounter`:

```gdscript
# Injectable so tests can force a specific composition (see hit_roll on
# BattleController for the same pattern) instead of depending on real
# randomness. Never reset by reset() — every call site that needs a specific
# outcome sets this immediately before its own enter_encounter() call.
var enemy_composition_roll: Callable = func(option_count: int) -> int: return randi() % option_count
```

Add the resolver and wire it into `enter_encounter()`:

```gdscript
func _resolve_enemy_composition(difficulty: int) -> Dictionary:
	var options: Array = STAR_ENEMY_COMPOSITIONS.get(difficulty, STAR_ENEMY_COMPOSITIONS[1])
	var option: Dictionary = options[0]
	if options.size() > 1:
		option = options[enemy_composition_roll.call(options.size())]
	var enemy: Dictionary = option.enemy.duplicate(true)
	enemy["count"] = option.count
	return enemy


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id
	var instance_index := _get_active_encounter_index(encounter_id)
	if instance_index != -1:
		active_encounters[instance_index].enemy = _resolve_enemy_composition(
			active_encounters[instance_index].difficulty
		)
```

- [ ] **Step 4: Run to verify all game_session tests pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: rebalance enemy counts with a random star-tier composition system"
```

### Task 4: Update battle/battlefield/full-loop tests for the new compositions

**Files:**
- Modify: `tests/unit/test_battle_controller.gd`, `tests/unit/test_battlefield.gd`, `tests/unit/test_first_campaign_ui_flow.gd`

**Interfaces:**
- Consumes: `GameSession.enemy_composition_roll` and `_setup_orc_outpost_battle()` (extended below) from Task 3.

Goblin Camp fielding only 1 enemy (was 2) and Orc Outpost never fielding a fixed 3 (was 3, now 1 or 2 at random) breaks several hard-coded assumptions. This task fixes each one.

- [ ] **Step 1: `tests/unit/test_battle_controller.gd` — fix the three composition tests**

Replace `test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count`'s enemy portion (it uses the no-selected-encounter fallback, which now resolves to Goblin Camp's 1-goblin template default):

```gdscript
func test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_eq(controller.units.size(), 2, "One Warrior (fallback) plus one goblin")
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	assert_not_null(warrior, "Warrior should spawn at the first player start position")
	assert_eq(warrior.side, BattleControllerScript.Side.PLAYER)
	assert_eq(warrior.max_health, 3)
	assert_eq(warrior.move_range, 3)
	assert_eq(warrior.attack_damage, 2)
	assert_eq(warrior.hit_chance, 0.6)

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin, "A goblin should spawn at the first enemy start position")
	assert_eq(goblin.side, BattleControllerScript.Side.ENEMY)
	assert_eq(goblin.max_health, 3)
	assert_eq(goblin.attack_damage, 1)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))
```

Replace `test_ready_builds_three_orcs_when_the_orc_outpost_is_selected` with two deterministic tests covering both random branches:

```gdscript
func test_ready_builds_one_orc_when_the_orc_outpost_resolves_to_orcs() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The orc-outpost's orc option fields one orc")

	var orc = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(orc)
	assert_eq(orc.side, BattleControllerScript.Side.ENEMY)
	assert_eq(orc.max_health, 5)
	assert_eq(orc.attack_damage, 2)
	assert_eq(orc.hit_chance, 0.5)
	assert_eq(orc.attack_name, tr("battle.enemy.orc.attack"))


func test_ready_builds_two_goblins_when_the_orc_outpost_resolves_to_goblins() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 2, "The orc-outpost's goblins option fields two goblins")

	for index in 2:
		var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[index])
		assert_not_null(goblin)
		assert_eq(goblin.max_health, 3)
		assert_eq(goblin.attack_damage, 1)
		assert_eq(goblin.hit_chance, 0.3)
```

Replace `test_ready_builds_two_goblins_when_the_goblin_camp_is_selected` (Goblin Camp is now single-enemy):

```gdscript
func test_ready_builds_one_goblin_when_the_goblin_camp_is_selected() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The goblin camp should field one goblin")

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin)
	assert_eq(goblin.max_health, 3)
	assert_eq(goblin.attack_damage, 1)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))
```

- [ ] **Step 2: `tests/unit/test_battlefield.gd` — add a forced-roll param and fix three tests**

Extend `_setup_orc_outpost_battle()`:

```gdscript
func _setup_orc_outpost_battle(roll_override: Callable = Callable()) -> Node2D:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	if roll_override.is_valid():
		GameSession.enemy_composition_roll = roll_override
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	return battlefield
```

Replace `test_ready_lists_each_living_enemys_health` and `test_enemy_health_list_drops_a_defeated_enemy` (they previously depended on the fallback path's Goblin Camp default, which is now single-enemy — redirect both to a deterministic two-goblin Orc Outpost battle so their original two-enemy assertions still hold unchanged):

```gdscript
func test_ready_lists_each_living_enemys_health() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.enemy_health.get_child_count(), 2)
	for label in battlefield.enemy_health.get_children():
		assert_eq(label.text, tr("battle.status.health") % [tr("battle.side.enemy"), 3, 3])


func test_enemy_health_list_drops_a_defeated_enemy() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.take_damage(goblin.max_health)
	battlefield.grid.units.erase(goblin)

	battlefield._update_health_labels()

	assert_eq(battlefield.enemy_health.get_child_count(), 1)
```

Replace `test_defeating_two_enemies_in_one_battle_awards_kill_xp_for_each` (Goblin Camp can no longer field two enemies; use the Orc Outpost's forced two-goblin option — kill_xp is a flat per-site value, so it's now 10 per kill, 20 total):

```gdscript
## Regression test for the finding that _award_kill_xp() used to be guarded
## by a single "already awarded this battle" boolean, which silently
## swallowed kill XP for every enemy after the first in a multi-enemy
## battle. enemy_defeated now fires once per defeated unit and the guard
## tracks awarded units individually, so both enemies' kills must each pay
## out their kill_xp. Uses the Orc Outpost forced to its two-goblin option
## since Goblin Camp is now a single-enemy (one-star) site.
func test_defeating_two_enemies_in_one_battle_awards_kill_xp_for_each() -> void:
	var battlefield := _setup_orc_outpost_battle(func(_option_count: int) -> int: return 0)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var first_enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var second_enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[1])
	first_enemy.grid_position = warrior.grid_position + Vector2i(1, 0)
	first_enemy.health = 1
	second_enemy.grid_position = warrior.grid_position + Vector2i(0, 1)
	second_enemy.health = 1
	battlefield.grid.selected_unit = warrior
	battlefield.grid.hit_roll = func() -> float: return 0.0

	battlefield.grid.try_attack_selected_unit(first_enemy.grid_position)
	warrior.has_acted = false
	battlefield.grid.try_attack_selected_unit(second_enemy.grid_position)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		20.0,
		"Defeating both enemies in one battle should award kill_xp (10) twice, not once"
	)
```

- [ ] **Step 3: `tests/unit/test_first_campaign_ui_flow.gd` — simplify the full-loop test to one goblin**

Replace the battle section of `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward` (from the `# Complete battle:` comment through the `assert_eq(GameSession.gold, 0, ...)` line) with:

```gdscript
	# Complete battle: defeat the goblin via the real board-click path (not
	# the private outcome hook other battle tests use directly), so this test
	# also proves a real kill still drives the win pipeline through to
	# GameManager.complete_battle(). The goblin camp is a one-star site and
	# now fields a single goblin (see GameSession.STAR_ENEMY_COMPOSITIONS).
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.apply_super_power()

	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
	var goblin_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
	var adjacent_to_goblin: Vector2i = goblin_start + Vector2i.UP
	battlefield.grid._handle_tile_click(warrior_start)
	battlefield.grid._handle_tile_click(adjacent_to_goblin)
	battlefield.grid._handle_tile_click(goblin_start)

	# Kill XP (5) plus the site's 10 clear XP totals 15 — short of the level
	# 2 threshold (20), so no level-up modal is expected here; the loop below
	# still dismisses one defensively in case a future rebalance changes the
	# math, and caps its wait so a stuck battle fails instead of hanging.
	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		if battlefield.level_up.visible:
			battlefield.level_up.continue_button.emit_signal("pressed")
		await get_tree().process_frame
		settle_frames += 1

	assert_true(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID))
	assert_eq(GameSession.selected_encounter, "", "Victory should clear the encounter selection")
	assert_eq(GameSession.pending_reward, 10, "The goblin camp's reward should be queued but not yet banked")
	assert_eq(GameSession.gold, 0, "Winning the battle alone must not bank the reward")
```

(This also resolves the separately-noted "uncapped enemy-turn wait loop" cleanup item in this file — the whole `while battlefield._enemy_turn_in_progress: await get_tree().process_frame` block it referred to is removed along with the now-unneeded "hunt the second goblin" logic.)

- [ ] **Step 4: Run every affected suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow.gd -gexit`
Expected: all PASS.

- [ ] **Step 5: Manually verify in-game via `make play`**

Enter the Goblin Camp (1 goblin) and the Orc Outpost a few times (should alternate between 1 orc and 2 goblins) to confirm both are winnable for a level-1 party and the enemy-health HUD band renders correctly for the 2-enemy case — this also closes out the previously-open "verify a 3-enemy battle" cleanup item, since no encounter can field 3 enemies anymore.

- [ ] **Step 6: Commit**

```bash
git add tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd tests/unit/test_first_campaign_ui_flow.gd
git commit -m "test: update battle/battlefield/full-loop tests for the star-tier rebalance"
```

---

## Milestone D: Minor Parties screen fix

### Task 5: Move Create Party below the table

**Files:**
- Modify: `scenes/ui/parties.tscn`

In `scenes/ui/parties.tscn`, move the `[node name="CreatePartyButton" ...]` block (and nothing else) so it appears after the `[node name="EmptyLabel" ...]` block and before `[node name="BackButton" ...]`, matching `party_details.tscn`'s Add Member placement (Title, PartyTable, EmptyLabel, **CreatePartyButton**, BackButton). Leave every property and the `[connection]` line unchanged — this is a pure reorder of two node blocks in the file, since Godot's `VBoxContainer` renders children in tree order and no test asserts on child index (only `get_node()` by name).

- [ ] **Step 1: Reorder the node blocks** as described above.
- [ ] **Step 2: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_parties.gd -gexit` — Expected: PASS unchanged.
- [ ] **Step 3: Commit**

```bash
git add scenes/ui/parties.tscn
git commit -m "fix: move Create Party below the party table for consistency"
```

---

## Milestone E: Guild Hall / full-party battles cleanup

### Task 6: Deduplicate the BFS/`is_blocked` closure in `battle_controller.gd`

**Files:**
- Modify: `scripts/battle/battle_controller.gd`

**Interfaces:**
- Produces: a new private `_move_distances(unit) -> Dictionary` helper.

`get_legal_moves()` and `try_move_selected_unit()` each build an identical `is_blocked` closure and run their own BFS. `grid.get_tiles_in_range()`'s result is exactly `grid.get_tile_distances()`'s keys, so both call sites can share one traversal.

- [ ] **Step 1: Implement**

Replace:

```gdscript
func get_legal_moves(unit) -> Array[Vector2i]:
	if unit.moves_remaining <= 0:
		return []
	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	return grid.get_tiles_in_range(unit.grid_position, unit.moves_remaining, is_blocked)


func try_move_selected_unit(target: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	var distances: Dictionary = grid.get_tile_distances(
		selected_unit.grid_position, selected_unit.moves_remaining, is_blocked
	)
	selected_unit.grid_position = target
	selected_unit.moves_remaining -= distances[target]
	last_attack_result = {}
	return true
```

with:

```gdscript
func _move_distances(unit) -> Dictionary:
	var is_blocked := func(pos: Vector2i) -> bool: return get_unit_at(pos) != null
	return grid.get_tile_distances(unit.grid_position, unit.moves_remaining, is_blocked)


func get_legal_moves(unit) -> Array[Vector2i]:
	if unit.moves_remaining <= 0:
		return []
	var moves: Array[Vector2i] = []
	moves.assign(_move_distances(unit).keys())
	return moves


func try_move_selected_unit(target: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	var distances := _move_distances(selected_unit)
	selected_unit.grid_position = target
	selected_unit.moves_remaining -= distances[target]
	last_attack_result = {}
	return true
```

- [ ] **Step 2: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit` — Expected: PASS unchanged (pure refactor; `get_tiles_in_range`/`get_tile_distances` run the identical BFS).
- [ ] **Step 3: Commit**

```bash
git add scripts/battle/battle_controller.gd
git commit -m "refactor: share one BFS helper between get_legal_moves and try_move_selected_unit"
```

### Task 7: Rename `SELECTED_MODULATE` → `LIVING_MODULATE` and fix a stale comment

**Files:**
- Modify: `scripts/battle/portrait_panel.gd`
- Test: `tests/unit/test_battlefield.gd` (verify only — likely no change needed)

`SELECTED_MODULATE` is applied to every *living* party member, not just the selected one (the actual "is this one selected" indicator is the separate `SelectionRing`). Rename for accuracy, and fix the docstring above `refresh()` which inaccurately claims `_player_adventurer_ids` is "capped by `PLAYER_START_POSITIONS.size()`" — it's actually uncapped; only the separate `units` array is capped.

- [ ] **Step 1: Rename the constant and its one usage**

```gdscript
const DEFEATED_MODULATE := Color(1, 1, 1, 0.35)
const LIVING_MODULATE := Color(1, 1, 1, 1)
```

and in `_build_row()`:

```gdscript
	row.modulate = LIVING_MODULATE if unit != null else DEFEATED_MODULATE
```

- [ ] **Step 2: Fix the stale comment** above `refresh()`:

```gdscript
	# Read from the board's own authoritative fielded-unit list rather than
	# re-deriving from GameSession: grid._player_adventurer_ids is what was
	# actually fielded (uncapped; only the separate `units` array is capped
	# by PLAYER_START_POSITIONS.size()), so the row list can never drift
	# from the board. This also means _find_unit() == null can only mean
	# "defeated" here, never "never fielded".
```

- [ ] **Step 3: Grep for any other reference** to `SELECTED_MODULATE`:

Run: `grep -rn "SELECTED_MODULATE" --include=*.gd .` (excluding `.worktrees/`) and update any hit — none are expected outside `portrait_panel.gd` itself based on current usage (`test_battlefield.gd` only references `PortraitPanelScript.DEFEATED_MODULATE`).

- [ ] **Step 4: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit` — Expected: PASS unchanged.
- [ ] **Step 5: Commit**

```bash
git add scripts/battle/portrait_panel.gd
git commit -m "refactor: rename SELECTED_MODULATE to LIVING_MODULATE and fix a stale comment"
```

### Task 8: Guard `select_unit_by_adventurer_id` against selecting an enemy unit

**Files:**
- Modify: `scripts/battle/battle_controller.gd`
- Test: `tests/unit/test_battle_controller.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func test_select_unit_by_adventurer_id_rejects_a_non_player_unit() -> void:
	var controller := _make_controller(4, 4)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Claw")
	enemy.adventurer_id = "not_really_an_adventurer"
	controller.units = [enemy]

	var selected: bool = controller.select_unit_by_adventurer_id("not_really_an_adventurer")

	assert_false(selected)
	assert_null(controller.selected_unit)
```

(Match `UnitScript.new()`'s actual constructor signature/argument order as defined in `scripts/battle/unit.gd` if it differs from the sketch above — check the file before writing this step.)

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit`
Expected: FAIL (currently unreachable/harmless in real play since `Unit.adventurer_id` is only ever set on player units, but the guard doesn't exist).

- [ ] **Step 3: Implement**

```gdscript
func select_unit_by_adventurer_id(adventurer_id: String) -> bool:
	if input_locked or active_side != Side.PLAYER:
		return false
	var unit = _get_unit_by_adventurer_id(adventurer_id)
	if unit == null or not unit.is_alive() or unit.side != Side.PLAYER:
		return false
	_select_unit(unit)
	return true
```

- [ ] **Step 4: Run to verify it passes**, plus the full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit`
- [ ] **Step 5: Commit**

```bash
git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git commit -m "fix: guard select_unit_by_adventurer_id against non-player units"
```

### Task 9: Cover `guild_hall.*` copy in the localization test, and add WASD/number-key hints

**Files:**
- Modify: `translations/en.tres`, `scripts/battle/battlefield.gd`
- Test: `tests/unit/test_localization.gd`

- [ ] **Step 1: Add the missing `guild_hall.*` literal-copy assertions**

In `tests/unit/test_localization.gd`'s `test_translation_keys_resolve_to_expected_english_copy()`, add:

```gdscript
	assert_eq(tr("guild_hall.title"), "Guild Hall")
	assert_eq(tr("guild_hall.level") % 1, "Guild Hall — Level 1")
	assert_eq(tr("guild_hall.party_size") % 4, "Party size: 4")
	assert_eq(tr("guild_hall.upgrade") % 50, "Upgrade to Level 2 — 50 gold")
	assert_eq(tr("guild_hall.max_level"), "Max Level")
```

- [ ] **Step 2: Add WASD/number-key mentions to the two actionable battle hints, and update their assertions in the same test**

In `translations/en.tres`, change:

```
"battle.hint.select_unit": "%s's move. Click a unit to select it. Esc: menu.",
```
to
```
"battle.hint.select_unit": "%s's move. Click a unit to select it, or press 1-5. Esc: menu.",
```

and:

```
"battle.hint.select_destination": "%s's move. Click a highlighted tile to move, or select another unit.",
```
to
```
"battle.hint.select_destination": "%s's move. Click a highlighted tile to move (or use WASD), or select another unit.",
```

Update the corresponding assertions in `test_localization.gd`:

```gdscript
	assert_eq(
		tr("battle.hint.select_unit") % "Player",
		"Player's move. Click a unit to select it, or press 1-5. Esc: menu."
	)
	...
	assert_eq(
		tr("battle.hint.select_destination") % "Player",
		"Player's move. Click a highlighted tile to move (or use WASD), or select another unit."
	)
```

No change is needed in `battlefield.gd` itself — it only ever calls `tr("battle.hint.select_unit") % side_name` etc., so a copy-only change in `en.tres` is sufficient.

- [ ] **Step 3: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit` — Expected: PASS.
- [ ] **Step 4: Commit**

```bash
git add translations/en.tres tests/unit/test_localization.gd
git commit -m "test: cover guild_hall.* copy and mention WASD/number-key controls in battle hints"
```

### Task 10: Remove the hardcoded collision-risk offset in `_stage_a_killing_blow`

**Files:**
- Modify: `tests/unit/test_battlefield.gd`

`_stage_a_killing_blow()` places the enemy at `warrior.grid_position + Vector2i(1, 0)`, which happens to equal `PLAYER_START_POSITIONS[1]` — a latent collision if a helper ever fields a 2-member party. Fix by picking any actually-free tile adjacent to the warrior at call time instead of a fixed offset.

- [ ] **Step 1: Implement**

```gdscript
func _stage_a_killing_blow(battlefield: Node2D) -> Dictionary:
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	for candidate in battlefield.grid.grid.get_adjacent(warrior.grid_position):
		if battlefield.grid.get_unit_at(candidate) == null:
			enemy.grid_position = candidate
			break
	enemy.health = 1
	battlefield.grid.selected_unit = warrior
	battlefield.grid.hit_roll = func() -> float: return 0.0
	return {"warrior": warrior, "enemy": enemy}
```

- [ ] **Step 2: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit` — Expected: PASS unchanged (every current caller only fields a 1-member party, so the chosen tile is identical to before).
- [ ] **Step 3: Commit**

```bash
git add tests/unit/test_battlefield.gd
git commit -m "test: stop hardcoding the killing-blow enemy offset to avoid a 2-member-party collision"
```

---

## Milestone F: Persistent encampment left-nav

**Layout approach (see `docs/UI-Layout-Design-Guidelines.md`):** `CampNav` is a normal UI component, so the four `Control`-rooted screens (Encampment, Units, Buildings, Deploy Party) mount it by wrapping their existing `Center` content and the new `CampNav` in a root-level `HBoxContainer` — the exact "LeftPanel + MapView" shape the guidelines' own hierarchy example shows — instead of hand-picking pixel offsets. `Center` gains `size_flags_horizontal/vertical = 3` (expand+fill) so it claims the remaining width and still centers its `VBox` within it; `CampNav`'s width is self-determined by its own `custom_minimum_size` (Constraints Over Coordinates, guideline #4), not a magic number copied into five files. This does move `Center` one level deeper in the tree (`Center` → `Body/Center`), so every `get_node("Center/VBox/...")` call in these screens' scripts and tests updates its prefix — a mechanical rename, not a structural risk, since nothing below `VBox` changes.
World Map keeps its existing Node2D tile/marker/route rendering as-is: guideline #6 explicitly carves out "map objects" for absolute positioning, and that rendering isn't new in this plan. What *is* new is shifting that board right to make room for `CampNav` — done by adding one `Board` Node2D as the sole parent of `Tiles`/`Highlights`/`Markers`/`Routes`, with its `position` set once (`board.position = BOARD_OFFSET` in `_ready()`), rather than the "add `BOARD_OFFSET` inside every drawing function" approach guideline #4 explicitly warns against ("layout calculations in code", "manually updating sibling positions"). Every `_draw_*` function's body is untouched — their coordinates were already relative to their own container, so reparenting that container under `Board` is the entire fix. Mouse-to-grid conversion switches from `get_local_mouse_position()` (WorldMap's own space) to `board.get_local_mouse_position()` (Godot's own transform math does the offsetting, not hand-written subtraction).

### Task 11: Build the reusable `CampNav` component

**Files:**
- Create: `scripts/ui/camp_nav.gd`, `scenes/ui/camp_nav.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_camp_nav.gd`

**Interfaces:**
- Produces: `CampNav` (a `PanelContainer` script), instanced identically into all six top-level camp screens (Encampment, Units, Buildings, Trade [disabled placeholder], Deploy Party, World Map). Public method `refresh()` re-evaluates the Deploy Party button's disabled state from `GameSession.get_deployable_encamped_parties()`.
- Consumes: `GameManager.go_to_encampment/go_to_units/go_to_buildings/go_to_deploy_party/go_to_world_map()` (all exist), `GameSession.get_deployable_encamped_parties()` (exists).

Four of the six labels reuse existing keys (`encampment.title`, `encampment.units`, `encampment.buildings`, `encampment.trade`, `encampment.deploy_party`); only `camp_nav.world_map` is new.

- [ ] **Step 1: Add the one new translation key**

In `translations/en.tres`, add near the `world_map.*` keys:

```
"camp_nav.world_map": "World Map",
```

- [ ] **Step 2: Write `scripts/ui/camp_nav.gd`**

```gdscript
extends PanelContainer

## Persistent left-hand navigation instanced into all six top-level camp
## screens (Encampment, Units, Buildings, Trade, Deploy Party, World Map).
## Every destination here is fixed, so — unlike InformationPanel's
## signal-forwarding pattern — each button routes straight through
## GameManager itself rather than bubbling a signal up to a parent screen.

@onready var encampment_button: Button = $VBox/EncampmentButton
@onready var units_button: Button = $VBox/UnitsButton
@onready var buildings_button: Button = $VBox/BuildingsButton
@onready var trade_button: Button = $VBox/TradeButton
@onready var deploy_party_button: Button = $VBox/DeployPartyButton
@onready var world_map_button: Button = $VBox/WorldMapButton


func _ready() -> void:
	refresh()


func refresh() -> void:
	deploy_party_button.disabled = GameSession.get_deployable_encamped_parties().is_empty()


func _on_encampment_button_pressed() -> void:
	GameManager.go_to_encampment()


func _on_units_button_pressed() -> void:
	GameManager.go_to_units()


func _on_buildings_button_pressed() -> void:
	GameManager.go_to_buildings()


func _on_deploy_party_button_pressed() -> void:
	GameManager.go_to_deploy_party()


func _on_world_map_button_pressed() -> void:
	GameManager.go_to_world_map()
```

- [ ] **Step 3: Write `scenes/ui/camp_nav.tscn`**

Follow `information_panel.tscn`'s pattern exactly: an unstretched root sized by `custom_minimum_size`, positioned by whichever parent scene instances it.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/camp_nav.gd" id="1_camp_nav"]

[node name="CampNav" type="PanelContainer"]
layout_mode = 3
anchors_preset = 0
custom_minimum_size = Vector2(180, 0)
script = ExtResource("1_camp_nav")

[node name="VBox" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 8

[node name="EncampmentButton" type="Button" parent="VBox"]
layout_mode = 2
text = "encampment.title"

[node name="UnitsButton" type="Button" parent="VBox"]
layout_mode = 2
text = "encampment.units"

[node name="BuildingsButton" type="Button" parent="VBox"]
layout_mode = 2
text = "encampment.buildings"

[node name="TradeButton" type="Button" parent="VBox"]
layout_mode = 2
disabled = true
text = "encampment.trade"

[node name="DeployPartyButton" type="Button" parent="VBox"]
layout_mode = 2
text = "encampment.deploy_party"

[node name="WorldMapButton" type="Button" parent="VBox"]
layout_mode = 2
text = "camp_nav.world_map"

[connection signal="pressed" from="VBox/EncampmentButton" to="." method="_on_encampment_button_pressed"]
[connection signal="pressed" from="VBox/UnitsButton" to="." method="_on_units_button_pressed"]
[connection signal="pressed" from="VBox/BuildingsButton" to="." method="_on_buildings_button_pressed"]
[connection signal="pressed" from="VBox/DeployPartyButton" to="." method="_on_deploy_party_button_pressed"]
[connection signal="pressed" from="VBox/WorldMapButton" to="." method="_on_world_map_button_pressed"]
```

- [ ] **Step 4: Write `tests/unit/test_camp_nav.gd`**

```gdscript
extends GutTest

const CampNavScene := preload("res://scenes/ui/camp_nav.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func _make_nav() -> Control:
	var nav: Control = CampNavScene.instantiate()
	add_child_autofree(nav)
	return nav


func test_shows_all_six_destinations() -> void:
	var nav := _make_nav()

	assert_eq(nav.get_node("VBox/EncampmentButton").text, "encampment.title")
	assert_eq(nav.get_node("VBox/UnitsButton").text, "encampment.units")
	assert_eq(nav.get_node("VBox/BuildingsButton").text, "encampment.buildings")
	assert_eq(nav.get_node("VBox/TradeButton").text, "encampment.trade")
	assert_eq(nav.get_node("VBox/DeployPartyButton").text, "encampment.deploy_party")
	assert_eq(nav.get_node("VBox/WorldMapButton").text, "camp_nav.world_map")


func test_trade_is_present_but_disabled() -> void:
	var nav := _make_nav()

	assert_true(nav.get_node("VBox/TradeButton").disabled)


func test_deploy_party_is_disabled_until_a_deployable_party_exists() -> void:
	var nav := _make_nav()
	assert_true(nav.get_node("VBox/DeployPartyButton").disabled)

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	nav.refresh()

	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)


func test_deploy_party_becomes_disabled_again_once_no_deployable_party_remains() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var nav := _make_nav()
	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)

	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	nav.refresh()

	assert_true(nav.get_node("VBox/DeployPartyButton").disabled)


func test_encampment_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_units_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_buildings_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


func test_deploy_party_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_deploy_party()")


func test_world_map_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_world_map()")
```

- [ ] **Step 5: Run** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_camp_nav.gd -gexit` — Expected: PASS.
- [ ] **Step 6: Commit**

```bash
git add scripts/ui/camp_nav.gd scenes/ui/camp_nav.tscn translations/en.tres tests/unit/test_camp_nav.gd
git commit -m "feat: add the reusable CampNav left-nav component"
```

### Task 12: Turn Encampment into a dashboard and mount CampNav on it

**Files:**
- Modify: `scripts/ui/encampment.gd`, `scenes/ui/encampment.tscn`, `translations/en.tres`
- Test: `tests/unit/test_encampment.gd`

**Interfaces:**
- Consumes: `CampNav` (Task 11).
- Produces: Encampment's own content becomes population/parties/units stats only; `UnitsButton`/`BuildingsButton`/`TradeButton`/`DeployPartyButton` and their handlers are removed from this screen (they now live only in `CampNav`).

"Population" = total roster size (`GameSession.adventurers.size()`); "Parties" = encamped (non-deployed) party count; "Units in camp" = adventurers who are not members of any currently-deployed party. These are three distinct, non-redundant counts.

- [ ] **Step 1: Add the three new translation keys**

In `translations/en.tres`, near `encampment.title`:

```
"encampment.population": "Population: %d",
"encampment.parties_count": "Parties: %d",
"encampment.units_count": "Units in camp: %d",
```

- [ ] **Step 2: Write the failing tests** — replace `tests/unit/test_encampment.gd` in full:

```gdscript
extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_encampment_contains_the_camp_nav() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))


func test_the_old_depart_and_manage_party_controls_are_absent() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.has_node("Body/Center/VBox/DepartButton"))
	assert_false(screen.has_node("Body/Center/VBox/ManagePartyButton"))
	assert_false(screen.has_node("Body/Center/VBox/Status"))
	assert_false(
		screen.has_node("Body/Center/VBox/UnitsButton"),
		"Encampment's own content no longer has nav buttons -- they live in CampNav"
	)
	assert_false(screen.has_node("Body/Center/VBox/BuildingsButton"))
	assert_false(screen.has_node("Body/Center/VBox/TradeButton"))
	assert_false(screen.has_node("Body/Center/VBox/DeployPartyButton"))


func test_encampment_shows_population_parties_and_units_counts() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 1)


func test_units_count_excludes_members_of_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 1)
	assert_eq(
		screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 0,
		"The only adventurer is out with a deployed party"
	)


func test_refresh_updates_the_counts() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 0)

	GameSession.create_party()
	screen.refresh()

	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)


func test_encampment_contains_the_information_panel_and_refreshes_its_gold_total() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	GameSession.gold = 25
	screen.refresh()

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_encampment_never_shows_party_info_since_it_has_no_selection_concept() -> void:
	GameSession.create_party()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	screen.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
```

- [ ] **Step 3: Run to verify failures**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_encampment.gd -gexit`
Expected: FAIL — `CampNav`/`PopulationLabel`/etc. don't exist yet.

- [ ] **Step 4: Rewrite `scripts/ui/encampment.gd`**

```gdscript
extends Control

@onready var population_label: Label = $Body/Center/VBox/PopulationLabel
@onready var parties_label: Label = $Body/Center/VBox/PartiesLabel
@onready var units_label: Label = $Body/Center/VBox/UnitsLabel
@onready var information_panel: PanelContainer = $InformationPanel


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	population_label.text = tr("encampment.population") % GameSession.adventurers.size()
	parties_label.text = tr("encampment.parties_count") % GameSession.get_encamped_parties().size()
	units_label.text = tr("encampment.units_count") % _count_encamped_units()
	information_panel.refresh()


## Adventurers currently physically present at the encampment: the roster
## minus whoever is out with a deployed party (an encamped-but-unassigned
## party's members still count as present).
func _count_encamped_units() -> int:
	var deployed_member_ids: Array = []
	for party in GameSession.parties:
		if party.get("deployed", false):
			deployed_member_ids.append_array(party.member_ids)
	return GameSession.adventurers.size() - deployed_member_ids.size()
```

- [ ] **Step 5: Rewrite `scenes/ui/encampment.tscn`**

Per the Milestone F layout note above: a root-level `HBoxContainer` ("Body") holds `CampNav` and `Center` side by side, `Center` expands to fill the rest of the width via size flags (not a hand-picked offset), and `InformationPanel` stays a direct child of the screen root since it's independently anchored to the top-right corner, unaffected by the left nav.

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/encampment.gd" id="1_encampment"]
[ext_resource type="PackedScene" path="res://scenes/ui/information_panel.tscn" id="2_information_panel"]
[ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]

[node name="Encampment" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_encampment")

[node name="Body" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 16

[node name="CampNav" parent="Body" instance=ExtResource("3_camp_nav")]
layout_mode = 2

[node name="Center" type="CenterContainer" parent="Body"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="VBox" type="VBoxContainer" parent="Body/Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "encampment.title"
horizontal_alignment = 1

[node name="PopulationLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "encampment.population"

[node name="PartiesLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "encampment.parties_count"

[node name="UnitsLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "encampment.units_count"

[node name="InformationPanel" parent="." instance=ExtResource("2_information_panel")]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -240.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 96.0
grow_horizontal = 0
```

(No `[connection]` lines — Encampment's own content has no buttons left; `CampNav` self-wires. `CampNav`'s width comes from its own `custom_minimum_size` (Task 11), so `Body` never needs a hardcoded number to make room for it.)

- [ ] **Step 6: Run to verify all pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_encampment.gd -gexit`
Expected: PASS.

- [ ] **Step 7: Manually verify layout via `make play`** — confirm CampNav and the dashboard labels don't overlap and every nav button routes correctly.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/encampment.gd scenes/ui/encampment.tscn translations/en.tres tests/unit/test_encampment.gd
git commit -m "feat: turn Encampment into a population/parties/units dashboard with a persistent left nav"
```

### Task 13: Mount CampNav on Units, Buildings, and Deploy Party

**Files:**
- Modify: `scenes/ui/units.tscn`, `scenes/ui/buildings.tscn`, `scenes/ui/deploy_party.tscn`, `scripts/ui/buildings.gd`, `scripts/ui/deploy_party.gd`
- Test: `tests/unit/test_units.gd`, `tests/unit/test_buildings.gd`, `tests/unit/test_deploy_party.gd`

Same `Body` `HBoxContainer` restructuring as Task 12's `encampment.tscn`: each screen's existing `Center` (with its `VBox` and all current content untouched) becomes a child of a new `Body` HBoxContainer alongside `CampNav`, instead of a hand-picked offset. This moves every `Center/VBox/...` path one level deeper to `Body/Center/VBox/...`, so scripts and tests referencing those paths update their prefix. `units.gd` has no such path (it only holds `$InformationPanel`), so it needs no script change.

- [ ] **Step 1: Update `scripts/ui/buildings.gd` and `scripts/ui/deploy_party.gd`'s onready paths**

In `scripts/ui/buildings.gd`:

```gdscript
@onready var building_table: TableView = $Body/Center/VBox/BuildingTable
```

In `scripts/ui/deploy_party.gd`:

```gdscript
@onready var party_table: TableView = $Body/Center/VBox/PartyTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel
```

- [ ] **Step 2: Update each test file** — for every line matching `get_node("Center/VBox/...")` or `has_node("Center/VBox/...")` in `tests/unit/test_units.gd` (8 occurrences), `tests/unit/test_buildings.gd` (4 occurrences), and `tests/unit/test_deploy_party.gd` (15 occurrences), change the `"Center/VBox/` prefix to `"Body/Center/VBox/`. This is a mechanical find-and-replace — confirm with `grep -c 'Center/VBox' tests/unit/test_units.gd tests/unit/test_buildings.gd tests/unit/test_deploy_party.gd` before and after (counts must be unchanged; only the string content changes).

Add one presence test per file. In `tests/unit/test_units.gd`:

```gdscript
func test_units_contains_the_camp_nav() -> void:
	var screen: Control = UnitsScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))
```

Add the analogous `test_buildings_contains_the_camp_nav()` to `tests/unit/test_buildings.gd` (using `BuildingsScene`, asserting `screen.get_node("Body/CampNav")`) and `test_deploy_party_contains_the_camp_nav()` to `tests/unit/test_deploy_party.gd` (using `DeployPartyScene`, same assertion) — check each file's existing preload constant name before writing the assertion.

- [ ] **Step 3: Run to verify these fail** (paths don't exist yet — `Center` is still a direct root child) for each of the three `-gselect=` runs.

- [ ] **Step 4: Edit each `.tscn`** the same way as `encampment.tscn` in Task 12: add the `camp_nav.tscn` `ext_resource`, wrap the existing `Center` block in a new `Body` `HBoxContainer`, and add `CampNav` as `Body`'s first child. For example in `scenes/ui/units.tscn`, replace:

```
[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
```

with:

```
[node name="Body" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 16

[node name="CampNav" parent="Body" instance=ExtResource("3_camp_nav")]
layout_mode = 2

[node name="Center" type="CenterContainer" parent="Body"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
```

and change every subsequent `parent="Center"` / `parent="Center/VBox"` line in the same file to `parent="Body/Center"` / `parent="Body/Center/VBox"`, and every `from="Center/VBox/..."` in a `[connection]` line to `from="Body/Center/VBox/..."`. Every node's own properties (text, `custom_minimum_size`, `disabled`, etc.) stay exactly as-is — only the `parent=`/`from=` path strings and the two new/changed node headers above change. Repeat identically for `scenes/ui/buildings.tscn` and `scenes/ui/deploy_party.tscn` (each gets its own `ext_resource id="3_camp_nav"` entry, numbered after that file's existing resources).

- [ ] **Step 5: Run all three affected suites**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_units.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_buildings.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_deploy_party.gd -gexit`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/units.tscn scenes/ui/buildings.tscn scenes/ui/deploy_party.tscn scripts/ui/buildings.gd scripts/ui/deploy_party.gd tests/unit/test_units.gd tests/unit/test_buildings.gd tests/unit/test_deploy_party.gd
git commit -m "feat: mount the persistent CampNav on Units, Buildings, and Deploy Party"
```

### Task 14: Mount CampNav on World Map, shifting the board right to make room

**Files:**
- Modify: `scripts/world/world_map.gd`, `scenes/world/world_map.tscn`
- Test: `tests/unit/test_world_map.gd`

**Interfaces:**
- Produces: a new `Board` `Node2D` node (`$Board`) that becomes the sole parent of the existing `Tiles`/`Highlights`/`Markers`/`Routes` containers; `WorldMap.BOARD_OFFSET: Vector2` (constant, applied once to `Board.position` in `_ready()`).
- Consumes: nothing new.

The tile grid currently renders starting at pixel `(0, 0)`, as a direct child of `WorldMap`. Per the Milestone F layout note, this plan does not sprinkle a `BOARD_OFFSET` addition through every drawing function (that's exactly the "layout calculations in code" / "manually updating sibling positions" the design guidelines warn against) — instead, `Tiles`/`Highlights`/`Markers`/`Routes` are reparented under one new `Board` node, and `Board`'s own position is set once. Every `_draw_*` function's body is completely unchanged: their coordinates were already relative to their own container's local origin, and that's now `Board`'s origin instead of `WorldMap`'s. `CampNav` mounts on the `HUD` `CanvasLayer` (screen-space UI, untouched by `Board`'s transform), in the top-left, clear of both the grid and the existing bottom hint bar. Every test in this file that operates in *grid* coordinates (the vast majority — `_handle_tile_click(Vector2i(...))`, `try_move_party`, `build_route`, etc.) is unaffected; tests that call `get_node("Markers")`/`get_node("Routes")` or assert exact rendered *pixel* positions need their path/offset updated.

- [ ] **Step 1: Update every `get_node("Markers")` / `get_node("Routes")` reference and the two exact-pixel-position tests/helpers**

Run `grep -n 'get_node("Markers")\|get_node("Routes")' tests/unit/test_world_map.gd` first — every hit (this includes the `Routes` lookups already used by Task 1's new repathing tests) must have its path changed from `"Markers"`/`"Routes"` to `"Board/Markers"`/`"Board/Routes"`, since those containers now live under `Board`. For example, Task 1's `test_repathing_mode_previews_a_new_route_alongside_the_old_one` changes:

```gdscript
	assert_eq(world_map.get_node("Routes").get_child_count(), 6)
```

to:

```gdscript
	assert_eq(world_map.get_node("Board/Routes").get_child_count(), 6)
```

Apply the same `"Markers"` → `"Board/Markers"` / `"Routes"` → `"Board/Routes"` rename to every other hit from the grep above.

Then update the two exact-pixel-position helpers/tests: they keep referencing `WorldMapScript.BOARD_OFFSET` exactly as before (it still exists as a constant — see Step 3 — just applied differently in production code), so their math is unchanged from a naive offset-based design; only the `get_node("Markers")` call inside the helper needs the same rename:

```gdscript
func _find_expedition_label_by_position(world_map: Node2D, position: Vector2i) -> Label:
	var expected_x := (
		position.x * WorldMapScript.TILE_SIZE + WorldMapScript.TILE_SIZE * 0.1
		+ WorldMapScript.BOARD_OFFSET.x
	)
	var expected_y := maxf(
		position.y * WorldMapScript.TILE_SIZE - WorldMapScript.TILE_SIZE * 0.6,
		WorldMapScript.EXPEDITION_LABEL_MIN_Y
	)
	for marker in world_map.get_node("Board/Markers").get_children():
		if marker is Label:
			if abs(marker.position.x - expected_x) < 1.0 and abs(marker.position.y - expected_y) < 1.0:
				return marker
	return null
```

```gdscript
func test_goblin_camp_label_position_is_unchanged_by_the_hint_bar_clamp() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var label := _find_expedition_label_by_position(world_map, goblin_record.position)

	assert_not_null(label, "Goblin Camp's expedition label should be drawn")
	assert_eq(
		label.position,
		Vector2(goblin_record.position) * WorldMapScript.TILE_SIZE
			+ Vector2(WorldMapScript.TILE_SIZE * 0.1, -WorldMapScript.TILE_SIZE * 0.6)
			+ WorldMapScript.BOARD_OFFSET
	)
```

Add a presence test:

```gdscript
func test_world_map_contains_the_camp_nav() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_not_null(world_map.get_node("HUD/CampNav"))
```

- [ ] **Step 2: Run to verify these fail**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit`
Expected: FAIL — `BOARD_OFFSET`/`Board` don't exist; `HUD/CampNav` doesn't exist; the renamed `Board/Markers`/`Board/Routes` paths don't resolve.

- [ ] **Step 3: Add the `Board` node and reparent the drawing containers under it, in `scenes/world/world_map.tscn`**

```
[node name="WorldMap" type="Node2D"]
script = ExtResource("1_world_map")

[node name="Board" type="Node2D" parent="."]

[node name="Tiles" type="Node2D" parent="Board"]

[node name="Highlights" type="Node2D" parent="Board"]

[node name="Markers" type="Node2D" parent="Board"]

[node name="Routes" type="Node2D" parent="Board"]
```

(`Board`'s own `position` is left at the scene's default `(0, 0)` — it's set once from code in Step 4 below, via the same `BOARD_OFFSET` constant the tests already reference, so there is exactly one number to keep in sync instead of one per drawing function.) Nothing else under `WorldMap` changes structurally yet — `HUD` and its children stay direct children of `WorldMap` as today.

- [ ] **Step 4: Add `BOARD_OFFSET`, apply it once to `Board`, and repoint mouse-to-grid conversion through it**

In `scripts/world/world_map.gd`, add near the other pixel/color consts:

```gdscript
# Reserves room for the persistent left nav (CampNav, 180px wide + 16px
# margin each side) so the tile grid never renders underneath it. Applied
# once to Board's own position in _ready() -- every drawing function below
# stays relative to Board's local origin and needs no offset of its own.
const BOARD_OFFSET := Vector2(212.0, 0.0)
```

Update the container `@onready` vars to point at `Board`'s children, and add one for `Board` itself:

```gdscript
@onready var board: Node2D = $Board
@onready var tile_container: Node2D = $Board/Tiles
@onready var highlight_container: Node2D = $Board/Highlights
@onready var marker_container: Node2D = $Board/Markers
@onready var route_container: Node2D = $Board/Routes
```

In `_ready()`, set `Board`'s position before the first draw call:

```gdscript
func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	board.position = BOARD_OFFSET
	party_position = GameSession.get_deployed_party_position()
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	_draw_tiles()
	_draw_markers()
	_draw_routes()
	_update_highlights()
	_update_turn_label()
	_refresh_turn_controls()
	_refresh_information_panel()
```

In `_unhandled_input()`, convert mouse position through `board` instead of `WorldMap`'s own local space, so Godot's node transform does the offsetting instead of hand-written subtraction:

```gdscript
	if event is InputEventMouseMotion:
		_update_hover_route(_to_grid_position(board.get_local_mouse_position()))
		return
```

and:

```gdscript
	var tile_pos := _to_grid_position(board.get_local_mouse_position())
```

`_to_grid_position()` itself is unchanged (`board.get_local_mouse_position()` already returns coordinates local to `Board`, so no subtraction is needed inside it). Every `_draw_tiles()` / `_draw_markers()` / `_draw_route_path()` / `_update_highlights()` function body is **unchanged** — they already compute positions relative to their own container's origin, and that container is now parented under `Board`.

- [ ] **Step 5: Add `CampNav` to the `HUD` layer in `scenes/world/world_map.tscn`**

Add the `ext_resource` and a node under `HUD`, positioned in the top-left (clear of the bottom `Hint`/`FeedbackPanel` bar at `y=608+`); `HUD` is a `CanvasLayer` (screen-space), so it's unaffected by `Board`'s transform:

```
[ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]
```

```
[node name="CampNav" parent="HUD" instance=ExtResource("3_camp_nav")]
offset_left = 16.0
offset_top = 16.0
```

(Insert this node block anywhere under the existing `HUD` children — e.g. right after `[node name="HUD" type="CanvasLayer" parent="."]`.)

- [ ] **Step 6: Run to verify all pass**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit`
Expected: PASS.

- [ ] **Step 7: Manually verify via `make play`** — confirm the grid renders fully clear of CampNav, all six nav buttons route correctly from the World Map, and clicking tiles / setting routes still works (pixel hit-testing now goes through `Board.get_local_mouse_position()`, so a mismatch here would mean `Board`'s position and `Board`'s children have drifted apart).

- [ ] **Step 8: Commit**

```bash
git add scripts/world/world_map.gd scenes/world/world_map.tscn tests/unit/test_world_map.gd
git commit -m "feat: shift the world map board right and mount the persistent CampNav"
```

---

## Milestone G: Documentation

### Task 15: Update `docs/dev/code-map.md`

**Files:**
- Modify: `docs/dev/code-map.md`

Fold in both the originally-noted staleness (no mention of `PortraitPanel`, the Buildings/Guild Hall scenes, Guild Hall state in `GameSession`'s "Owns" list, `get_tile_distances`, or the WASD/number-key battle-flow) and the debt this plan itself adds (the `CampNav` shell, `EXPEDITIONS`' `enemy` field no longer being a single fixed value for star-2+ sites).

- [ ] **Step 1: Update the `GameSession` "Owns" cell** in the autoloads table to mention Guild Hall level, e.g. append `, Guild Hall level` after `gold`.

- [ ] **Step 2: Update the directory-map listing** under `scenes/ui/` to include `buildings`, `guild_hall`, and `camp_nav`, and under `scripts/ui/` to mention `portrait_panel.gd` lives in `scripts/battle/` (not `scripts/ui/`) alongside `battle_controller.gd`/`battlefield.gd`/`grid.gd`/`unit.gd` — check the existing bullet's wording before editing so the correction reads cleanly in context.

- [ ] **Step 3: Extend the `EXPEDITIONS` bullet** in "Domain model" to describe the star-tier system:

```markdown
- **`EXPEDITIONS: Dictionary`** (constant) — the two encounter *templates*
  (`goblin_camp`, `orc_outpost`): fixed `position`, `reward`, `kill_xp`,
  `clear_xp`, `difficulty` (star tier), and a documented-default `enemy`.
  A live *active instance*'s `enemy` is re-resolved from
  `STAR_ENEMY_COMPOSITIONS[difficulty]` every time it's entered (see
  `enter_encounter()`/`_resolve_enemy_composition()`/
  `enemy_composition_roll`) — 1 star is a fixed single goblin; 2-3 stars
  randomly pick between two goblins-vs-fewer-orcs options.
```

- [ ] **Step 4: Add a short "Battle: two grid objects" addendum** for `get_tile_distances`, e.g. append to that section's second bullet: "; `get_tile_distances` runs the identical BFS but also records distance-from-start, and is what `battle_controller.gd`'s `_move_distances()` uses for both `get_legal_moves()` and `try_move_selected_unit()`."

- [ ] **Step 5: Add a short "Camp navigation" section** after "World Map: routing is turn-based, not real-time":

```markdown
## Camp navigation: CampNav is a reusable shell, not a router

`scenes/ui/camp_nav.tscn` (`scripts/ui/camp_nav.gd`) is instanced
identically into all six top-level camp screens (Encampment, Units,
Buildings, Trade, Deploy Party, World Map) to give a persistent left-hand
nav. It has no state of its own beyond the Deploy Party button's disabled
flag and never receives a signal from its parent screen — every button
calls a `GameManager.go_to_*()` directly, the same way `InformationPanel`'s
buttons do *not* (that one forwards a signal, since its "View" destination
depends on the parent screen's own selection).
```

- [ ] **Step 6: Add a one-line mention of WASD/number-key controls** to the "Battle flow" paragraph, e.g. append: "Player units can also be moved with WASD and selected with the 1-5 number keys (`battle_controller.gd`'s `MOVE_KEY_DIRECTIONS`/`NUMBER_KEYS`), independent of the click path described above."

- [ ] **Step 7: Read the full file back once** to confirm it reads coherently end to end (this is prose, not code — no automated test covers it).

- [ ] **Step 8: Commit**

```bash
git add docs/dev/code-map.md
git commit -m "docs: update code-map.md for CampNav, the star system, and prior staleness"
```

---

## Self-review notes (from authoring this plan)

- **Spec coverage:** every section of `docs/plans/campaign-loop-follow-up.md` maps to a milestone above — encampment nav (F), world map bug (A), XP accounting (B), battle balancing (C), and every bullet in the Guild Hall cleanup list (E, plus the two items resolved as byproducts of C/Task 4 and noted inline: the enemy-health-HUD-overlap check and the uncapped wait loop).
- **Layout guideline compliance (`docs/UI-Layout-Design-Guidelines.md`):** Milestone F was redesigned mid-authoring to stop hand-picking pixel offsets. The four `Control` screens now mount `CampNav` via a root-level `HBoxContainer` (`Center` expands via size flags, `CampNav`'s width comes from its own `custom_minimum_size`) instead of an anchored `offset_left`. World Map keeps its Node2D board's absolute-coordinate rendering (guideline #6's sanctioned "map objects" exception, and pre-existing besides), but the rightward shift needed for `CampNav` is applied once to a new `Board` node's `position`, not summed into every drawing function — no `_draw_*` function body changes at all in Task 14.
- **Assumptions flagged for review, not silently baked in:** "population/parties/units" as three distinct dashboard counts (Task 12) and the exact `CampNav`/`BOARD_OFFSET` width/offset values (Tasks 11-14) are concrete, reasoned choices, not guesses from thin air — but they're the kind of visual/product-labeling call worth a quick look in `make play` before considering Milestone F done.
- **Type/name consistency checked:** `repathing` (Task 1), `enemy_composition_roll`/`STAR_ENEMY_COMPOSITIONS`/`_resolve_enemy_composition` (Task 3), `_move_distances` (Task 6), `LIVING_MODULATE` (Task 7), and `CampNav`/`Body`/`Board`/`BOARD_OFFSET` (Tasks 11-14) are each introduced once and referenced with the same name in every later task that touches them.
