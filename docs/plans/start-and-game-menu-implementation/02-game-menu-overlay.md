# Step 02: Game Menu Overlay

## Milestone

A new `game_menu` overlay opens on Escape from every gameplay scene
(battlefield, world map, encampment, party manager, starting settlement),
pausing the game underneath instead of destroying its state. Return (or
Escape again) closes it and resumes exactly where the player left off. Save
shows "Not implemented yet"; Load is grayed out via the same
`GameManager.has_saved_game` flag `start_menu` uses; Quit works the same as
`start_menu`'s Quit.

## Setup

Step 01 must be merged into `main`. Preserve unrelated working-tree edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/game-menu-overlay
```

## Files

- Create: `scenes/ui/game_menu.tscn`
- Create: `scripts/ui/game_menu.gd`
- Create: `scripts/ui/game_menu.gd.uid` (Godot generates this the first time
  the script is opened/run; add it to git once it appears)
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/world/world_map.gd`
- Modify: `scripts/ui/encampment.gd`
- Modify: `scripts/ui/party_manager.gd`
- Modify: `scripts/local/starting_settlement.gd`
- Modify: `translations/en.tres`
- Create: `tests/unit/test_game_menu.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_encampment.gd`
- Modify: `tests/unit/test_party_manager.gd`
- Modify: `tests/unit/test_starting_settlement.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing tests for the overlay and open/close routing

Create `tests/unit/test_game_menu.gd`:

```gdscript
extends GutTest

const GameMenuScene := preload("res://scenes/ui/game_menu.tscn")


func before_each() -> void:
	GameManager.has_saved_game = false


func test_load_is_disabled_without_a_saved_game() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_true(menu.get_node("Center/VBox/LoadButton").disabled)


func test_return_save_and_quit_are_always_enabled() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.get_node("Center/VBox/ReturnButton").disabled)
	assert_false(menu.get_node("Center/VBox/SaveButton").disabled)
	assert_false(menu.get_node("Center/VBox/QuitButton").disabled)


func test_pressing_save_shows_the_not_implemented_status() -> void:
	var menu: CanvasLayer = GameMenuScene.instantiate()
	add_child_autofree(menu)
	var status: Label = menu.get_node("Center/VBox/StatusLabel")

	menu.get_node("Center/VBox/SaveButton").emit_signal("pressed")

	assert_true(status.visible)
	assert_eq(status.text, "menu.not_implemented")
```

Add open/close coverage to `tests/unit/test_game_manager.gd`:

```gdscript
func test_open_game_menu_shows_the_overlay_and_pauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.open_game_menu()

	assert_true(manager._game_menu.visible)
	assert_true(get_tree().paused)

	manager.close_game_menu()


func test_close_game_menu_hides_the_overlay_and_unpauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.open_game_menu()

	manager.close_game_menu()

	assert_false(manager._game_menu.visible)
	assert_false(get_tree().paused)
```

Update the existing Escape assertion in `tests/unit/test_battlefield.gd` to
expect the overlay instead of a scene change:

```gdscript
func test_escape_marks_input_handled_before_opening_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/battle/battlefield.gd")
	var handle_input_at := source.find("get_viewport().set_input_as_handled()")
	var open_menu_at := source.find("GameManager.open_game_menu()")

	assert_ne(handle_input_at, -1, "Battlefield must mark Escape input as handled")
	assert_ne(open_menu_at, -1, "Battlefield must open the game menu on Escape")
	assert_lt(
		handle_input_at,
		open_menu_at,
		"Battlefield must handle Escape before opening the overlay"
	)
```

Add the same kind of source-scan assertion to the other gameplay scene test
files. `tests/unit/test_world_map.gd` (add as a new function):

```gdscript
func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world/world_map.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
```

`tests/unit/test_encampment.gd` (add as a new function):

```gdscript
func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/encampment.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
```

`tests/unit/test_party_manager.gd` (add as a new function):

```gdscript
func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_manager.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
```

`tests/unit/test_starting_settlement.gd` (add as a new function):

```gdscript
func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/local/starting_settlement.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
```

Update the two hint strings in `tests/unit/test_localization.gd` that
mention "main menu" (Escape no longer takes you there):

```gdscript
	assert_eq(
		tr("battle.hint.select_unit") % "Player",
		"Player turn. Click a unit to select it. Esc: menu."
	)
```

```gdscript
	assert_eq(
		tr("world_map.hint"),
		(
			"World Map. Click the party to select it, then click a highlighted tile to move. "
			+ "Click the marked location to enter battle. Return to the settlement by clicking a selected party there. "
			+ "Esc: menu."
		)
	)
```

Add the new `game_menu` translation-key assertions to
`test_translation_keys_resolve_to_expected_english_copy()`:

```gdscript
	assert_eq(tr("menu.return"), "Return")
	assert_eq(tr("menu.save"), "Save")
	assert_eq(tr("menu.not_implemented"), "Not implemented yet")
```

Run `make test`. It must fail: `game_menu.tscn`, `GameManager.open_game_menu`
/ `close_game_menu`, and the new translation keys don't exist yet.

### 2. Add the `game_menu` scene and script

Create `scenes/ui/game_menu.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/game_menu.gd" id="1_menu"]

[node name="GameMenu" type="CanvasLayer"]
script = ExtResource("1_menu")

[node name="Dim" type="ColorRect" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0, 0, 0, 0.6)

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="ReturnButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.return"

