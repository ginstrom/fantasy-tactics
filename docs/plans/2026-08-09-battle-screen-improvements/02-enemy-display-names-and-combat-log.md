# Step 2: Enemy Display Names and the Combat Log

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task.

**Branch:** `enemy-names-and-combat-log`

**Goal:** Every unit (player and enemy) has a stable, human-readable
`display_name` for the rest of this plan to use. The battle HUD's bottom
panel gains a scrolling combat log, appended to (never overwritten) as
attacks happen, auto-scrolled to the newest line. Movement is not logged
(only attacks — hit, miss, defeat).

**Files:**
- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_localization.gd`

**Interfaces produced (Steps 3 and 5 depend on these):**
- `Unit.display_name: String` — `"Warrior"` / `"Warrior 2"` for player
  units (copied from `GameSession.get_adventurer(id).name`); `"Kobold 1"`,
  `"Kobold 2"`, ... for enemy units (always indexed, even when only one is
  fielded).
- `Unit.enemy_type_name: String` — `""` for player units; the untranslated-index
  species name (`"Kobold"`) for enemy units. Used by Step 5 to group kills
  by type.
- `Battlefield.log_list: VBoxContainer` (unique name `%Log`) — one `Label`
  child per logged attack, oldest first.

## Context you need before starting

- `scripts/battle/unit.gd` is a plain `RefCounted` with a positional
  `_init()`. **Do not add a new constructor parameter** — every existing
  test and call site constructs `Unit.new(...)` positionally, and a new
  required/optional trailing param would still shift nothing (it'd be
  fine at the end), but the two new fields here are simplest set as plain
  public vars assigned by the caller after construction, matching how
  `battle_controller.gd`'s own tests already do it (e.g.
  `warrior.health = 0`, `defender.defense = 50`).
- `scripts/battle/battle_controller.gd`'s `_ready()` builds every `Unit`
  for the battle (`scripts/battle/battle_controller.gd:63-96`). Player
  units come from `_player_adventurer_ids` (one per party member, in
  party order); enemy units come from `_get_enemy_stats()` (one species,
  `enemy_stats.count` copies — **a battle only ever fields one enemy
  species**, see `GameSession.STAR_ENEMY_COMPOSITIONS`, so "index within
  the type" and "index within the battle" are the same number).
- `enemy_stats` (the `Dictionary` returned by `_get_enemy_stats()`) already
  carries a `name_key` field (e.g. `"battle.enemy.kobold"` →
  `"Kobold"`), separate from `attack_name_key` (the weapon name, e.g.
  `"battle.enemy.kobold.attack"` → `"Rusty Dagger"`). `attack_name_key` is
  already used (for `Unit.attack_name`); `name_key` is not used anywhere
  yet — this step is what wires it up.
- `battlefield.gd`'s `_on_board_changed()` is the single place that
  currently sets `status.text` from `grid.last_attack_result` after a
  **player** attack; `_play_enemy_turn()`'s loop over `steps` is the
  single place that does the same for **enemy** attacks (and also for
  enemy moves, which don't log). Both already have the data you need
  (`step.attacker`, `step.defender`, `step.hit`, `step.damage`,
  `step.defeated`) — `try_attack_selected_unit()` in
  `battle_controller.gd:218-225` builds that exact dict.
- **Do not touch** `_describe_step()`, `status.text`, or `hint.text` — the
  existing single-line Hint/Status behavior (and every test that pins its
  exact wording, e.g. `test_describe_step_reports_a_hit_with_damage`) is
  unrelated to this step and must keep passing unchanged. The log is a
  new, separate, additive widget.
- A `Battlefield` is re-instantiated fresh for every battle (see the
  comment above `_kill_xp_awarded_units` in `battlefield.gd`), so the log
  never needs an explicit reset between battles — it starts empty because
  the scene does.

## Step 2a: `Unit.display_name` / `enemy_type_name`

- [ ] **Write the failing tests**

Add to `tests/unit/test_battle_controller.gd`, after
`test_ready_falls_back_to_the_default_warrior_when_no_party_is_selected`:

```gdscript
func test_ready_assigns_the_adventurers_name_as_the_player_units_display_name() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.display_name, "Warrior")
	assert_eq(warrior.enemy_type_name, "", "Player units have no enemy type name")


func test_ready_indexes_even_a_solo_enemy() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	assert_eq(goblin.display_name, "Goblin 1", "Enemies are always indexed, even the only one fielded")
	assert_eq(goblin.enemy_type_name, "Goblin")


