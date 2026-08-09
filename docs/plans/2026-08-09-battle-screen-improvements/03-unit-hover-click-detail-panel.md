# Step 3: Unit Hover/Click Detail Panel

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task.

**Branch:** `unit-hover-click-detail-panel`
**Depends on:** Step 2 merged to `main` first (`Unit.display_name`).

**Goal:** A new right-side panel on the battle HUD shows detail for
whichever unit the mouse is currently over (live hover), or — if the
mouse isn't over a unit right now — whichever unit was last "pinned" by a
click. Player units show name/class/level/exact HP. Enemies show only a
Healthy/Wounded/Badly Wounded tier, never exact numbers. **Click-to-attack
is completely unchanged** — the only new click behavior is that clicking
an enemy that's not a legal attack target (today a silent no-op) now pins
that enemy in the panel instead of doing nothing.

**Files:**
- Create: `scripts/battle/unit_info_panel.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_battle_controller.gd`
- Test: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_localization.gd`

**Interfaces:**
- Consumes: `Unit.display_name: String`, `Unit.enemy_type_name: String`
  (Step 2). `Unit.health: int`, `Unit.max_health: int`,
  `Unit.adventurer_id: String`, `Unit.side: int` (pre-existing).
  `GameSession.get_adventurer(id) -> Dictionary` (pre-existing, has
  `"name"`, `"class"`, `"level"`).
- Produces: `BattleController.hovered_unit`, `BattleController.
  inspected_unit`, `BattleController.get_focused_unit() -> Variant`,
  signal `BattleController.unit_focus_changed(unit)`. `Battlefield.
  unit_info_panel: Control` (unique name `%UnitInfoPanel`) with methods
  `show_unit(unit)` / `clear()`.

## Context you need before starting

- `battle_controller.gd`'s `_select_unit(unit)` (private, called by every
  selection path: clicking your own unit, `select_unit_by_adventurer_id`,
  `end_turn()`'s round-start auto-select) is the single chokepoint for
  "the selected unit changed." Folding the new "pinned inspect" state into
  this one method, instead of scattering calls at every call site, keeps
  selection and inspection in sync everywhere for free — including
  clearing the panel when `_select_unit(null)` runs at enemy-turn start.
- `_handle_tile_click()`'s existing branches
  (`scripts/battle/battle_controller.gd:396-413`) are: click your own unit
  → select; click an enemy in attack range with a unit selected → attack;
  **click an enemy that's neither of those → currently nothing happens**.
  That third branch is exactly where the new pin-on-click goes — no
  existing behavior in that branch needs to change, you're only adding to
  the case that currently does nothing.
- `_unhandled_input()` currently only branches on
  `InputEventMouseButton`/`InputEventKey`. `InputEventMouseMotion` needs a
  new branch. `make_input_local(event)` is a built-in `CanvasItem` method
  already used by `_handle_mouse_input()` on this same node — reuse it,
  don't reimplement tile-position math.
- `PortraitPanel` (an existing `Control` script attached directly to a
  node inside `battlefield.tscn`, not a separate instanced `.tscn`) is the
  precedent to follow: this new panel is the same shape — a plain
  `Control` node with a script, living inside `battlefield.tscn`'s HUD,
  not its own scene file.
- The `BodyRow` `HBoxContainer` currently holds only `PortraitPanel`
  (fixed-width, pinned to the left by nothing pushing it — the grid itself
  renders separately, outside the HUD's `CanvasLayer`). To pin the new
  panel to the *right* edge, `BodyRow` needs `size_flags_horizontal = 3`
  (so it actually fills the VBox's width) plus a spacer `Control` between
  `PortraitPanel` and the new panel with `size_flags_horizontal = 3` (so
  it — not either panel — absorbs the extra width) **and**
  `mouse_filter = MOUSE_FILTER_IGNORE` (an empty `Control` defaults to
  `MOUSE_FILTER_STOP`, which would silently swallow every click/hover over
  the middle of the board — this exact pitfall is already called out
  repeatedly in `portrait_panel.gd`'s comments; don't reintroduce it here).

## Step 3a: Hover and pinned-click tracking on `BattleController`

- [ ] **Write the failing tests**

Add to `tests/unit/test_battle_controller.gd`, after
`test_wasd_step_is_rejected_for_a_target_outside_the_grid`:

```gdscript
func _motion_event_over(controller: Node2D, grid_pos: Vector2i) -> InputEventMouseMotion:
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = (
		controller.global_position + Vector2(grid_pos) * BattleControllerScript.TILE_SIZE + Vector2(32, 32)
	)
	return motion_event


