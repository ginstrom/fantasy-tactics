# Step 01: Start Menu Split

## Milestone

`main_menu` is renamed to `start_menu` throughout the codebase. It gains
`Continue` and `Load` buttons, both grayed out via a new
`GameManager.has_saved_game` flag hardcoded to `false`. `New Game` and `Quit`
keep their current behavior. Escape still returns to this same menu from
gameplay (that destructive behavior isn't fixed until Step 02) — only its
target scene's name changes.

## Setup

Preserve unrelated working-tree edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/start-menu-split
```

## Files

- Rename: `scenes/ui/main_menu.tscn` -> `scenes/ui/start_menu.tscn`
- Rename: `scripts/ui/main_menu.gd` -> `scripts/ui/start_menu.gd`
- Rename: `scripts/ui/main_menu.gd.uid` -> `scripts/ui/start_menu.gd.uid`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/boot/boot.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/world/world_map.gd`
- Modify: `translations/en.tres`
- Create: `tests/unit/test_start_menu.gd`
- Modify: `tests/unit/test_localization.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_boot.gd`

## Red/green implementation

### 1. Rename the scene and script

```bash
git mv scenes/ui/main_menu.tscn scenes/ui/start_menu.tscn
git mv scripts/ui/main_menu.gd scripts/ui/start_menu.gd
git mv scripts/ui/main_menu.gd.uid scripts/ui/start_menu.gd.uid
```

Update the `ext_resource` path and root node name inside
`scenes/ui/start_menu.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/start_menu.gd" id="1_menu"]

[node name="StartMenu" type="Control"]
```

(Leave the rest of the file's structure as-is for now — buttons are added in
step 4 below.)

### 2. Write failing tests for the rename and the new buttons

In `tests/unit/test_localization.gd`, rename the `MainMenuScene` constant and
its test:

```gdscript
const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")
```

```gdscript
func test_start_menu_uses_translation_keys_not_literal_copy() -> void:
	var start_menu: Control = StartMenuScene.instantiate()
	add_child_autofree(start_menu)

	assert_eq(start_menu.get_node("Center/VBox/Title").text, "menu.title")
	assert_eq(start_menu.get_node("Center/VBox/ContinueButton").text, "menu.continue")
	assert_eq(start_menu.get_node("Center/VBox/NewGameButton").text, "menu.new_game")
	assert_eq(start_menu.get_node("Center/VBox/LoadButton").text, "menu.load")
	assert_eq(start_menu.get_node("Center/VBox/QuitButton").text, "menu.quit")
```

Add two new lines to `test_translation_keys_resolve_to_expected_english_copy()`:

```gdscript
	assert_eq(tr("menu.continue"), "Continue")
	assert_eq(tr("menu.load"), "Load")
```

Create `tests/unit/test_start_menu.gd`:

```gdscript
extends GutTest

const StartMenuScene := preload("res://scenes/ui/start_menu.tscn")


func test_continue_and_load_are_disabled_without_a_saved_game() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/ContinueButton").disabled)
	assert_true(screen.get_node("Center/VBox/LoadButton").disabled)


func test_new_game_and_quit_are_always_enabled() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/NewGameButton").disabled)
	assert_false(screen.get_node("Center/VBox/QuitButton").disabled)
```

In `tests/unit/test_game_manager.gd`, add:

```gdscript
func test_start_menu_route_uses_start_menu_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/start_menu.tscn")
	assert_string_contains(source, "go_to_start_menu()")
```

In `tests/unit/test_battlefield.gd`, update the existing assertion to expect
the renamed method:

```gdscript
func test_escape_marks_input_handled_before_changing_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/battle/battlefield.gd")
	var handle_input_at := source.find("get_viewport().set_input_as_handled()")
	var change_scene_at := source.find("GameManager.go_to_start_menu()")

	assert_ne(handle_input_at, -1, "Battlefield must mark Escape input as handled")
	assert_ne(change_scene_at, -1, "Battlefield must return to the start menu on Escape")
	assert_lt(
		handle_input_at,
		change_scene_at,
		"Battlefield must handle Escape before changing scenes, which detaches its viewport"
	)
```

In `tests/unit/test_boot.gd`, rename the test for clarity (no behavior
change):

```gdscript
func test_boot_defers_start_menu_transition() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/boot/boot.gd")
	assert_true(
		source.contains("call_deferred"),
		"Boot must defer the start-menu transition; sync change_scene in _ready errors"
	)
```

Run `make test`. It must fail: the new buttons/keys and the renamed
`go_to_start_menu()` method don't exist yet.

### 3. Rename the GameManager route and add `has_saved_game`

In `scripts/autoload/game_manager.gd`, rename the constant and method, and
add the new flag:

```gdscript
extends Node

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const PARTY_MANAGER_SCENE := "res://scenes/ui/party_manager.tscn"
const ENCAMPMENT_SCENE := "res://scenes/ui/encampment.tscn"
const STARTING_SETTLEMENT_SCENE := "res://scenes/local/starting_settlement.tscn"
const WORLD_MAP_SCENE := "res://scenes/world/world_map.tscn"
const BATTLEFIELD_SCENE := "res://scenes/battle/battlefield.tscn"

const EN_TRANSLATION := preload("res://translations/en.tres")

# Hardcoded until a real save system exists; both menus read this to decide
# whether Continue/Load are available.
var has_saved_game: bool = false


func _ready() -> void:
	TranslationServer.add_translation(EN_TRANSLATION)


func go_to_start_menu() -> Error:
	return _change_scene(START_MENU_SCENE)
```

Leave every other method in the file unchanged.

Update the two remaining call sites that still reference the old name:

`scripts/boot/boot.gd`:

```gdscript
extends Node


func _ready() -> void:
	# change_scene_to_file cannot run while the tree is still building this node.
	call_deferred("_enter_start_menu")


func _enter_start_menu() -> void:
	GameManager.go_to_start_menu()
```

`scripts/battle/battlefield.gd` (only the `_unhandled_input` body changes):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_start_menu()
```

`scripts/world/world_map.gd` (only the `_unhandled_input` body changes):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_start_menu()
		return
	...
```

(Keep the rest of `world_map.gd`'s `_unhandled_input` — the mouse-click
handling below the early `return` — unchanged.)

### 4. Add the Continue/Load buttons and translations

Add `ContinueButton` and `LoadButton` nodes to
`scenes/ui/start_menu.tscn`, in this order (Continue, New Game, Load, Quit):

```text
[node name="ContinueButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.continue"

[node name="NewGameButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.new_game"

[node name="LoadButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.load"

[node name="QuitButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "menu.quit"

[connection signal="pressed" from="Center/VBox/ContinueButton" to="." method="_on_continue_pressed"]
[connection signal="pressed" from="Center/VBox/NewGameButton" to="." method="_on_new_game_pressed"]
[connection signal="pressed" from="Center/VBox/QuitButton" to="." method="_on_quit_pressed"]
```

`LoadButton` has no `pressed` connection — it's always disabled for now, and
disabled buttons never emit `pressed`.

Replace `scripts/ui/start_menu.gd` with:

```gdscript
extends Control

@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var load_button: Button = $Center/VBox/LoadButton


func _ready() -> void:
	continue_button.disabled = not GameManager.has_saved_game
	load_button.disabled = not GameManager.has_saved_game


func _on_continue_pressed() -> void:
	# No save system yet, so Continue starts a new game like New Game does.
	# This becomes real resume-from-save logic once save/load exists.
	GameManager.go_to_game()


func _on_new_game_pressed() -> void:
	GameManager.go_to_game()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
```

Add two keys to `translations/en.tres` (insert after `"menu.quit"`):

```text
"menu.continue": "Continue",
"menu.load": "Load",
```

### 5. Verify green

```bash
make check
```

Expected: all tests pass, including the new `test_start_menu.gd` and the
updated localization/battlefield/game_manager/boot tests.

### 6. Manual verification

Run `make editor`, then run `start_menu.tscn` directly (top toolbar ▶ next to
the scene, or F6). Confirm:

- Continue and Load appear grayed out and unclickable.
- New Game is clickable and starts a game (routes to the starting
  settlement).
- Quit is clickable (closes the running scene).

Then run `make play` from the project root and confirm the game still boots
straight into this same start menu.

Close the editor without committing any generated files beyond the new
`.uid` file Godot creates for `start_menu.gd` (already renamed above) — check
`git status --short` and make sure nothing unexpected shows up.

## Commit and handoff

```bash
git add docs/plans/start-and-game-menu-implementation/index.md docs/plans/start-and-game-menu-implementation/01-start-menu-split.md docs/plans/start-and-game-menu-implementation/02-game-menu-overlay.md scenes/ui/start_menu.tscn scripts/ui/start_menu.gd scripts/ui/start_menu.gd.uid scripts/autoload/game_manager.gd scripts/boot/boot.gd scripts/battle/battlefield.gd scripts/world/world_map.gd translations/en.tres tests/unit/test_start_menu.gd tests/unit/test_localization.gd tests/unit/test_battlefield.gd tests/unit/test_game_manager.gd tests/unit/test_boot.gd
git commit -m "feat: split main menu into start menu with continue/load"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/start-menu-split
git branch -d feat/start-menu-split
git status --short
```

Do not push.
