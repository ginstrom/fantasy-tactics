# Step 04: Battlefield Presentation and Campaign Outcomes

## Milestone

The battlefield HUD shows both units' current/max health and a status line
reporting attacker, hit-or-miss, and damage. Pressing **End Turn** disables
the button, locks board input on the `Grid`, and paces `run_enemy_turn()`'s
returned steps one beat at a time using a tunable constant. Killing the last
enemy marks `goblin_camp` complete and routes to the world map through
`GameManager.complete_battle()`; losing the Warrior abandons the encounter
(without completing it) and returns the party to `starting_settlement`
through a new `GameManager.fail_battle()`. The developer-facing **Complete
Battle** button is gone.

## Setup

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/battlefield-outcomes
```

## Files

- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing tests

**`tests/unit/test_battle_controller.gd`** — the input lock added below must
block clicks:

```gdscript
func test_locked_input_is_ignored_by_handle_tile_click() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.input_locked = true

	controller._handle_tile_click(Vector2i(1, 1))

	assert_null(controller.selected_unit, "A locked board must ignore clicks")
```

**`tests/unit/test_game_session.gd`**:

```gdscript
func test_abandoning_the_current_encounter_clears_selection_without_completing_it() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.enter_encounter("goblin_camp")

	session.abandon_current_encounter()

	assert_eq(session.selected_encounter, "")
	assert_false(session.is_encounter_complete("goblin_camp"))
```

**`tests/unit/test_game_manager.gd`**:

```gdscript
func test_fail_battle_abandons_the_encounter_and_returns_the_party_home() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_encounter, "")
	assert_false(GameSession.is_encounter_complete("goblin_camp"))
```

**`tests/unit/test_battlefield.gd`** — add these alongside the existing
Escape test:

```gdscript
func test_set_enemy_turn_in_progress_locks_and_unlocks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._set_enemy_turn_in_progress(true)

	assert_true(battlefield.grid.input_locked)
	assert_true(battlefield.end_turn_button.disabled)

	battlefield._set_enemy_turn_in_progress(false)

	assert_false(battlefield.grid.input_locked)
	assert_false(battlefield.end_turn_button.disabled)


func test_locked_input_ignores_board_clicks() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield._set_enemy_turn_in_progress(true)

	battlefield.grid._handle_tile_click(Vector2i(1, 1))

	assert_null(battlefield.grid.selected_unit, "A locked board must ignore clicks")


func test_describe_step_reports_a_hit_with_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "attack", "attacker": attacker, "hit": true, "damage": 1}

	assert_eq(battlefield._describe_step(step), tr("battle.status.hit") % [tr("battle.side.enemy"), 1])


func test_describe_step_reports_a_miss() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "attack", "attacker": attacker, "hit": false, "damage": 0}

	assert_eq(battlefield._describe_step(step), tr("battle.status.miss") % tr("battle.side.enemy"))


func test_describe_step_reports_an_enemy_move() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var mover = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "move", "unit": mover, "from": Vector2i(4, 4), "to": Vector2i(4, 3)}

	assert_eq(battlefield._describe_step(step), tr("battle.status.enemy_move") % tr("battle.side.enemy"))


func test_ready_shows_full_health_for_both_units() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.player_health.text, tr("battle.status.health") % [tr("battle.side.player"), 3, 3]
	)
	assert_eq(
		battlefield.enemy_health.text, tr("battle.status.health") % [tr("battle.side.enemy"), 3, 3]
	)


func test_health_label_shows_defeated_after_a_unit_dies() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(Vector2i(4, 4))
	goblin.take_damage(goblin.max_health)
	battlefield.grid.units.erase(goblin)

	battlefield._update_health_labels()

	assert_eq(battlefield.enemy_health.text, tr("battle.status.defeated") % tr("battle.side.enemy"))


func test_show_battle_result_shows_the_victory_message_and_locks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(true)

	assert_eq(battlefield.status.text, tr("battle.result.victory"))
	assert_true(battlefield._battle_resolved)
	assert_true(battlefield.end_turn_button.disabled)
	assert_true(battlefield.grid.input_locked)


func test_show_battle_result_shows_the_defeat_message_and_locks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(false)

	assert_eq(battlefield.status.text, tr("battle.result.defeat"))
	assert_true(battlefield._battle_resolved)


func test_apply_battle_outcome_true_completes_the_encounter() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_encounter_complete("goblin_camp"))