func test_hovering_a_tile_with_a_unit_sets_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.hovered_unit, enemy)


func test_hovering_empty_ground_clears_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(0, 0)))

	assert_null(controller.hovered_unit)


func test_clicking_an_out_of_range_enemy_pins_it_without_attacking() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(controller.inspected_unit, enemy)
	assert_true(enemy.is_alive(), "Clicking an out-of-range enemy must not attack it")


func test_clicking_an_attackable_enemy_still_attacks_instead_of_pinning() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller._handle_tile_click(enemy.grid_position)

	assert_true(attacker.has_acted, "An in-range click must still resolve as an attack, unchanged")


func test_selecting_a_unit_pins_it_as_the_inspected_unit() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [warrior]

	controller._select_unit(warrior)

	assert_eq(controller.inspected_unit, warrior)


func test_get_focused_unit_prefers_the_live_hover_over_the_pinned_click() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [warrior, enemy]
	controller._select_unit(warrior)
	assert_eq(controller.get_focused_unit(), warrior, "With nothing hovered, the pinned selection shows")

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.get_focused_unit(), enemy, "A live hover must take priority over the pinned click")


func test_unit_focus_changed_emits_when_the_focused_unit_changes() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	var received: Array = []
	controller.unit_focus_changed.connect(func(unit) -> void: received.append(unit))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(received, [enemy])
```

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=hover -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=pin -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=focused -gexit
```
Expected: FAIL — `hovered_unit`/`inspected_unit`/`get_focused_unit`/
`unit_focus_changed` don't exist yet.

- [ ] **Implement in `battle_controller.gd`**

Add the signal next to the existing `enemy_defeated` signal:

```gdscript
## Emitted whenever get_focused_unit()'s result changes -- either a live
## hover moved onto/off of a unit, or the pinned inspected_unit changed
## (see _select_unit()/_handle_tile_click()). Carries the new focused unit,
## or null when nothing is focused. Battlefield connects this to drive the
## new right-side unit detail panel; it never affects selection, movement,
## or combat.
signal unit_focus_changed(unit)
```

Add the two new fields next to `selected_unit`:

```gdscript
var hovered_unit = null
var inspected_unit = null
```

Change `_unhandled_input()`:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key_input(event)
```

Add the new handler and the three small hover/inspect methods, near
`_handle_mouse_input()`:

```gdscript
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var tile_pos := _to_grid_position(make_input_local(event).position)
	var unit = get_unit_at(tile_pos) if grid.is_in_bounds(tile_pos) else null
	_set_hovered_unit(unit)


func _set_hovered_unit(unit) -> void:
	if unit == hovered_unit:
		return
	hovered_unit = unit
	_emit_focus_changed()


## Only called from the one _handle_tile_click() branch where a click
## neither selects your own unit nor resolves as an attack (see that
## method) -- every selection path instead goes through _select_unit(),
## which pins the same way for free.
func _set_inspected_unit(unit) -> void:
	inspected_unit = unit
	_emit_focus_changed()


func get_focused_unit():
	return hovered_unit if hovered_unit != null else inspected_unit


func _emit_focus_changed() -> void:
	unit_focus_changed.emit(get_focused_unit())
```

Modify `_select_unit()` (add one line):

```gdscript
func _select_unit(unit) -> void:
	selected_unit = unit
	_set_inspected_unit(unit)
	_update_highlights()
	board_changed.emit()
```

Modify `_handle_tile_click()`'s third branch — replace:

```gdscript
		if selected_unit != null and try_attack_selected_unit(tile_pos):
			_draw_units()
			_select_unit_after_action()
		return