func test_ready_assigns_stable_indexed_display_names_to_same_type_enemies() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.KOBOLD_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 3
	GameSession.active_encounters.append({
		"id": "capacity_test",
		"template_id": GameSession.RUINED_FORTRESS_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 3,
		"kill_xp": 3,
		"clear_xp": 30,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "capacity_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var names: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			names.append(unit.display_name)
			assert_eq(unit.enemy_type_name, "Kobold")
	names.sort()
	assert_eq(names, ["Kobold 1", "Kobold 2", "Kobold 3"])
```

(`GameSession.RUINED_FORTRESS_ID` and `GameSession.KOBOLD_ENEMY_STATS`
are pre-existing constants in `scripts/autoload/game_session.gd` — no new
constants to add.)

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=display_name -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=indexes -gexit
```
Expected: FAIL — `display_name`/`enemy_type_name` don't exist on `Unit`
yet (`Invalid get index 'display_name'`).

- [ ] **Add the fields to `Unit`**

In `scripts/battle/unit.gd`, add next to the existing `kill_xp` field:

```gdscript
# Human-readable label for logs/detail panels. "Warrior"/"Warrior 2" for a
# player unit (copied from the adventurer's own name — already unique per
# party member). "Kobold 1"/"Kobold 2" for an enemy unit: always indexed,
# even when only one of that type is fielded, because a battle only ever
# fields one enemy species (see GameSession.STAR_ENEMY_COMPOSITIONS) so the
# index alone already disambiguates. Empty until BattleController assigns
# it in _ready() — the constructor is intentionally not touched here (every
# existing call site constructs Unit.new() positionally; these two fields
# follow this file's existing pattern of being set directly on the
# instance instead, see e.g. defense/resistance in the tests).
var display_name: String = ""
# "Kobold" for an enemy unit (its species name, with no index) -- used to
# group kills by type. Empty for a player unit.
var enemy_type_name: String = ""
```

- [ ] **Assign them in `battle_controller.gd`'s `_ready()`**

Replace the player-unit loop (currently
`units.append(UnitScript.new(...))` directly) with a version that keeps a
local reference so `display_name` can be set before appending:

```gdscript
	for index in mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size()):
		var adventurer_id: String = _player_adventurer_ids[index]
		var damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
		var player_unit := UnitScript.new(
			PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
			GameSession.get_effective_move_range(adventurer_id),
			GameSession.get_effective_max_health(adventurer_id),
			damage_range.x,
			damage_range.y,
			GameSession.get_effective_hit_chance(adventurer_id),
			GameSession.get_effective_weapon_name(adventurer_id),
			adventurer_id,
			GameSession.get_effective_defense(adventurer_id),
			GameSession.get_effective_resistance(adventurer_id)
		)
		player_unit.display_name = GameSession.get_adventurer(adventurer_id).get("name", "")
		units.append(player_unit)
```

And the enemy-unit loop:

```gdscript
	var enemy_count: int = enemy_stats.get("count", 1)
	var enemy_type_name: String = tr(enemy_stats.name_key)
	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
		var enemy_unit := UnitScript.new(
			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.attack_damage, enemy_stats.hit_chance,
			tr(enemy_stats.attack_name_key), "", 0, 0, enemy_stats.get("kill_xp", 0)
		)
		enemy_unit.display_name = "%s %d" % [enemy_type_name, index + 1]
		enemy_unit.enemy_type_name = enemy_type_name
		units.append(enemy_unit)
```

(Both replacements sit inside the existing `_ready()` — only the body of
the two `for` loops changes; the surrounding code, including the
`selected_unit = _first_living_player_unit()` line right after, is
untouched.)

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
```
Expected: `N/N passed.` — including every pre-existing test in this file
(none of them assert on `display_name`/`enemy_type_name`, and the loop
restructuring produces identical `units` contents otherwise).

- [ ] **Commit**

```bash
git add scripts/battle/unit.gd scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git commit -m "feat: give every battle unit a stable display name"
```

## Step 2b: Combat log — scene and wiring

- [ ] **Write the failing test**

Add to `tests/unit/test_battlefield.gd`, after
`test_bottom_panel_does_not_share_a_parent_with_the_portrait_panel`:

```gdscript
func test_combat_log_shares_the_bottom_panel_stack_and_starts_empty() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.log_list.get_parent().get_parent(), battlefield.hint.get_parent())
	assert_eq(battlefield.log_list.get_child_count(), 0)


func test_combat_log_is_wrapped_in_a_height_capped_scroll_container() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var scroll_container: Control = battlefield.log_list.get_parent()
	assert_true(scroll_container is ScrollContainer)
	assert_gt(scroll_container.custom_minimum_size.y, 0.0)
```

- [ ] **Run to verify it fails**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gunit_test_name=combat_log -gexit
```
Expected: FAIL — `battlefield.log_list` doesn't exist.

- [ ] **Add the scene nodes**

In `scenes/battle/battlefield.tscn`, insert two nodes into
`HUD/Margin/VBox/BottomPanel/BottomContent`, right after the existing
`Status` label and before `EnemyHealthScroll`:

```
[node name="LogScroll" type="ScrollContainer" parent="HUD/Margin/VBox/BottomPanel/BottomContent"]
layout_mode = 2
custom_minimum_size = Vector2(0, 100)
horizontal_scroll_mode = 0

[node name="Log" type="VBoxContainer" parent="HUD/Margin/VBox/BottomPanel/BottomContent/LogScroll"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
```

(Mirrors the existing `EnemyHealthScroll`/`EnemyHealth` pair exactly —
same `ScrollContainer` + `VBoxContainer` shape, same
`unique_name_in_owner` convention, same height-cap pattern that fixed the
enemy-health-list-grows-too-tall bug this codebase already hit once.)

- [ ] **Wire the `@onready` field**

In `scripts/battle/battlefield.gd`, add next to the existing
`@onready var enemy_health: VBoxContainer = %EnemyHealth`:

```gdscript
@onready var log_list: VBoxContainer = %Log
@onready var log_scroll: ScrollContainer = $HUD/Margin/VBox/BottomPanel/BottomContent/LogScroll
```

- [ ] **Run to verify it passes**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```
Expected: `N/N passed.`

- [ ] **Commit**

```bash
git add scenes/battle/battlefield.tscn scripts/battle/battlefield.gd tests/unit/test_battlefield.gd
git commit -m "feat: add the empty combat log container to the battle HUD"
```

## Step 2c: Combat log — translation keys and line-building

- [ ] **Write the failing tests**

Add to `tests/unit/test_localization.gd`, right after the existing
`assert_eq(tr("battle.status.enemy_move") % "Goblin", "Goblin moves closer.")`
line:

```gdscript
	assert_eq(
		tr("battle.log.hit") % ["Warrior 2", "Kobold 2", 3],
		"Warrior 2 attacks Kobold 2 — hits for 3 damage!"
	)
	assert_eq(
		tr("battle.log.miss") % ["Warrior", "Kobold 1"],
		"Warrior attacks Kobold 1 — misses."
	)
	assert_eq(tr("battle.log.defeated") % "Kobold 2", "Kobold 2 is defeated!")
```

Add to `tests/unit/test_battlefield.gd`, after the new
`test_combat_log_is_wrapped_in_a_height_capped_scroll_container`:

```gdscript
func _stage_an_adjacent_pair(battlefield: Node2D) -> Dictionary:
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.grid_position = warrior.grid_position + Vector2i(1, 0)
	battlefield.grid.selected_unit = warrior
	return {"warrior": warrior, "goblin": goblin}


func test_a_hit_appends_a_detailed_line_naming_both_units_and_the_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.hit") % [units.warrior.display_name, units.goblin.display_name, 3]
	)