func test_apply_battle_outcome_false_returns_the_party_home_without_completing() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(false)

	assert_false(GameSession.has_deployed_party())
	assert_false(GameSession.is_encounter_complete("goblin_camp"))
```

**`tests/unit/test_localization.gd`** — remove the `battle.complete_battle`
assertion from `test_translation_keys_resolve_to_expected_english_copy` and
add the new keys:

```gdscript
	assert_eq(
		tr("battle.hint.already_moved") % "Player",
		"Player turn. This unit has already moved. Attack an adjacent enemy or select another unit."
	)
	assert_eq(
		tr("battle.hint.turn_complete") % "Player",
		"Player turn. This unit has moved and attacked. Select another unit."
	)
	assert_eq(tr("battle.status.awaiting_action"), "No actions yet.")
	assert_eq(tr("battle.status.health") % ["Warrior", 3, 3], "Warrior: 3/3 HP")
	assert_eq(tr("battle.status.defeated") % "Goblin", "Goblin: defeated")
	assert_eq(tr("battle.status.hit") % ["Warrior", 2], "Warrior hits for 2 damage.")
	assert_eq(tr("battle.status.miss") % "Goblin", "Goblin misses.")
	assert_eq(tr("battle.status.enemy_move") % "Goblin", "Goblin moves closer.")
	assert_eq(tr("battle.status.enemy_turn"), "Enemy turn.")
	assert_eq(tr("battle.result.victory"), "Victory! The goblin camp is cleared.")
	assert_eq(tr("battle.result.defeat"), "Defeat. The party returns to the settlement.")
```

(this replaces the existing `battle.hint.already_moved` assertion, whose
expected copy changes, and the deleted `battle.complete_battle` assertion.)

Update `test_battlefield_hud_buttons_use_translation_keys_not_literal_copy`
to drop the removed button and check the new Status label instead:

```gdscript
func test_battlefield_hud_buttons_use_translation_keys_not_literal_copy() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("HUD/EndTurnButton").text, "battle.end_turn")
	assert_eq(battlefield.get_node("HUD/Status").text, "battle.status.awaiting_action")
```

Run:

```bash
make test
```

Expected: FAIL — `input_locked`, `abandon_current_encounter()`,
`fail_battle()`, and every new `battlefield.gd` member/method referenced
above do not exist yet; the `CompleteBattleButton` node and
`battle.complete_battle` key are still present.

### 2. Lock board input on the Grid

Add to `scripts/battle/battle_controller.gd`:

```gdscript
var input_locked: bool = false
```

Guard the one place player clicks are dispatched:

```gdscript
func _handle_tile_click(tile_pos: Vector2i) -> void:
	if input_locked:
		return

	var clicked_unit = get_unit_at(tile_pos)
	...
```

(keep the rest of the function body from step 02 unchanged — only the new
guard clause at the top is added).

### 3. Add the non-completing defeat transition to `GameSession`

Add next to `complete_current_encounter()` in
`scripts/autoload/game_session.gd`:

```gdscript
func abandon_current_encounter() -> void:
	selected_encounter = ""
```

### 4. Add `fail_battle()` to `GameManager`

Add next to `complete_battle()` in `scripts/autoload/game_manager.gd`:

```gdscript
func fail_battle() -> Error:
	GameSession.abandon_current_encounter()
	return enter_starting_settlement()
```

This reuses `enter_starting_settlement()`, which already calls
`GameSession.return_deployed_party_to_settlement()` and changes to the
starting-settlement scene — `fail_battle()` only adds the non-completing
encounter cleanup in front of it.

### 5. Rewrite `battlefield.gd`

Replace `scripts/battle/battlefield.gd` in full:

```gdscript
extends Node2D

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SIDE_NAME_KEYS := {0: "battle.side.player", 1: "battle.side.enemy"}
const ENEMY_TURN_BEAT_SECONDS := 0.5

@onready var hint: Label = $HUD/Hint
@onready var status: Label = $HUD/Status
@onready var player_health: Label = $HUD/PlayerHealth
@onready var enemy_health: Label = $HUD/EnemyHealth
@onready var end_turn_button: Button = $HUD/EndTurnButton
@onready var grid: Node2D = $Grid

var enemy_turn_beat_seconds: float = ENEMY_TURN_BEAT_SECONDS
var _enemy_turn_in_progress: bool = false
var _battle_resolved: bool = false


func _ready() -> void:
	_on_board_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_end_turn_pressed() -> void:
	if _enemy_turn_in_progress or _battle_resolved:
		return
	grid.end_turn()
	_play_enemy_turn()