[node name="SaveButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.save"

[node name="LoadButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.load"

[node name="QuitButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.quit"

[node name="StatusLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
text = ""
visible = false
horizontal_alignment = 1

[connection signal="pressed" from="Center/VBox/ReturnButton" to="." method="_on_return_pressed"]
[connection signal="pressed" from="Center/VBox/SaveButton" to="." method="_on_save_pressed"]
[connection signal="pressed" from="Center/VBox/QuitButton" to="." method="_on_quit_pressed"]
```

`LoadButton` has no `pressed` connection — same reasoning as `start_menu`:
it's always disabled right now, so it never emits `pressed`.

Create `scripts/ui/game_menu.gd`:

```gdscript
extends CanvasLayer

@onready var load_button: Button = $Center/VBox/LoadButton
@onready var status_label: Label = $Center/VBox/StatusLabel


func _ready() -> void:
	# PROCESS_MODE_ALWAYS keeps this overlay (and its buttons, which inherit
	# it) receiving input even while GameManager pauses the tree to open it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	load_button.disabled = not GameManager.has_saved_game


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.close_game_menu()


func _on_return_pressed() -> void:
	GameManager.close_game_menu()


func _on_save_pressed() -> void:
	status_label.text = tr("menu.not_implemented")
	status_label.visible = true


func _on_quit_pressed() -> void:
	GameManager.quit_game()
```

### 3. Wire `GameManager.open_game_menu()` / `close_game_menu()`

In `scripts/autoload/game_manager.gd`, add the scene constant, the persistent
overlay instance, and the two new methods:

```gdscript
const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const PARTY_MANAGER_SCENE := "res://scenes/ui/party_manager.tscn"
const ENCAMPMENT_SCENE := "res://scenes/ui/encampment.tscn"
const STARTING_SETTLEMENT_SCENE := "res://scenes/local/starting_settlement.tscn"
const WORLD_MAP_SCENE := "res://scenes/world/world_map.tscn"
const BATTLEFIELD_SCENE := "res://scenes/battle/battlefield.tscn"
const GAME_MENU_SCENE := "res://scenes/ui/game_menu.tscn"

const EN_TRANSLATION := preload("res://translations/en.tres")

# Hardcoded until a real save system exists; both menus read this to decide
# whether Continue/Load are available.
var has_saved_game: bool = false

var _game_menu: CanvasLayer


func _ready() -> void:
	TranslationServer.add_translation(EN_TRANSLATION)
	# Added as our own child (instead of per-scene) so one instance persists
	# across every scene change.
	_game_menu = preload(GAME_MENU_SCENE).instantiate()
	add_child(_game_menu)


func open_game_menu() -> void:
	_game_menu.visible = true
	get_tree().paused = true


func close_game_menu() -> void:
	_game_menu.visible = false
	get_tree().paused = false
```

Leave every other method unchanged.

### 4. Point Escape at the overlay in every gameplay scene

`scripts/battle/battlefield.gd`:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
```

`scripts/world/world_map.gd` (only the Escape branch changes; keep the mouse
handling below it):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
		return
	...
```

`scripts/ui/encampment.gd` (new handler; rest of the file is unchanged):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
```

`scripts/ui/party_manager.gd` (new handler; rest of the file is unchanged):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
```

`scripts/local/starting_settlement.gd` (new handler; rest of the file is
unchanged):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()
```

### 5. Add translations and update the Escape hint copy

Add three keys to `translations/en.tres` (insert after `"menu.load"`):

```text
"menu.return": "Return",
"menu.save": "Save",
"menu.not_implemented": "Not implemented yet",
```

Update the two existing hint strings that reference "main menu" (Escape no
longer takes you there):

```text
"battle.hint.select_unit": "%s turn. Click a unit to select it. Esc: menu.",
```

```text
"world_map.hint": "World Map. Click the party to select it, then click a highlighted tile to move. Click the marked location to enter battle. Return to the settlement by clicking a selected party there. Esc: menu."
```

### 6. Verify green

```bash
make check
```

Expected: all tests pass, including the new `test_game_menu.gd` and the
updated battlefield/world_map/encampment/party_manager/starting_settlement/
localization/game_manager tests.

### 7. Manual verification

Run `make play`. Start a new game, then in the starting settlement, the
encampment, the world map, and a battle (via the goblin-camp encounter),
press Escape and confirm each time:

- The game screen dims and Return/Save/Load/Quit appear on top of it — the
  underlying scene is still visible, not replaced.
- Load is grayed out; Save shows "Not implemented yet" when clicked.
- Return closes the overlay and you're back exactly where you were (party
  position, encampment state, battle board all unchanged).
- Pressing Escape again while the overlay is open also closes it.
- Quit closes the game.

Also confirm gameplay actually pauses: while the overlay is open on the world
map, clicking where the party would move does nothing until you close the
menu.

## Commit and handoff

```bash
git add docs/plans/start-and-game-menu-implementation/index.md docs/plans/start-and-game-menu-implementation/02-game-menu-overlay.md scenes/ui/game_menu.tscn scripts/ui/game_menu.gd scripts/ui/game_menu.gd.uid scripts/autoload/game_manager.gd scripts/battle/battlefield.gd scripts/world/world_map.gd scripts/ui/encampment.gd scripts/ui/party_manager.gd scripts/local/starting_settlement.gd translations/en.tres tests/unit/test_game_menu.gd tests/unit/test_game_manager.gd tests/unit/test_battlefield.gd tests/unit/test_world_map.gd tests/unit/test_encampment.gd tests/unit/test_party_manager.gd tests/unit/test_starting_settlement.gd tests/unit/test_localization.gd
git commit -m "feat: add game menu overlay opened by Escape during gameplay"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/game-menu-overlay
git branch -d feat/game-menu-overlay
git status --short
```

Do not push.