```

with:

```gdscript
		if selected_unit != null and try_attack_selected_unit(tile_pos):
			_draw_units()
			_select_unit_after_action()
			return
		_set_inspected_unit(clicked_unit)
		return
```

(The rest of `_handle_tile_click()` — the own-unit-select branch above it
and the move-fallback below it — is untouched.)

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
```
Expected: `N/N passed.` — every pre-existing test in this file too (the
`_select_unit()` change only adds a call, it doesn't alter
`selected_unit`/`board_changed` behavior; the `_handle_tile_click()`
change only adds a new final line to a branch that previously did
nothing).

- [ ] **Commit**

```bash
git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git commit -m "feat: track a hovered/pinned focused unit on the battlefield"
```

## Step 3b: The detail panel itself

- [ ] **Write the failing tests**

Add to `tests/unit/test_localization.gd`, right after the new
`battle.log.*` assertions from Step 2:

```gdscript
	assert_eq(tr("battle.unit_info.empty"), "Hover or click a unit to see its details.")
	assert_eq(tr("battle.unit_info.hp") % [3, 8], "HP: 3/8")
	assert_eq(tr("battle.unit_info.healthy"), "Healthy")
	assert_eq(tr("battle.unit_info.wounded"), "Wounded")
	assert_eq(tr("battle.unit_info.badly_wounded"), "Badly Wounded")
```

Add to `tests/unit/test_battlefield.gd`, after
`test_hud_top_right_stack_holds_turn_label_end_turn_and_information_panel`:

```gdscript
func test_unit_info_panel_starts_empty() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_true(battlefield.unit_info_panel.get_node("Content/EmptyLabel").visible)
	assert_false(battlefield.unit_info_panel.get_node("Content/NameLabel").visible)


func test_unit_info_panel_shows_exact_hp_name_class_and_level_for_a_player_unit() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	battlefield.grid._set_hovered_unit(warrior)

	var panel: Control = battlefield.unit_info_panel
	assert_false(panel.get_node("Content/EmptyLabel").visible)
	assert_true(panel.get_node("Content/NameLabel").visible)
	assert_eq(panel.get_node("Content/NameLabel").text, "Warrior")
	assert_eq(panel.get_node("Content/ClassLabel").text, tr("information.class") % "warrior")
	assert_eq(panel.get_node("Content/LevelLabel").text, tr("information.level") % 1)
	assert_eq(panel.get_node("Content/HpLabel").text, tr("battle.unit_info.hp") % [10, 10])
	assert_false(panel.get_node("Content/WoundLabel").visible, "Enemies-only row must stay hidden for a player unit")


func test_unit_info_panel_shows_only_a_wound_tier_for_an_enemy_never_exact_hp() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	battlefield.grid._set_hovered_unit(goblin)

	var panel: Control = battlefield.unit_info_panel
	assert_eq(panel.get_node("Content/NameLabel").text, goblin.display_name)
	assert_true(panel.get_node("Content/WoundLabel").visible)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.healthy"))
	assert_false(panel.get_node("Content/HpLabel").visible, "Player-only row must stay hidden for an enemy")
	assert_false(panel.get_node("Content/ClassLabel").visible)
	assert_false(panel.get_node("Content/LevelLabel").visible)


func test_unit_info_panel_wound_tiers_match_the_health_percentage_thresholds() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var panel: Control = battlefield.unit_info_panel

	goblin.health = goblin.max_health  # 100%
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.healthy"))

	goblin.health = int(goblin.max_health * 0.5)  # 50%, inside the 34-66% band
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.wounded"))

	goblin.health = 1  # well under 33%
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.badly_wounded"))


func test_unit_info_panel_clears_back_to_empty_when_focus_is_lost() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	battlefield.grid._set_hovered_unit(goblin)

	battlefield.grid._set_hovered_unit(null)

	assert_true(battlefield.unit_info_panel.get_node("Content/EmptyLabel").visible)
	assert_false(battlefield.unit_info_panel.get_node("Content/NameLabel").visible)


func test_unit_info_panel_lives_to_the_right_of_the_portrait_panel() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.unit_info_panel.get_parent(), battlefield.portrait_panel.get_parent())
	var body_row: Node = battlefield.unit_info_panel.get_parent()
	assert_gt(
		battlefield.unit_info_panel.get_index(), battlefield.portrait_panel.get_index(),
		"The unit info panel must sit after (visually to the right of) the portrait panel in BodyRow"
	)
```