func _play_enemy_turn() -> void:
	_set_enemy_turn_in_progress(true)
	status.text = tr("battle.status.enemy_turn")
	var steps: Array = grid.run_enemy_turn()
	for step in steps:
		grid._draw_units()
		grid._update_highlights()
		status.text = _describe_step(step)
		await get_tree().create_timer(enemy_turn_beat_seconds).timeout

	if grid.is_battle_lost():
		_resolve_battle(false)
		return

	grid.end_turn()
	_set_enemy_turn_in_progress(false)
	_on_board_changed()


func _on_board_changed() -> void:
	if _battle_resolved:
		return

	var side_name: String = tr(SIDE_NAME_KEYS[grid.active_side])
	var selected_unit = grid.selected_unit

	if selected_unit == null:
		hint.text = tr("battle.hint.select_unit") % side_name
	elif selected_unit.has_moved and selected_unit.has_acted:
		hint.text = tr("battle.hint.turn_complete") % side_name
	elif selected_unit.has_moved:
		hint.text = tr("battle.hint.already_moved") % side_name
	else:
		hint.text = tr("battle.hint.select_destination") % side_name

	_update_health_labels()
	if not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)

	if grid.is_battle_won():
		_resolve_battle(true)


func _resolve_battle(victory: bool) -> void:
	_show_battle_result(victory)
	await get_tree().create_timer(enemy_turn_beat_seconds).timeout
	_apply_battle_outcome(victory)


func _show_battle_result(victory: bool) -> void:
	_battle_resolved = true
	_set_enemy_turn_in_progress(true)
	status.text = tr("battle.result.victory") if victory else tr("battle.result.defeat")


func _apply_battle_outcome(victory: bool) -> void:
	if victory:
		GameManager.complete_battle()
	else:
		GameManager.fail_battle()


func _set_enemy_turn_in_progress(value: bool) -> void:
	_enemy_turn_in_progress = value
	end_turn_button.disabled = value
	grid.input_locked = value


func _describe_step(step: Dictionary) -> String:
	if step.type == "attack":
		var attacker_name: String = tr(SIDE_NAME_KEYS[step.attacker.side])
		if step.hit:
			return tr("battle.status.hit") % [attacker_name, step.damage]
		return tr("battle.status.miss") % attacker_name

	var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
	return tr("battle.status.enemy_move") % mover_name


func _update_health_labels() -> void:
	player_health.text = _format_health(
		tr("battle.side.player"), _find_unit_by_side(BattleControllerScript.Side.PLAYER)
	)
	enemy_health.text = _format_health(
		tr("battle.side.enemy"), _find_unit_by_side(BattleControllerScript.Side.ENEMY)
	)


func _find_unit_by_side(side: int):
	for unit in grid.units:
		if unit.side == side:
			return unit
	return null


func _format_health(label: String, unit) -> String:
	if unit == null or not unit.is_alive():
		return tr("battle.status.defeated") % label
	return tr("battle.status.health") % [label, unit.health, unit.max_health]
