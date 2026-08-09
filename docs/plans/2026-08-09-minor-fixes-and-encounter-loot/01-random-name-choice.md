# Step 1: Random Name Choice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `random-name-choice`

**Goal:** Add a `[Random]` button (dice emoji) below both the player-name
box on the Start Menu and a new party-name box on the Parties screen. The
player-name choices are "The Black Company" / "Company of Saints"; the
party-name choices are "Party 1" / "Alpha Party". Today the party name is
hardcoded to `"Party 1"` with no player-facing prompt at all — this step
adds that prompt.

**Files:**
- Modify: `scenes/ui/start_menu.tscn`
- Modify: `scripts/ui/start_menu.gd`
- Modify: `scenes/ui/parties.tscn`
- Modify: `scripts/ui/parties.gd`
- Modify: `scripts/autoload/game_session.gd` (`create_party()`)
- Modify: `scripts/autoload/game_manager.gd` (`create_party()`)
- Modify: `translations/en.tres`
- Test: `tests/unit/test_start_menu.gd`
- Test: `tests/unit/test_parties.gd`
- Test: `tests/unit/test_game_session.gd`
- Test: `tests/unit/test_game_manager.gd`
- Test: `tests/unit/test_localization.gd`

## Part A — Player name random button

### Step A1: Write the failing tests

Add to `tests/unit/test_start_menu.gd` (after
`test_begin_button_is_disabled_until_a_name_is_entered`):

```gdscript
func test_random_button_fills_the_name_field_with_one_of_the_two_choices() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)

	screen._on_random_button_pressed()

	var name_input: LineEdit = screen.get_node("Center/VBox/NameEntry/NameInput")
	assert_true(name_input.text in ["The Black Company", "Company of Saints"])


func test_random_button_enables_the_begin_button() -> void:
	var screen: Control = StartMenuScene.instantiate()
	add_child_autofree(screen)
	var begin_button: Button = screen.get_node("Center/VBox/NameEntry/BeginButton")
	assert_true(begin_button.disabled)

	screen._on_random_button_pressed()

	assert_false(begin_button.disabled)
```

### Step A2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_start_menu.gd -gexit
```

Expected: both new tests FAIL — `_on_random_button_pressed` doesn't exist
yet, and `NameEntry/RandomButton` isn't in the scene.

### Step A3: Add the button to the scene

Edit `scenes/ui/start_menu.tscn`. Insert a new `RandomButton` node between
`NameInput` and `BeginButton` inside `NameEntry`, and wire its `pressed`
signal:

```
[node name="RandomButton" type="Button" parent="Center/VBox/NameEntry"]
layout_mode = 2
text = "🎲 menu.random"
```

Add the connection alongside the existing ones at the bottom of the file:

```
[connection signal="pressed" from="Center/VBox/NameEntry/RandomButton" to="." method="_on_random_button_pressed"]
```

(`text` here is a translation key, same as every other button in this
scene — `tr()` resolves it at render time via `translations/en.tres`, added
in Step A4. Godot's default theme font does not render color emoji; the
dice glyph is prefixed literally so it degrades to a plain missing-glyph
box rather than breaking the build — call this out during manual
verification in Step A5.)

### Step A4: Add the translation key

In `translations/en.tres`, add a `menu.random` key next to the other
`menu.*` keys (find `"menu.enter_name": "Enter your name:",` and add a line
after it):

```
"menu.random": "Random",
```

### Step A5: Implement `_on_random_button_pressed`

In `scripts/ui/start_menu.gd`, add the node reference, the choice list, and
the handler:

```gdscript
@onready var random_button: Button = $Center/VBox/NameEntry/RandomButton

const PLAYER_NAME_CHOICES := ["The Black Company", "Company of Saints"]
```

Add the handler function (anywhere among the other `_on_*` functions):

```gdscript
func _on_random_button_pressed() -> void:
	name_input.text = PLAYER_NAME_CHOICES[randi() % PLAYER_NAME_CHOICES.size()]
	_on_name_input_text_changed(name_input.text)
```

### Step A6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_start_menu.gd -gexit
```

Expected: `N/N passed.`

## Part B — Party name prompt and random button