func test_a_miss_appends_a_miss_line_naming_both_units() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.99

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.miss") % [units.warrior.display_name, units.goblin.display_name]
	)


func test_a_killing_blow_appends_a_defeated_suffix() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.health = 1
	battlefield.grid.hit_roll = func() -> float: return 0.0

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_string_contains(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.defeated") % units.goblin.display_name
	)


func test_a_repeated_board_changed_event_does_not_duplicate_the_log_line() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	battlefield._on_board_changed()

	assert_eq(
		battlefield.log_list.get_child_count(), 1,
		"A repeated board_changed for the same already-logged attack must not re-log it"
	)


func test_enemy_turn_attacks_are_appended_to_the_log() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.grid_position = warrior.grid_position + Vector2i(1, 0)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield._on_end_turn_pressed()

	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.hit") % [goblin.display_name, warrior.display_name, 1]
	)


func test_enemy_turn_moves_are_not_logged() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	# The default fallback fielding (no party assigned) puts the Warrior at
	# PLAYER_START_POSITIONS[0] and the goblin at ENEMY_START_POSITIONS[0],
	# which are not adjacent -- see test_run_enemy_turn_moves_the_goblin_
	# toward_the_nearest_player_unit for the same non-adjacent setup, so this
	# enemy turn is guaranteed to be a move with no attack.
	battlefield._on_end_turn_pressed()

	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.log_list.get_child_count(), 0, "A move-only enemy turn must not add any log line")