```

Notes on why this is structured this way:

- `_resolve_battle()` and `_play_enemy_turn()` are `async` (they `await` a
  scene-tree timer). Never call either directly from a test: a call left
  suspended at the `await` when `add_child_autofree` frees the battlefield
  at the end of the test method will resume later, on a freed node, and
  error out — possibly during a later, unrelated test. `_resolve_battle()`
  exists only to be fire-and-forget from production code
  (`_on_board_changed()` / `_play_enemy_turn()`); it delegates its
  synchronous half to `_show_battle_result()`, which is what tests call
  directly to assert the immediate message/lock effects without ever
  reaching the `await`.
- Victory is checked from `_on_board_changed()`, which fires immediately
  after the player's own killing blow (through `_select_unit_after_action()`
  from step 02) — not only at the end of an enemy turn — because the player
  can win mid-turn, before ever pressing **End Turn**.
- Defeat can only happen from the goblin's own attack, so it is checked once,
  right after `_play_enemy_turn()`'s paced loop finishes.

### 6. Update the scene

In `scenes/battle/battlefield.tscn`:

- Remove the `CompleteBattleButton` node and its `pressed` connection.
- Change the `EndTurnButton` connection's `method` from `end_turn` (on
  `Grid`) to `_on_end_turn_pressed` (on `.`, the `Battlefield` root).
- Add three new `Label` nodes under `HUD`: `Status` (initial `text =
  "battle.status.awaiting_action"`), `PlayerHealth`, and `EnemyHealth` (no
  static text needed — both are written by `_update_health_labels()` before
  the first frame renders).

Resulting file:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/battlefield.gd" id="1_battlefield"]
[ext_resource type="Script" path="res://scripts/battle/battle_controller.gd" id="2_battle"]

[node name="Battlefield" type="Node2D"]
script = ExtResource("1_battlefield")

[node name="Grid" type="Node2D" parent="."]
position = Vector2(448, 168)
script = ExtResource("2_battle")

[node name="Tiles" type="Node2D" parent="Grid"]

[node name="Highlights" type="Node2D" parent="Grid"]

[node name="Units" type="Node2D" parent="Grid"]

[node name="HUD" type="CanvasLayer" parent="."]

[node name="Hint" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 16.0
offset_right = 640.0
offset_bottom = 48.0
text = "battle.hint.select_unit"

[node name="Status" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 56.0
offset_right = 640.0
offset_bottom = 88.0
text = "battle.status.awaiting_action"

[node name="PlayerHealth" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 96.0
offset_right = 400.0
offset_bottom = 128.0

[node name="EnemyHealth" type="Label" parent="HUD"]
offset_left = 16.0
offset_top = 128.0
offset_right = 400.0
offset_bottom = 160.0

[node name="EndTurnButton" type="Button" parent="HUD"]
offset_left = 1104.0
offset_top = 16.0
offset_right = 1264.0
offset_bottom = 48.0
text = "battle.end_turn"

[connection signal="pressed" from="HUD/EndTurnButton" to="." method="_on_end_turn_pressed"]
[connection signal="board_changed" from="Grid" to="." method="_on_board_changed"]
```

### 7. Update translations

In `translations/en.tres`, delete the `"battle.complete_battle": "Complete
Battle",` line and change `"battle.hint.already_moved"`'s copy, then add the
new keys. The `messages` block becomes:

```
"battle.end_turn": "End Turn",
"battle.side.player": "Player",
"battle.side.enemy": "Enemy",
"battle.hint.select_unit": "%s turn. Click a unit to select it. Esc: menu.",
"battle.hint.already_moved": "%s turn. This unit has already moved. Attack an adjacent enemy or select another unit.",
"battle.hint.turn_complete": "%s turn. This unit has moved and attacked. Select another unit.",
"battle.hint.select_destination": "%s turn. Click a highlighted tile to move, or select another unit.",
"battle.status.awaiting_action": "No actions yet.",
"battle.status.health": "%s: %d/%d HP",
"battle.status.defeated": "%s: defeated",
"battle.status.hit": "%s hits for %d damage.",
"battle.status.miss": "%s misses.",
"battle.status.enemy_move": "%s moves closer.",
"battle.status.enemy_turn": "Enemy turn.",
"battle.result.victory": "Victory! The goblin camp is cleared.",
"battle.result.defeat": "Defeat. The party returns to the settlement.",
```

(leave every other key in the file untouched; this is only the `battle.*`
subset, shown in the order it appears in the file).

### 8. Verify green

```bash
make test
make check
rg -n "CompleteBattleButton|complete_battle\"|_on_complete_battle_pressed" scenes scripts translations
```

Expected: all GUT tests pass; the `rg` search finds no remaining references
to the removed developer control (the `GameManager.complete_battle()`
method itself must still exist — only the button and its handler are gone).

### 9. Manual verification

Run `make play` and check both full paths end to end:

1. From the starting settlement, depart with the Warrior, walk to the
   goblin camp, click it to select, click again to enter.
2. In battle, move the Warrior adjacent to the goblin, attack until it
   dies. Confirm the HUD shows health and hit/miss/damage feedback as you
   go, and that the goblin's own turn animates (move then attack) with
   **End Turn** disabled and the board unresponsive while it plays.
3. Confirm victory returns you to the world map with the camp shown
   cleared, and that clicking it again does not re-enter battle.
4. Start a fresh attempt at the camp and let the goblin kill the Warrior;
   confirm defeat returns you to the starting settlement, the party is no
   longer deployed, and the camp is available to try again.

Ask for user approval before merging.

## Commit and handoff

```bash
git add scripts/battle/battle_controller.gd scripts/battle/battlefield.gd scenes/battle/battlefield.tscn scripts/autoload/game_session.gd scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd tests/unit/test_game_session.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git commit -m "feat: add battle HUD feedback, paced enemy turn, and campaign outcome routing"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/battlefield-outcomes
git branch -d feat/battlefield-outcomes
git status --short
```

Do not push.
