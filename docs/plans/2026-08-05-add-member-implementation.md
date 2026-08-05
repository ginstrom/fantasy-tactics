# Add Member Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Party Details "Add Member" action functional, with the debug tooling needed to reach and test it.

**Architecture:** `GameSession` gains an explicit-id `assign_adventurer_to_party(party_id, adventurer_id)` (with `assign_adventurer_to_selected_party` becoming a thin wrapper over it) and a `recruit_adventurer()` roster primitive. `GameManager` gains matching routing/passthrough methods (`go_to_add_member`, `assign_adventurer_to_party`, `recruit_adventurer`) and a debug scenario mapping. A new Add Member screen follows the existing Deploy Party list-and-immediate-action pattern. Two debug-only additions (`party_empty` scenario, `Recruit Adventurer` action) make the feature reachable given today's single-adventurer, single-party roster.

**Tech Stack:** Godot 4, GDScript, GUT test framework, Make.

## Global Constraints

- Session queries stay deep-copy-safe: any dictionary returned from `GameSession` (e.g. `get_party`, `get_adventurer`) must not let a caller mutate session state through it. Existing `.duplicate(true)` queries are unchanged by this plan.
- Follow the explicit-id convention (`get_party(id)`, `deploy_party(id)`) for all new `GameSession`/`GameManager` methods in this plan, not the older selected-party-singleton convention.
- List-row rebuilds always detach with `remove_child()` then `queue_free()` — never `free()` directly — because a row's own `pressed` handler can be what triggers the rebuild.
- Debug-only code (`scripts/debug/debug_scenarios.gd`, `scripts/debug/debug_menu.gd`, `GameManager.recruit_adventurer()`) must only call public `GameSession`/`GameManager` APIs, never write `GameSession.parties`/`GameSession.adventurers` directly, and debug actions gate on `OS.is_debug_build()` exactly like `GameManager.apply_super_power()` already does.
- Roster and Recruitment screens remain non-functional; do not wire them up as part of this plan.
- `make check` and `git diff --check` must pass before any task is considered done.

---

### Task 1: GameSession — explicit-id assignment and recruitment

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

**Interfaces:**
- Produces: `GameSession.assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool`; `GameSession.recruit_adventurer() -> void` (always succeeds; appends one adventurer to `adventurers`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_game_session.gd` (it already has a `_party(...)` helper near the top — reuse it):

```gdscript
func test_assign_adventurer_to_party_targets_the_named_party_not_the_selected_one() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()
	session.parties.append(
		_party("second_party", [] as Array[String], GameSessionScript.STARTING_SETTLEMENT_ID, false)
	)

	assert_true(session.assign_adventurer_to_party("second_party", "warrior_001"))

	assert_eq(session.get_party("second_party").member_ids, ["warrior_001"])
	assert_eq(
		session.get_selected_party().member_ids,
		[] as Array[String],
		"Only the named party should gain the member"
	)


func test_assign_adventurer_to_party_rejects_unknown_party_unknown_adventurer_and_double_assignment() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	assert_false(session.assign_adventurer_to_party("no_such_party", "warrior_001"))
	assert_false(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "no_such_adventurer"))
	assert_true(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "warrior_001"))
	assert_false(session.assign_adventurer_to_party(GameSessionScript.FIRST_PARTY_ID, "warrior_001"))


func test_assign_adventurer_to_selected_party_still_works_as_a_thin_wrapper() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.create_party()

	assert_true(session.assign_adventurer_to_selected_party("warrior_001"))

	assert_eq(session.get_selected_party().member_ids, ["warrior_001"])


func test_recruit_adventurer_appends_a_new_available_adventurer_with_a_fresh_id() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 2)
	var recruit: Dictionary = session.adventurers[1]
	assert_eq(recruit.id, "warrior_002")
	assert_eq(recruit.name, "Warrior 2")
	assert_eq(recruit["class"], "warrior")
	assert_eq(recruit.availability_status, "available")
	assert_true(session.get_available_adventurers().has(recruit))


func test_recruit_adventurer_never_collides_with_an_earlier_recruit() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.recruit_adventurer()

	session.recruit_adventurer()

	assert_eq(session.adventurers.size(), 3)
	assert_eq(session.adventurers[2].id, "warrior_003")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: the four `assign_adventurer_to_party`/wrapper tests fail with "Invalid call. Nonexistent function 'assign_adventurer_to_party'"; the two `recruit_adventurer` tests fail the same way for `recruit_adventurer`.