```

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gunit_test_name=battle.log -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gunit_test_name=log -gexit
```
Expected: FAIL — the `battle.log.*` keys don't exist, and
`battlefield.log_list` has no children after an attack.

- [ ] **Add the translation keys**

In `translations/en.tres`, in the `battle.*` block, right after
`"battle.status.enemy_turn": "Enemy turn.",`:

```
"battle.log.hit": "%s attacks %s — hits for %d damage!",
"battle.log.miss": "%s attacks %s — misses.",
"battle.log.defeated": "%s is defeated!",
```

- [ ] **Implement the log in `battlefield.gd`**

Add a new field next to the other award-guard fields (near
`_kill_xp_awarded_units`):

```gdscript
# Identity guard so a repeated board_changed event for the same attack (see
# _on_board_changed()) can't append the same log line twice. Compared with
# is_same() rather than == because try_attack_selected_unit() always
# assigns last_attack_result a brand-new Dictionary literal per attack, so
# reference identity alone already distinguishes "already logged this" from
# "a genuinely new attack" -- no need to compare field-by-field.
var _last_logged_attack_result: Dictionary = {}
```

Modify `_on_board_changed()` — replace:

```gdscript
	if not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)
```

with:

```gdscript
	if not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)
		_log_attack(grid.last_attack_result)
```

Modify `_play_enemy_turn()`'s loop — replace:

```gdscript
	for step in steps:
		grid._draw_units()
		grid._update_highlights()
		status.text = _describe_step(step)
		await get_tree().create_timer(enemy_turn_beat_seconds).timeout
```

with:

```gdscript
	for step in steps:
		grid._draw_units()
		grid._update_highlights()
		status.text = _describe_step(step)
		if step.type == "attack":
			_log_attack(step)
		await get_tree().create_timer(enemy_turn_beat_seconds).timeout
```

Add the three new methods near `_describe_step()`:

```gdscript
func _log_attack(step: Dictionary) -> void:
	if is_same(_last_logged_attack_result, step):
		return
	_last_logged_attack_result = step
	_append_log_line(_describe_log_entry(step))


func _describe_log_entry(step: Dictionary) -> String:
	var attacker_name: String = step.attacker.display_name
	var defender_name: String = step.defender.display_name
	if not step.hit:
		return tr("battle.log.miss") % [attacker_name, defender_name]
	var line: String = tr("battle.log.hit") % [attacker_name, defender_name, step.damage]
	if step.defeated:
		line += " " + tr("battle.log.defeated") % defender_name
	return line


func _append_log_line(text: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	log_list.add_child(label)
	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)
```

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```
Expected: `N/N passed.` for both files, including every pre-existing test
(nothing about `_describe_step`, `status`, or `hint` changed).

- [ ] **Commit**

```bash
git add scripts/battle/battlefield.gd translations/en.tres tests/unit/test_battlefield.gd tests/unit/test_localization.gd
git commit -m "feat: append detailed attack lines to a scrolling combat log"
```

## Manual verification

1. `make play`
2. Debug menu (**FN+F9**) → **Ruined Fortress** (stages three level-1
   Warriors against up to 8 Kobolds — the best scenario for seeing
   several same-type enemies indexed at once, and for generating enough
   attacks to see the log actually scroll).
3. Confirm the bottom panel now shows, below Hint/Status: a new log area.
   Make a few attacks (hits and at least one miss — `battle.log.miss`
   lines only appear on a miss, so attack repeatedly if the first roll
   hits) and confirm each appends a new line at the bottom, the panel
   auto-scrolls to keep the newest line visible, and enemy names read
   `"Kobold 1"`, `"Kobold 2"`, etc. (not all just `"Kobold"`).
4. End a turn and let an enemy attack; confirm its move (if any) produces
   no log line but its attack does.
5. Defeat a Kobold; confirm that line ends with
   `"... Kobold N is defeated!"`.

## Full run and merge

```bash
make check
```
Expected: `N/N passed.` / `---- All tests passed! ----`, exit 0.

```bash
git checkout main
git merge enemy-names-and-combat-log
git branch -d enemy-names-and-combat-log
```