(`GameSession.WARRIOR_ID`'s adventurer dict has `"class": "warrior"`,
`"level": 1`, `"name": "Warrior"`, matching the values already asserted
elsewhere, e.g. `test_every_member_renders_as_a_row_with_name_class_and_level`
in `test_party_details.gd`.)

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gunit_test_name=unit_info -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gunit_test_name=unit_info_panel -gexit
```
Expected: FAIL — the `battle.unit_info.*` keys and `battlefield.
unit_info_panel` don't exist yet.

- [ ] **Add the translation keys**

In `translations/en.tres`, in the `battle.*` block, right after the
`battle.log.*` keys added in Step 2:

```
"battle.unit_info.empty": "Hover or click a unit to see its details.",
"battle.unit_info.hp": "HP: %d/%d",
"battle.unit_info.healthy": "Healthy",
"battle.unit_info.wounded": "Wounded",
"battle.unit_info.badly_wounded": "Badly Wounded",
```

(`information.class` and `information.level` already exist —
`"Class: %s"` / `"Level: %d"` — and are reused as-is rather than
duplicated.)

- [ ] **Create `scripts/battle/unit_info_panel.gd`**

```gdscript
extends PanelContainer

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const HEALTHY_THRESHOLD := 0.66
const WOUNDED_THRESHOLD := 0.33

@onready var empty_label: Label = $Content/EmptyLabel
@onready var name_label: Label = $Content/NameLabel
@onready var class_label: Label = $Content/ClassLabel
@onready var level_label: Label = $Content/LevelLabel
@onready var hp_label: Label = $Content/HpLabel
@onready var wound_label: Label = $Content/WoundLabel


func clear() -> void:
	empty_label.visible = true
	name_label.visible = false
	class_label.visible = false
	level_label.visible = false
	hp_label.visible = false
	wound_label.visible = false


func show_unit(unit) -> void:
	if unit == null:
		clear()
		return

	empty_label.visible = false
	name_label.visible = true
	name_label.text = unit.display_name

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	class_label.visible = is_player
	level_label.visible = is_player
	hp_label.visible = is_player
	wound_label.visible = not is_player

	if is_player:
		var adventurer := GameSession.get_adventurer(unit.adventurer_id)
		class_label.text = tr("information.class") % adventurer.get("class", "")
		level_label.text = tr("information.level") % adventurer.get("level", 0)
		hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	else:
		wound_label.text = tr(_wound_tier_key(unit))


func _wound_tier_key(unit) -> String:
	if unit.max_health <= 0:
		return "battle.unit_info.badly_wounded"
	var health_percent: float = float(unit.health) / float(unit.max_health)
	if health_percent > HEALTHY_THRESHOLD:
		return "battle.unit_info.healthy"
	if health_percent > WOUNDED_THRESHOLD:
		return "battle.unit_info.wounded"
	return "battle.unit_info.badly_wounded"