- [ ] **Step 3: Implement the minimal change**

In `scripts/autoload/game_session.gd`, replace the existing `assign_adventurer_to_selected_party` (lines 155-162) with:

```gdscript
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1 or not _has_adventurer(adventurer_id) or _is_adventurer_assigned(adventurer_id):
		return false

	var member_ids: Array = parties[party_index].member_ids
	member_ids.append(adventurer_id)
	return true


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	return assign_adventurer_to_party(selected_party_id, adventurer_id)


func recruit_adventurer() -> void:
	var recruit_number := adventurers.size() + 1
	var adventurer: Dictionary = DEFAULT_WARRIOR.duplicate(true)
	adventurer.id = "warrior_%03d" % recruit_number
	adventurer.name = "Warrior %d" % recruit_number
	adventurers.append(adventurer)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS, including all pre-existing `test_game_session.gd` tests (the refactor must not change `assign_adventurer_to_selected_party`'s observable behavior).

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
git commit -m "feat: add explicit-id party assignment and adventurer recruitment"
```

---

### Task 2: DebugScenarios — party_empty scenario

**Files:**
- Modify: `scripts/debug/debug_scenarios.gd`
- Test: `tests/unit/test_debug_scenarios.gd`

**Interfaces:**
- Consumes: `GameSession.create_party() -> bool` (existing).
- Produces: `DebugScenarios.SCENARIO_IDS` includes `"party_empty"` (positioned right after `"party_ready"`); `DebugScenarios.apply("party_empty") -> bool` creates an encamped party with no members.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_debug_scenarios.gd`, replace `test_scenario_ids_are_in_display_order` with:

```gdscript
func test_scenario_ids_are_in_display_order() -> void:
	assert_eq(DebugScenarios.scenario_ids(), [
		"new_campaign",
		"encampment",
		"party_manager",
		"party_ready",
		"party_empty",
		"world_map",
		"goblin_camp",
		"orc_outpost",
	])
```

Add a new test:

```gdscript
func test_party_empty_creates_an_encamped_party_with_no_members() -> void:
	assert_true(DebugScenarios.apply("party_empty"))
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: `test_scenario_ids_are_in_display_order` fails (missing `"party_empty"` in the list); `test_party_empty_creates_an_encamped_party_with_no_members` fails (`apply("party_empty")` returns `false` since it hits the unhandled `match` fallthrough).

- [ ] **Step 3: Implement the minimal change**

In `scripts/debug/debug_scenarios.gd`, update `SCENARIO_IDS` (insert `"party_empty"` after `"party_ready"`):

```gdscript
const SCENARIO_IDS := [
	"new_campaign",
	"encampment",
	"party_manager",
	"party_ready",
	"party_empty",
	"world_map",
	"goblin_camp",
	"orc_outpost",
]
```

Add a new `match` arm in `apply()`, right after the `"party_ready"` arm:

```gdscript
		"party_empty":
			return GameSession.create_party()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/debug/debug_scenarios.gd tests/unit/test_debug_scenarios.gd
git commit -m "feat: add party_empty debug scenario"
```

---

### Task 3: GameManager — add member route, assignment passthrough, recruit action

**Files:**
- Modify: `scripts/autoload/game_manager.gd`
- Test: `tests/unit/test_game_manager.gd`

**Interfaces:**
- Consumes: `GameSession.get_party(id)`, `GameSession.assign_adventurer_to_party(party_id, adventurer_id)`, `GameSession.recruit_adventurer()` (Task 1); `DebugScenarios` scenario id `"party_empty"` (Task 2, used only via the string literal in `debug_scenario_target`).
- Produces: `GameManager.ADD_MEMBER_SCENE`; `GameManager.go_to_add_member(party_id: String) -> Error`; `GameManager.assign_adventurer_to_party(party_id: String, adventurer_id: String) -> Error`; `GameManager.recruit_adventurer() -> Error`; `GameManager.debug_scenario_target("party_empty")` returns `DebugTarget.ENCAMPMENT`.

- [ ] **Step 1: Write the failing tests**

Add to `tests/unit/test_game_manager.gd`:

```gdscript
func test_add_member_route_points_to_the_add_member_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/add_member.tscn")
	assert_string_contains(source, "func go_to_add_member(")


func test_going_to_add_member_with_an_unknown_party_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_add_member("no_such_party")

	assert_ne(err, OK, "An unknown party id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_going_to_add_member_with_a_known_party_id_sets_the_route_context() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.go_to_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_assign_adventurer_to_party_reports_invalid_data_for_an_unknown_adventurer() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.assign_adventurer_to_party(GameSession.FIRST_PARTY_ID, "no_such_adventurer")

	assert_ne(err, OK)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])


func test_assign_adventurer_to_party_assigns_the_named_adventurer_to_the_named_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.assign_adventurer_to_party(GameSession.FIRST_PARTY_ID, GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_recruit_adventurer_appends_a_new_adventurer_to_the_roster() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.recruit_adventurer()

	assert_eq(err, OK)
	assert_eq(GameSession.adventurers.size(), 2)
	assert_eq(GameSession.adventurers[1].id, "warrior_002")


func test_debug_scenario_target_maps_party_empty_to_the_encampment() -> void:
	assert_eq(GameManager.debug_scenario_target("party_empty"), GameManager.DebugTarget.ENCAMPMENT)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `go_to_add_member`, `assign_adventurer_to_party`, and `recruit_adventurer` don't exist yet on `GameManager`; `debug_scenario_target("party_empty")` returns `DebugTarget.NONE`.

- [ ] **Step 3: Implement the minimal change**

In `scripts/autoload/game_manager.gd`, add a new scene constant right after `DEPLOY_PARTY_SCENE` (line 15):

```gdscript
const ADD_MEMBER_SCENE := "res://scenes/ui/add_member.tscn"
```

Add `go_to_add_member` right after `go_to_deploy_party()` (after line 127):

```gdscript
func go_to_add_member(party_id: String) -> Error:
	if GameSession.get_party(party_id).is_empty():
		route_context_id = ""
		return ERR_INVALID_DATA
	route_context_id = party_id
	return _change_scene(ADD_MEMBER_SCENE)
```

Add `assign_adventurer_to_party` right after `deploy_party()` (after line 138):

```gdscript
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> Error:
	if not GameSession.assign_adventurer_to_party(party_id, adventurer_id):
		return ERR_INVALID_DATA
	return OK
```

Add `recruit_adventurer` right after `apply_super_power()` (after line 198):

```gdscript
func recruit_adventurer() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	GameSession.recruit_adventurer()
	return OK
```

Update the `debug_scenario_target` match statement (line 160) to include `"party_empty"`:

```gdscript
		"encampment", "party_ready", "party_empty":
			return DebugTarget.ENCAMPMENT
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_manager.gd tests/unit/test_game_manager.gd
git commit -m "feat: add GameManager routes for add-member and recruitment"
```

---

### Task 4: Debug menu — party_empty and Recruit Adventurer buttons

**Files:**
- Modify: `scripts/debug/debug_menu.gd`
- Modify: `scenes/debug/debug_menu.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_debug_menu.gd`

**Interfaces:**
- Consumes: `GameManager.run_debug_scenario("party_empty")` via the existing `_run()` helper; `GameManager.recruit_adventurer() -> Error` (Task 3).
- Produces: `debug_menu.gd` methods `_on_party_empty_pressed()`, `_on_recruit_pressed()`; scene nodes `Panel/Rows/PartyEmptyButton`, `Panel/Rows/RecruitButton`.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_debug_menu.gd`, replace `test_debug_menu_starts_hidden_with_eight_stable_scenario_buttons` with:

```gdscript
func test_debug_menu_starts_hidden_with_ten_stable_scenario_buttons() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.visible)
	assert_eq(menu.get_node("Panel/Rows/NewCampaignButton").text, "debug.new_campaign")
	assert_eq(menu.get_node("Panel/Rows/EncampmentButton").text, "debug.encampment")
	assert_eq(menu.get_node("Panel/Rows/PartyManagerButton").text, "debug.party_manager")
	assert_eq(menu.get_node("Panel/Rows/PartyReadyButton").text, "debug.party_ready")
	assert_eq(menu.get_node("Panel/Rows/PartyEmptyButton").text, "debug.party_empty")
	assert_eq(menu.get_node("Panel/Rows/WorldMapButton").text, "debug.world_map")
	assert_eq(menu.get_node("Panel/Rows/GoblinCampButton").text, "debug.goblin_camp")
	assert_eq(menu.get_node("Panel/Rows/OrcOutpostButton").text, "debug.orc_outpost")
	assert_eq(menu.get_node("Panel/Rows/SuperPowerButton").text, "debug.super_power")
	assert_eq(menu.get_node("Panel/Rows/RecruitButton").text, "debug.recruit")
```