Today `parties.gd`'s `_on_create_party_pressed()` calls
`GameManager.create_party()` immediately, which calls
`GameSession.create_party()`, which hardcodes `"name": "Party 1"`. This
part adds a name-entry sub-view (shown in place of the `Create Party`
button, mirroring Start Menu's `NameEntry` pattern) and threads the entered
name through to `GameSession.create_party(name)`.

### Step B1: Write the failing tests

Add to `tests/unit/test_game_session.gd` (near the existing party-creation
tests — search for `func test_create_party`):

```gdscript
func test_create_party_uses_the_given_name() -> void:
	var session := GameSessionScript.new()
	session.reset()

	session.create_party("Alpha Party")

	assert_eq(session.parties[0].name, "Alpha Party")


func test_create_party_defaults_to_party_1_when_no_name_is_given() -> void:
	var session := GameSessionScript.new()
	session.reset()

	session.create_party()

	assert_eq(session.parties[0].name, "Party 1")
```

(Check the file's existing `GameSessionScript` const/preload at the top —
every other test in this file instantiates the session the same way; match
that pattern exactly rather than introducing a new one.)

Add to `tests/unit/test_game_manager.gd` (near existing `create_party`
coverage — search for `func test_create_party` or
`GameManager.create_party`):

```gdscript
func test_create_party_passes_the_given_name_through_to_game_session() -> void:
	GameManager.create_party("Alpha Party")

	assert_eq(GameSession.parties[0].name, "Alpha Party")
```

Add to `tests/unit/test_parties.gd` (after
`test_create_party_action_creates_exactly_one_party_and_refreshes_the_table`):

```gdscript
func test_create_party_button_reveals_the_name_entry_instead_of_creating_immediately() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var create_button: Button = screen.get_node("Body/Center/VBox/CreatePartyButton")

	create_button.emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 0)
	assert_true(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)
	assert_false(create_button.visible)


func test_party_name_random_button_fills_the_name_field_with_one_of_the_two_choices() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")

	screen._on_party_name_random_button_pressed()

	var name_input: LineEdit = screen.get_node("Body/Center/VBox/PartyNameEntry/NameInput")
	assert_true(name_input.text in ["Party 1", "Alpha Party"])


func test_confirming_the_party_name_creates_the_party_with_that_name_and_hides_the_entry() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")
	var name_input: LineEdit = screen.get_node("Body/Center/VBox/PartyNameEntry/NameInput")
	name_input.text = "Alpha Party"

	screen.get_node("Body/Center/VBox/PartyNameEntry/ConfirmButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.parties[0].name, "Alpha Party")
	assert_false(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)


func test_cancelling_the_party_name_entry_creates_nothing_and_restores_the_button() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")

	screen.get_node("Body/Center/VBox/PartyNameEntry/CancelButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 0)
	assert_false(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)
	assert_true(screen.get_node("Body/Center/VBox/CreatePartyButton").visible)
```

The existing
`test_create_party_action_creates_exactly_one_party_and_refreshes_the_table`
test will now fail too, since `create_button.emit_signal("pressed")` no
longer creates a party immediately — update it in this same step to go
through the new confirm flow:

```gdscript
func test_create_party_action_creates_exactly_one_party_and_refreshes_the_table() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var create_button: Button = screen.get_node("Body/Center/VBox/CreatePartyButton")

	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
	screen.get_node("Body/Center/VBox/PartyNameEntry/ConfirmButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(UiTestHelpers.tree_row_values(screen.get_node("Body/Center/VBox/PartyTable/Tree"), 0), ["Party 1"])
	assert_true(create_button.disabled)
```

(The default name is still `"Party 1"` here since the test never types
into `NameInput` — matches `GameSession.create_party()`'s default.)

### Step B2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_parties.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```

Expected: every new/updated test FAILS.

### Step B3: `GameSession.create_party(name)`

In `scripts/autoload/game_session.gd`, find `func create_party() -> bool:`
(around line 430) and its `"name": "Party 1"` literal. Change the
signature and that literal:

```gdscript
func create_party(party_name: String = "Party 1") -> bool:
```

```gdscript
		"name": party_name,
```

Leave the rest of the function body untouched.

### Step B4: `GameManager.create_party(name)`

In `scripts/autoload/game_manager.gd`, find `func create_party() -> Error:`
(around line 114) and update it to pass the name through:

```gdscript
func create_party(party_name: String = "Party 1") -> Error:
	if not GameSession.create_party(party_name):
		return ERR_INVALID_DATA
	return OK
```

(Match whatever the existing body does with the boolean result — only the
parameter threading changes.)

### Step B5: Add the party-name entry to the scene

Edit `scenes/ui/parties.tscn`. Add a `PartyNameEntry` `VBoxContainer`
sibling of `CreatePartyButton` (initially hidden), containing a prompt
label, a `LineEdit`, a `RandomButton`, and `ConfirmButton`/`CancelButton`:

```
[node name="PartyNameEntry" type="VBoxContainer" parent="Body/Center/VBox"]
visible = false
layout_mode = 2
theme_override_constants/separation = 16

[node name="Prompt" type="Label" parent="Body/Center/VBox/PartyNameEntry"]
layout_mode = 2
text = "parties.enter_name"
horizontal_alignment = 1

[node name="NameInput" type="LineEdit" parent="Body/Center/VBox/PartyNameEntry"]
layout_mode = 2

[node name="RandomButton" type="Button" parent="Body/Center/VBox/PartyNameEntry"]
layout_mode = 2
text = "🎲 menu.random"

[node name="ConfirmButton" type="Button" parent="Body/Center/VBox/PartyNameEntry"]
layout_mode = 2
text = "parties.confirm_name"

[node name="CancelButton" type="Button" parent="Body/Center/VBox/PartyNameEntry"]
layout_mode = 2
text = "ui.cancel"
```

Add the connections at the bottom of the file, alongside the existing ones:

```
[connection signal="pressed" from="Body/Center/VBox/PartyNameEntry/RandomButton" to="." method="_on_party_name_random_button_pressed"]
[connection signal="pressed" from="Body/Center/VBox/PartyNameEntry/ConfirmButton" to="." method="_on_party_name_confirm_pressed"]
[connection signal="pressed" from="Body/Center/VBox/PartyNameEntry/CancelButton" to="." method="_on_party_name_cancel_pressed"]
```

Check `ui.cancel` already exists in `translations/en.tres` (it's used
elsewhere in this codebase for cancel actions); if it doesn't, add it —
search first with `grep -n '"ui\.' translations/en.tres`.

### Step B6: Add the new translation keys

In `translations/en.tres`, add next to the other `parties.*` keys (search
for `"parties.title"`):

```
"parties.enter_name": "Name this party:",
"parties.confirm_name": "Create Party",
```

### Step B7: Implement the handlers in `parties.gd`

Add node references near the top of `scripts/ui/parties.gd`:

```gdscript
@onready var party_name_entry: VBoxContainer = $Body/Center/VBox/PartyNameEntry
@onready var party_name_input: LineEdit = $Body/Center/VBox/PartyNameEntry/NameInput

const PARTY_NAME_CHOICES := ["Party 1", "Alpha Party"]
```

Replace `_on_create_party_pressed`:

```gdscript
func _on_create_party_pressed() -> void:
	party_name_input.text = ""
	create_party_button.visible = false
	party_name_entry.visible = true
	party_name_input.grab_focus()
```

Add the three new handlers:

```gdscript
func _on_party_name_random_button_pressed() -> void:
	party_name_input.text = PARTY_NAME_CHOICES[randi() % PARTY_NAME_CHOICES.size()]


func _on_party_name_confirm_pressed() -> void:
	var entered_name := party_name_input.text.strip_edges()
	GameManager.create_party(entered_name if not entered_name.is_empty() else "Party 1")
	party_name_entry.visible = false
	create_party_button.visible = true
	refresh()


func _on_party_name_cancel_pressed() -> void:
	party_name_entry.visible = false
	create_party_button.visible = true
```

`refresh()` already sets `create_party_button.disabled` from
`rows.is_empty()`; since `_on_party_name_confirm_pressed` makes it visible
again before calling `refresh()`, the existing disable-once-a-party-exists
behavior is unaffected.

### Step B8: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_parties.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```

Expected: `N/N passed.` for all three files.

### Step B9: Add the new keys to `test_localization.gd`

Add to `tests/unit/test_localization.gd`'s
`test_translation_keys_resolve_to_expected_english_copy` (or the nearest
existing `parties.*`/`menu.*` assertions):

```gdscript
	assert_eq(tr("menu.random"), "Random")
	assert_eq(tr("parties.enter_name"), "Name this party:")
	assert_eq(tr("parties.confirm_name"), "Create Party")
```

Run:

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
```

Expected: `N/N passed.`

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. From the Start Menu, click **New Game**. Click **🎲 Random** — the name
   field fills with either "The Black Company" or "Company of Saints" and
   **Begin** becomes enabled. Note whether the dice glyph renders as an
   emoji or a missing-glyph box in this build's font; either is acceptable,
   but mention which in your report.
2. Enter the settlement, go to Parties, click **Create Party** — the
   button is replaced by a name prompt with **🎲 Random**, **Create
   Party**, and **Cancel**. Click Random a few times and confirm it only
   ever fills "Party 1" or "Alpha Party".
3. Click **Cancel** — the prompt disappears, no party was created, and
   **Create Party** reappears.
4. Click **Create Party** again, type a custom name, confirm — the new
   party appears in the table under that name.

## Commit

```bash
git add scenes/ui/start_menu.tscn scripts/ui/start_menu.gd \
  scenes/ui/parties.tscn scripts/ui/parties.gd \
  scripts/autoload/game_session.gd scripts/autoload/game_manager.gd \
  translations/en.tres \
  tests/unit/test_start_menu.gd tests/unit/test_parties.gd \
  tests/unit/test_game_session.gd tests/unit/test_game_manager.gd \
  tests/unit/test_localization.gd
git commit -m "feat: add random name choice for player and party"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge random-name-choice
git branch -d random-name-choice
```