```

- [ ] **Add the panel to `battlefield.tscn`**

Replace the `BodyRow` node and its `PortraitPanel` child block with (new
`size_flags_horizontal` on `BodyRow`, new `Spacer` and `UnitInfoPanel`
siblings after `PortraitPanel`):

```
[node name="BodyRow" type="HBoxContainer" parent="HUD/Margin/VBox"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="PortraitPanel" type="Control" parent="HUD/Margin/VBox/BodyRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
custom_minimum_size = Vector2(204, 0)
script = ExtResource("4_portrait_panel")

[node name="Rows" type="VBoxContainer" parent="HUD/Margin/VBox/BodyRow/PortraitPanel"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Spacer" type="Control" parent="HUD/Margin/VBox/BodyRow"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="UnitInfoPanel" type="PanelContainer" parent="HUD/Margin/VBox/BodyRow"]
unique_name_in_owner = true
layout_mode = 2
size_flags_vertical = 3
custom_minimum_size = Vector2(220, 0)
script = ExtResource("5_unit_info_panel")

[node name="Content" type="VBoxContainer" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="EmptyLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
autowrap_mode = 3
text = "battle.unit_info.empty"

[node name="NameLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
visible = false

[node name="ClassLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
visible = false

[node name="LevelLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
visible = false

[node name="HpLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
visible = false

[node name="WoundLabel" type="Label" parent="HUD/Margin/VBox/BodyRow/UnitInfoPanel/Content"]
layout_mode = 2
visible = false
```

`mouse_filter = 2` on `Spacer` is `Control.MOUSE_FILTER_IGNORE` (Godot's
`.tscn` text format stores the enum's integer value).

Also add the new `ext_resource` line near the top of the file (next to
`4_portrait_panel`):

```
[ext_resource type="Script" path="res://scripts/battle/unit_info_panel.gd" id="5_unit_info_panel"]
```

And bump the scene's `load_steps` header count by 1 to match the new
`ext_resource` (read the current value at the top of the file and
increment it by exactly 1 — Godot doesn't strictly require this to be
exact, but keep it accurate rather than leaving it stale).

- [ ] **Wire it up in `battlefield.gd`**

Add the `@onready` field next to `portrait_panel`:

```gdscript
@onready var unit_info_panel: Control = %UnitInfoPanel
```

In `_ready()`, connect the new signal right after the existing
`grid.enemy_defeated.connect(_award_kill_xp)` line:

```gdscript
	grid.unit_focus_changed.connect(_on_unit_focus_changed)
```

Add the handler near `_on_board_changed()`:

```gdscript
func _on_unit_focus_changed(unit) -> void:
	unit_info_panel.show_unit(unit)
```

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```
Expected: `N/N passed.` for both files, including every pre-existing
`test_battlefield.gd` test (in particular the `BodyRow`/`PortraitPanel`
structural tests — `test_bottom_panel_does_not_share_a_parent_with_the_
portrait_panel` and `test_portrait_panel_is_container_driven_not_offset_
positioned` — since `PortraitPanel`'s own subtree and node path are
unchanged, only its siblings within `BodyRow` changed).

- [ ] **Commit**

```bash
git add scripts/battle/unit_info_panel.gd scripts/battle/battlefield.gd scenes/battle/battlefield.tscn translations/en.tres tests/unit/test_battlefield.gd tests/unit/test_localization.gd
git commit -m "feat: show hovered/clicked unit detail in a new battle HUD panel"
```

## Manual verification

1. `make play`
2. Debug menu (**FN+F9**) → **Ruined Fortress**.
3. Hover the mouse over one of your own Warriors: confirm the right panel
   shows its name, class, level, and exact HP (e.g. `HP: 10/10`).
4. Hover over a Kobold: confirm the panel shows its name (`"Kobold N"`)
   and a wound tier (`Healthy`), never a number.
5. Attack a Kobold a few times to drop its HP below two-thirds, then
   below a third; re-hover it and confirm the tier label updates to
   `Wounded` then `Badly Wounded`.
6. Move the mouse off the grid entirely (over empty UI chrome): confirm
   the panel falls back to showing whichever unit you last selected or
   clicked (not a blank state) — then click empty ground to deselect and
   confirm it now shows the empty-state hint text.
7. With a unit selected that has an out-of-range enemy nearby, click that
   enemy: confirm it is **not** attacked (health unchanged) and the panel
   now shows its detail. Then click an enemy that **is** in range: confirm
   it still resolves as a normal attack, exactly as before this step.

## Full run and merge

```bash
make check
```
Expected: `N/N passed.` / `---- All tests passed! ----`, exit 0.

```bash
git checkout main
git merge unit-hover-click-detail-panel
git branch -d unit-hover-click-detail-panel
```