Add two new tests:

```gdscript
func test_party_empty_button_runs_the_party_empty_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_party_empty_pressed()

	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])
	assert_false(GameSession.has_deployed_party())
	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_recruit_button_adds_an_adventurer_and_closes_the_menu() -> void:
	GameSession.reset()
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_recruit_pressed()

	assert_eq(GameSession.adventurers.size(), 2)
	assert_false(menu.visible, "A successful recruit should close the menu, like Super Power")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `PartyEmptyButton`/`RecruitButton` nodes don't exist yet, and `_on_party_empty_pressed`/`_on_recruit_pressed` don't exist on the script.

- [ ] **Step 3: Implement the minimal change**

In `scripts/debug/debug_menu.gd`, add right after `_on_party_ready_pressed()`:

```gdscript
func _on_party_empty_pressed() -> void:
	_run("party_empty")
```

Add right after `_on_super_power_pressed()`:

```gdscript
func _on_recruit_pressed() -> void:
	if GameManager.recruit_adventurer() == OK:
		visible = false
```

In `scenes/debug/debug_menu.tscn`, insert a new button node right after `PartyReadyButton` (before `WorldMapButton`):

```
[node name="PartyEmptyButton" type="Button" parent="Panel/Rows"]
layout_mode = 2
text = "debug.party_empty"
```

Insert a new button node right after `SuperPowerButton` (the last node):

```
[node name="RecruitButton" type="Button" parent="Panel/Rows"]
layout_mode = 2
text = "debug.recruit"
```

Add the two matching connection lines at the bottom, keeping the `PartyEmptyButton` connection grouped with the other scenario buttons and `RecruitButton` last:

```
[connection signal="pressed" from="Panel/Rows/PartyEmptyButton" to="." method="_on_party_empty_pressed"]
```

(insert right after the `PartyReadyButton` connection line)

```
[connection signal="pressed" from="Panel/Rows/RecruitButton" to="." method="_on_recruit_pressed"]
```

(insert right after the `SuperPowerButton` connection line)

In `translations/en.tres`, the `"debug.party_ready"` line already ends with a comma; insert a new line right after it:

```
"debug.party_ready": "Party Ready to Depart",
"debug.party_empty": "Party Awaiting a Member",
```

Add a trailing comma to the `"debug.super_power"` line (it's currently the last entry) and insert a new final line after it:

```
"debug.super_power": "Super Power",
"debug.recruit": "Recruit Adventurer"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/debug/debug_menu.gd scenes/debug/debug_menu.tscn translations/en.tres tests/unit/test_debug_menu.gd
git commit -m "feat: add party_empty and recruit debug menu buttons"
```

---

### Task 5: Add Member screen

**Files:**
- Create: `scripts/ui/add_member.gd`
- Create: `scenes/ui/add_member.tscn`
- Test: `tests/unit/test_add_member.gd`
- Modify: `translations/en.tres`

**Interfaces:**
- Consumes: `GameSession.get_available_adventurers() -> Array[Dictionary]` (existing); `GameManager.route_context_id`, `GameManager.assign_adventurer_to_party(party_id, adventurer_id) -> Error`, `GameManager.go_to_party_details(party_id) -> Error`, `GameManager.open_game_menu()` (Task 3 and existing).
- Produces: scene `res://scenes/ui/add_member.tscn`, script exposing `party_id: String` and `refresh() -> void`; nodes `Center/VBox/Title`, `Center/VBox/AdventurerList`, `Center/VBox/EmptyLabel`, `Center/VBox/BackButton`, `InformationPanel`.

- [ ] **Step 1: Write the failing tests**

Create `tests/unit/test_add_member.gd`:

```gdscript
extends GutTest

const AddMemberScene := preload("res://scenes/ui/add_member.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func _open_add_member(party_id: String) -> Control:
	GameManager.route_context_id = party_id
	var screen: Control = AddMemberScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_add_member_shows_the_title_and_the_back_action() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Center/VBox/Title").text, "add_member.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_reads_the_party_id_from_route_context() -> void:
	GameSession.create_party()

	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.party_id, GameSession.FIRST_PARTY_ID)


func test_no_available_adventurer_shows_the_empty_state_without_errors() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "add_member.empty")
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 0)


func test_lists_exactly_the_available_adventurers() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 1)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)
	assert_eq(row.text, tr("add_member.member_row") % ["Warrior", "warrior", 1])


func test_selecting_a_row_assigns_that_exact_adventurer_to_this_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)

	row.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_selecting_a_row_returns_to_that_partys_details() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)

	row.emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_a_stale_row_fails_safely_and_refreshes_the_list_in_place() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var row: Button = screen.get_node("Center/VBox/AdventurerList").get_child(0)
	# The adventurer gets assigned elsewhere out from under the still-displayed row.
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)

	row.emit_signal("pressed")

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/AdventurerList").get_child_count(), 0)


func test_back_button_returns_to_party_details_without_mutating_the_party() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	GameSession.create_party()
	var screen := _open_add_member(GameSession.FIRST_PARTY_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `res://scenes/ui/add_member.tscn` does not exist yet.

- [ ] **Step 3: Implement the minimal change**

Create `scripts/ui/add_member.gd`:

```gdscript
extends Control

## Lists GameSession.get_available_adventurers() for the party named by
## GameManager.route_context_id (see party_details.gd, which sets it before
## routing here) and treats selecting a row as the assignment itself: it
## calls GameManager.assign_adventurer_to_party() immediately, then returns
## to Party Details on success. A row that has gone stale (its adventurer
## got assigned elsewhere while this screen was open) fails safely and this
## screen just refreshes the list in place instead of navigating anywhere.

@onready var adventurer_list: VBoxContainer = $Center/VBox/AdventurerList
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var party_id: String = ""


func _ready() -> void:
	information_panel.refresh()
	party_id = GameManager.route_context_id
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	_rebuild_adventurer_rows()


## Rebuilds the row list from scratch. remove_child() already takes each row
## off get_children() synchronously, so a refresh called more than once per
## frame, as tests do, never leaves stale rows sitting alongside new ones;
## queue_free() only defers the actual deallocation.
func _rebuild_adventurer_rows() -> void:
	for child in adventurer_list.get_children():
		adventurer_list.remove_child(child)
		child.queue_free()

	var available: Array[Dictionary] = GameSession.get_available_adventurers()
	empty_label.visible = available.is_empty()

	for adventurer in available:
		var row := Button.new()
		row.name = "AdventurerRow_%s" % adventurer.id
		row.text = tr("add_member.member_row") % [
			adventurer["name"], adventurer["class"], adventurer["level"]
		]
		row.pressed.connect(_on_adventurer_row_pressed.bind(adventurer.id))
		adventurer_list.add_child(row)


func _on_adventurer_row_pressed(adventurer_id: String) -> void:
	if GameManager.assign_adventurer_to_party(party_id, adventurer_id) == OK:
		GameManager.go_to_party_details(party_id)
		return
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_party_details(party_id)
```

Create `scenes/ui/add_member.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/add_member.gd" id="1_add_member"]
[ext_resource type="PackedScene" path="res://scenes/ui/information_panel.tscn" id="2_information_panel"]

[node name="AddMember" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_add_member")

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Center/VBox"]
layout_mode = 2
text = "add_member.title"
horizontal_alignment = 1

[node name="AdventurerList" type="VBoxContainer" parent="Center/VBox"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="EmptyLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
visible = false
text = "add_member.empty"
horizontal_alignment = 1

[node name="BackButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "ui.back"

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

[connection signal="pressed" from="Center/VBox/BackButton" to="." method="_on_back_pressed"]
```

In `translations/en.tres`, the `"deploy_party.empty"` line already ends with a comma; insert three new lines right after it:

```
"deploy_party.empty": "No party is ready to deploy.",
"add_member.title": "Add Member",
"add_member.empty": "No adventurers are available to add.",
"add_member.member_row": "%s — %s — Lv %d",
```

Note: opening this scene in the Godot editor (see Task 6's final headless editor scan) generates the `.uid` sidecar file for `add_member.gd` automatically; no manual step is needed for it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/add_member.gd scenes/ui/add_member.tscn tests/unit/test_add_member.gd translations/en.tres
git commit -m "feat: add the Add Member screen"
```

---

### Task 6: Party Details — enable Add Member

**Files:**
- Modify: `scripts/ui/party_details.gd`
- Modify: `scenes/ui/party_details.tscn`
- Test: `tests/unit/test_party_details.gd`

**Interfaces:**
- Consumes: `GameManager.go_to_add_member(party_id) -> Error` (Task 3); `GameSession.get_available_adventurers()` (existing); the Add Member scene existing at `res://scenes/ui/add_member.tscn` (Task 5).
- Produces: `party_details.gd` method `_on_add_member_pressed()`.

- [ ] **Step 1: Write the failing tests**

In `tests/unit/test_party_details.gd`, replace `test_add_member_is_present_but_disabled_and_labelled_with_its_own_name` with:

```gdscript
func test_add_member_is_enabled_for_an_encamped_party_with_an_available_adventurer() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Center/VBox/AddMemberButton")
	assert_true(add_button.visible, "Add Member must be offered for an encamped party")
	assert_false(add_button.disabled, "An available adventurer exists, so Add Member must be usable")
	assert_eq(add_button.text, "party_details.add_member")


func test_add_member_is_disabled_when_no_adventurer_is_available() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	var add_button: Button = screen.get_node("Center/VBox/AddMemberButton")
	assert_true(add_button.visible)
	assert_true(add_button.disabled, "The only adventurer is already a member of this party")


func test_pressing_add_member_routes_to_the_add_member_screen_with_this_partys_id() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	screen.get_node("Center/VBox/AddMemberButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — the enabled-state test fails because `AddMemberButton.disabled` is hardcoded `true` in the scene, and `_on_add_member_pressed` does not exist.

- [ ] **Step 3: Implement the minimal change**

In `scripts/ui/party_details.gd`, replace the header comment block (lines 3-8) with:

```gdscript
## Shows the roster of a single party (read from GameManager.route_context_id)
## and mirrors the selected member into the shared InformationPanel, the same
## selection pattern Parties uses for parties (see parties.gd). Add Member is
## hidden entirely for a deployed party, since you can't add a member to a
## party that's out in the field, and disabled for an encamped party with no
## available adventurer left to add.
```

Replace `refresh()` (lines 32-44) with:

```gdscript
func refresh() -> void:
	var party := GameSession.get_party(party_id)
	if party.is_empty():
		party_name_label.text = ""
		_rebuild_member_rows([])
	else:
		party_name_label.text = party.name
		_rebuild_member_rows(party.member_ids)
	# A deployed party is out in the field; Add Member doesn't even make
	# sense to offer, so it disappears entirely rather than merely staying
	# disabled. An encamped party with nobody left to recruit keeps the
	# button visible but disabled, so its presence isn't a mystery.
	add_member_button.visible = not party.get("deployed", false)
	add_member_button.disabled = GameSession.get_available_adventurers().is_empty()
	_refresh_selection()
```

Add a new handler right before `_on_back_pressed()`:

```gdscript
func _on_add_member_pressed() -> void:
	GameManager.go_to_add_member(party_id)
```

In `scenes/ui/party_details.tscn`, remove the `disabled = true` line from the `AddMemberButton` node (it becomes):

```
[node name="AddMemberButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "party_details.add_member"
```

Add a new connection line, right before the existing `BackButton` connection:

```
[connection signal="pressed" from="Center/VBox/AddMemberButton" to="." method="_on_add_member_pressed"]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test`
Expected: PASS.

- [ ] **Step 5: Run the full check suite**

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

Expected: `make check` passes; the headless editor pass completes without import errors (and generates `scripts/ui/add_member.gd.uid`); `git diff --check` reports no whitespace errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/party_details.gd scenes/ui/party_details.tscn tests/unit/test_party_details.gd
git commit -m "feat: enable Add Member in Party Details"
```

---

## Final Verification

After all six tasks are complete and committed:

- `make check` passes on the full branch.
- `godot --headless --path . --editor --quit` completes without import errors, and `scripts/ui/add_member.gd.uid` exists afterward.
- `git diff --check` is clean against the base branch.
- Manual signoff path: launch the game, press F9, run `Party Awaiting a Member`, press F9 again, run `Recruit Adventurer`, navigate to that party's details, press `Add Member`, and confirm the recruited adventurer appears and selecting it returns to Party Details with the roster updated.
- Manual signoff also covers: Add Member disabled (not hidden) when the encamped party already holds every available adventurer, and Add Member hidden entirely once that party is deployed.
