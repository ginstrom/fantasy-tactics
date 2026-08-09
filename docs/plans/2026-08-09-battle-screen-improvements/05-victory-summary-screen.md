# Step 5: Victory Summary Screen

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task.

**Branch:** `victory-summary-screen`
**Depends on:** Step 2 merged to `main` first (`Unit.enemy_type_name`).

**Goal:** After a victory (once any level-ups have finished resolving), a
new `BattleResult` scene shows enemies killed (grouped by type × count),
total and per-member XP gained, which members leveled up (if any), and
this battle's loot. `[OK]` returns to the World Map. Defeat is untouched
— it still goes straight to `GameManager.fail_battle()`.

**Files:**
- Create: `scenes/ui/battle_result.tscn`
- Create: `scripts/ui/battle_result.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_battle_result.gd` (new)
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_first_campaign_ui_flow.gd`
- Modify: `tests/unit/test_localization.gd`

**Interfaces:**
- Consumes: `Unit.enemy_type_name` (Step 2). `GameSession.
  complete_current_encounter()`, `GameSession.pending_reward: int`,
  `GameSession.pending_mana_crystals: Dictionary`, `GameSession.
  pending_gear: Array` (all pre-existing). `GameSession.
  get_party(id) -> Dictionary`, `GameSession.get_adventurer(id) ->
  Dictionary` (pre-existing).
- Produces: `GameManager.battle_result_summary: Dictionary` (transient,
  same "set before navigating, read in `_ready()`" pattern as `route_
  context_id`), shape `{"kills_by_type": Dictionary, "total_xp": float,
  "party_member_count": int, "leveled_up_ids": Array[String]}`.
  `GameManager.go_to_battle_result(summary: Dictionary) -> Error`.

## Context you need before starting

- **`GameManager.complete_battle()` is not changed and not removed.** It's
  used today by `scripts/tools/screenshot_tour.gd` to jump straight to a
  post-battle World Map state for a screenshot, skipping any UI in
  between — that's a legitimate, separate use case for a dev tool, not
  the real player-facing victory path. This step adds a **new**, parallel
  path (`_finish_victory()` in `battlefield.gd`, below) that the real
  gameplay flow uses instead; `screenshot_tour.gd` is not touched.
- `battlefield.gd`'s `_apply_battle_outcome(true)` currently does, in
  order: `_award_clear_xp()` (reads `_current_expedition()`, which reads
  `GameSession.selected_encounter` — **must** run before that gets
  cleared) → if a level-up is now showing, defer and return → otherwise
  `GameManager.complete_battle()` (which internally calls `GameSession.
  complete_current_encounter()`, clearing `selected_encounter`, then
  `go_to_world_map()`). `_on_level_up_queue_drained()` calls the same
  `GameManager.complete_battle()` for the deferred path. **Both call
  sites** change to call a new private `_finish_victory()` instead — the
  ordering relative to `_award_clear_xp()` and the level-up gate is
  otherwise identical to today.
- `GameSession.complete_current_encounter()` both marks the encounter
  complete **and** rolls this battle's loot into `GameSession.
  pending_reward`/`pending_mana_crystals`/`pending_gear` (see `_roll_and_
  queue_loot()`) — so it must run *before* the summary screen can show
  loot, and the summary screen can then just read those three fields
  live, the same way `information_panel.gd`'s `_refresh_carried_loot()`
  already does for the World Map.
- `GameSession.selected_party_id` remains set after `complete_current_
  encounter()` (that call only touches `selected_encounter`/`active_
  encounters`/`completed_encounters`/`pending_*` — it does not touch
  `selected_party_id`), so `battlefield.gd` can read `GameSession.
  get_party(GameSession.selected_party_id)` for the member count *after*
  calling it, same as `_award_party_xp()` already does today.
- Kills-by-type: a battle only ever fields one enemy species (Step 2's
  context notes this), so grouping is simple — `_award_kill_xp(unit)`
  already runs exactly once per real kill (guarded by `_kill_xp_awarded_
  units`); add the tally there.
- XP total/each: `_award_party_xp(amount)` already runs for every kill and
  for the clear award; accumulate a running total there, guarded by the
  same `if amount <= 0: return` it already has. "Each" is computed in the
  new scene from `total_xp / party_member_count`, not stored pre-divided
  (matches how `GameSession.award_party_xp()` itself splits: `share :=
  amount / member_ids.size()`).
- Leveled-up ids: `_award_party_xp()` already receives the return value of
  `GameSession.award_party_xp()` (`Array[String]` of members who leveled
  from *that* award) and loops over it to queue each one's modal. A member
  can level up from a kill-triggered award and *again* from the
  clear-triggered award in the same battle — accumulate into a
  deduplicated list, don't just concatenate.
- This step changes what scene is live immediately after a real victory,
  which three tests in `tests/unit/test_first_campaign_ui_flow.gd`
  currently assume (they wait for `get_tree().current_scene.name ==
  "WorldMap"` right after victory). One of those three
  (`test_fresh_campaign_completes_the_full_game_loop_and_banks_the_
  reward`) never actually inspects the live scene tree — it re-
  instantiates its own `WorldMapScene` manually — so it needs **no
  change**. The other two do inspect the live scene tree and **must** be
  updated (Step 5d below shows exactly how).

## Step 5a: `GameManager.go_to_battle_result()`

- [ ] **Write the failing tests**

Add to `tests/unit/test_game_manager.gd`. First find how this file's
existing tests are structured (`grep -n "func test_" tests/unit/
test_game_manager.gd | head -5` to match the file's own conventions for
instantiating `GameManager`/checking `_change_scene` calls — this
codebase's `GameManager` is an autoload singleton, so tests call its
methods directly rather than instancing a new one, same as every other
`GameManager.go_to_*` test in this file). Add:

```gdscript
func test_go_to_battle_result_stores_the_summary_dictionary() -> void:
	var summary := {"kills_by_type": {"Goblin": 1}, "total_xp": 15.0, "party_member_count": 1, "leveled_up_ids": []}

	GameManager.go_to_battle_result(summary)

	assert_eq(GameManager.battle_result_summary, summary)


func test_battle_result_summary_starts_empty() -> void:
	assert_eq(GameManager.battle_result_summary, {})
```

Add `GameManager.battle_result_summary = {}` to this file's `after_each()`
(or `before_each()`, matching whichever this file already uses to reset
`route_context_id` between tests — check the existing pattern with
`grep -n "func before_each\|func after_each" tests/unit/
test_game_manager.gd` and mirror it exactly) so this new field can't leak
between tests either.

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gunit_test_name=battle_result -gexit
```
Expected: FAIL — `GameManager.battle_result_summary`/`go_to_battle_
result` don't exist.

- [ ] **Implement in `game_manager.gd`**

Add the scene constant next to the other `*_SCENE` constants:

```gdscript
const BATTLE_RESULT_SCENE := "res://scenes/ui/battle_result.tscn"
```

Add the field next to `route_context_id`:

```gdscript
# Transient victory-summary payload, mirroring route_context_id's "set
# right before navigating, read once in the destination scene's _ready()"
# pattern. Battlefield builds this from data no other system durably
# tracks (this battle's kills/XP/level-ups), so — unlike route_context_id,
# which always names something GameSession already owns — there is no
# live GameSession id to re-validate on the way in.
var battle_result_summary: Dictionary = {}
```

Add the method next to `go_to_party_details()`:

```gdscript
func go_to_battle_result(summary: Dictionary) -> Error:
	battle_result_summary = summary
	return _change_scene(BATTLE_RESULT_SCENE)
```

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```
Expected: `N/N passed.`

- [ ] **Commit**

```bash
git add scripts/autoload/game_manager.gd tests/unit/test_game_manager.gd
git commit -m "feat: add GameManager.go_to_battle_result and its transient summary field"
```

(`scenes/ui/battle_result.tscn` doesn't exist yet, so `_change_scene`
will `push_error` if this ever actually fires before Step 5c — that's
fine for now since nothing calls `go_to_battle_result()` yet outside this
step's own tests, which don't await the deferred scene change.)

## Step 5b: Battlefield accumulates the summary

- [ ] **Write the failing tests**

Add to `tests/unit/test_battlefield.gd`, after `test_clear_xp_with_no_
level_up_completes_the_battle_immediately` (the last test in the existing
"Task 2" XP block):

```gdscript
func test_a_victorious_battle_reports_kills_grouped_by_type_to_the_summary() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield._apply_battle_outcome(true)

	assert_eq(GameManager.battle_result_summary.kills_by_type, {tr("battle.enemy.goblin"): 1})


func test_a_victorious_battle_reports_total_and_per_member_xp_to_the_summary() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield._apply_battle_outcome(true)

	assert_eq(
		GameManager.battle_result_summary.total_xp, 15.0,
		"5 goblin kill XP + 10 goblin camp clear XP"
	)
	assert_eq(GameManager.battle_result_summary.party_member_count, 1)


func test_a_victorious_battle_with_no_level_up_reports_an_empty_leveled_up_list() -> void:
	var battlefield := _setup_goblin_camp_battle()

	battlefield._apply_battle_outcome(true)

	assert_eq(GameManager.battle_result_summary.leveled_up_ids, [])


func test_leveled_up_ids_accumulate_across_kill_and_clear_xp_and_reach_the_summary() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)
	assert_true(battlefield.level_up.visible, "sanity check: this setup crosses the level-2 threshold")
	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary.leveled_up_ids, ["warrior_001"])


func test_multiple_kills_in_one_battle_are_tallied_by_type_not_overwritten() -> void:
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

	battlefield._apply_battle_outcome(true)

	assert_eq(GameManager.battle_result_summary.kills_by_type, {tr("battle.enemy.goblin"): 2})
```

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gunit_test_name=summary -gexit
```
Expected: FAIL — `GameManager.battle_result_summary` stays `{}` (nothing
populates it yet), and (once Step 5a is merged) `_apply_battle_outcome`
still calls the old `GameManager.complete_battle()` path, not a summary
builder.

- [ ] **Implement in `battlefield.gd`**

Add the three new accumulator fields next to `_clear_xp_awarded`:

```gdscript
# Populated over the course of the battle for the victory summary screen
# (see _finish_victory()). Keyed by Unit.enemy_type_name (Step 2) rather
# than display_name, since the summary groups "2 Goblins", not "Goblin 1"
# and "Goblin 2" separately -- and a battle only ever fields one enemy
# species (see GameSession.STAR_ENEMY_COMPOSITIONS), so this dict never
# holds more than one key in practice today.
var _kills_by_type: Dictionary = {}
# Every _award_party_xp() call (kill or clear) adds its amount here, so the
# summary can show a true battle total regardless of how many separate
# awards produced it.
var _total_xp_awarded: float = 0.0
# Deduplicated: a member can level up once from a kill-triggered award and
# again from the clear-triggered award in the same battle (each call to
# GameSession.award_party_xp() only reports members who crossed a
# threshold *during that call*), so this must not just concatenate.
var _leveled_up_ids: Array[String] = []
```

Modify `_award_kill_xp()` — add the tally line right after the existing
guard-append, before the existing `_award_party_xp()` call:

```gdscript
func _award_kill_xp(unit) -> void:
	if _kill_xp_awarded_units.has(unit):
		return
	_kill_xp_awarded_units.append(unit)
	_kills_by_type[unit.enemy_type_name] = _kills_by_type.get(unit.enemy_type_name, 0) + 1
	_award_party_xp(unit.kill_xp)
```

Modify `_award_party_xp()` — add the total and the leveled-up merge:

```gdscript
func _award_party_xp(amount: float) -> void:
	if amount <= 0:
		return
	_total_xp_awarded += amount
	# Captured before GameSession.award_party_xp() mutates anything, so each
	# leveled member's health-gain can be shown later even though GameSession
	# already applies the increase as part of this same call.
	var health_before: Dictionary = {}
	for member_id in GameSession.get_party(GameSession.selected_party_id).get("member_ids", []):
		health_before[member_id] = GameSession.get_effective_max_health(member_id)

	var leveled_up: Array[String] = GameSession.award_party_xp(GameSession.selected_party_id, amount)
	for adventurer_id in leveled_up:
		_refresh_unit_health(adventurer_id)
		_queue_level_up(adventurer_id, health_before.get(adventurer_id, 0))
		if not _leveled_up_ids.has(adventurer_id):
			_leveled_up_ids.append(adventurer_id)
```

Replace `_apply_battle_outcome()`'s victory branch — currently:

```gdscript
func _apply_battle_outcome(victory: bool) -> void:
	if victory:
		# Clear XP only on victory, and only while selected_encounter (read by
		# _current_expedition()) is still set — GameManager.complete_battle()
		# clears it right after.
		_award_clear_xp()
		# _award_clear_xp() may have just queued a level-up (on top of any
		# still-showing kill-triggered one): the battle-result scene
		# transition must wait for the whole queue to resolve first.
		if _level_up_active:
			_pending_victory_completion = true
			return
		GameManager.complete_battle()
	else:
		GameManager.fail_battle()
```

with:

```gdscript
func _apply_battle_outcome(victory: bool) -> void:
	if victory:
		# Clear XP only on victory, and only while selected_encounter (read by
		# _current_expedition()) is still set — _finish_victory() clears it
		# right after via GameSession.complete_current_encounter().
		_award_clear_xp()
		# _award_clear_xp() may have just queued a level-up (on top of any
		# still-showing kill-triggered one): the summary-screen transition
		# must wait for the whole queue to resolve first.
		if _level_up_active:
			_pending_victory_completion = true
			return
		_finish_victory()
	else:
		GameManager.fail_battle()
```

Replace `_on_level_up_queue_drained()` — currently:

```gdscript
func _on_level_up_queue_drained() -> void:
	if not _pending_victory_completion:
		return
	_pending_victory_completion = false
	GameManager.complete_battle()
```

with:

```gdscript
func _on_level_up_queue_drained() -> void:
	if not _pending_victory_completion:
		return
	_pending_victory_completion = false
	_finish_victory()
```

Add the new method near those two:

```gdscript
## Rolls this battle's loot into GameSession's pending_* fields (see
## GameSession.complete_current_encounter() -> _roll_and_queue_loot()) and
## routes to the victory summary screen with everything this battle
## accumulated. Unlike GameManager.complete_battle() (still used by
## scripts/tools/screenshot_tour.gd to skip straight to the World Map),
## this is the real gameplay path -- it shows the summary before the
## player ever reaches the World Map.
func _finish_victory() -> void:
	GameSession.complete_current_encounter()
	var party := GameSession.get_party(GameSession.selected_party_id)
	var summary := {
		"kills_by_type": _kills_by_type,
		"total_xp": _total_xp_awarded,
		"party_member_count": maxi(party.get("member_ids", []).size(), 1),
		"leveled_up_ids": _leveled_up_ids,
	}
	GameManager.go_to_battle_result(summary)
```

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```
Expected: `N/N passed.` — including every pre-existing test in this file.
In particular `test_apply_battle_outcome_true_completes_the_encounter`,
`test_winning_the_goblin_camp_awards_its_ten_point_clear_xp`, `test_a_
level_up_from_clear_xp_must_resolve_before_the_battle_completes`, and
`test_a_clear_xp_level_up_that_requires_a_perk_choice_still_gates_
completion` still pass unchanged: they assert on `GameSession.is_
encounter_complete(...)` / `GameSession.get_adventurer(...).progression.
xp` / `battlefield.level_up.visible`, none of which this step's changes
alter — `_finish_victory()` still calls `GameSession.complete_current_
encounter()` at exactly the point `GameManager.complete_battle()` used to
call it internally.

- [ ] **Commit**

```bash
git add scripts/battle/battlefield.gd tests/unit/test_battlefield.gd
git commit -m "feat: accumulate kills/XP/level-ups for the victory summary"
```

## Step 5c: The `BattleResult` scene

- [ ] **Write the failing tests**

Add to `translations/en.tres`, nothing yet — the keys are added in the
implementation sub-step below; write the localization test first so it's
red, matching this plan's other steps:

Add to `tests/unit/test_localization.gd`, after the `battle.unit_info.*`
assertions from Step 3:

```gdscript
	assert_eq(tr("battle_result.title"), "Victory!")
	assert_eq(tr("battle_result.kills") % "Goblin x1", "Enemies defeated: Goblin x1")
	assert_eq(tr("battle_result.no_kills"), "No enemies defeated.")
	assert_eq(tr("battle_result.xp") % [15, 15], "XP gained: 15 total (15 each)")
	assert_eq(tr("battle_result.leveled_up") % "Warrior, Warrior 2", "Leveled up: Warrior, Warrior 2")
	assert_eq(tr("battle_result.loot") % [1, 2, 0], "Loot: 1 gold, 2 mana crystals, 0 gear")
	assert_eq(tr("battle_result.ok"), "OK")
```

Create `tests/unit/test_battle_result.gd`:

```gdscript
extends GutTest

const BattleResultScene := preload("res://scenes/ui/battle_result.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.battle_result_summary = {}


func after_each() -> void:
	GameManager.battle_result_summary = {}


func _open_battle_result(summary: Dictionary) -> Control:
	GameManager.battle_result_summary = summary
	var screen: Control = BattleResultScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_shows_kills_grouped_by_type() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {"Goblin": 2, "Orc": 1}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_true(
		screen.get_node("Center/VBox/KillsLabel").text.contains("Goblin x2")
		and screen.get_node("Center/VBox/KillsLabel").text.contains("Orc x1")
	)


func test_shows_no_kills_message_when_nothing_was_killed() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/KillsLabel").text, tr("battle_result.no_kills"))


func test_shows_total_and_per_member_xp() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 20.0, "party_member_count": 2, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/XpLabel").text, tr("battle_result.xp") % [20, 10])


func test_hides_the_leveled_up_row_when_nobody_leveled_up() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_false(screen.get_node("Center/VBox/LevelUpLabel").visible)


func test_shows_the_leveled_up_members_names_when_present() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	assert_true(screen.get_node("Center/VBox/LevelUpLabel").visible)
	assert_eq(screen.get_node("Center/VBox/LevelUpLabel").text, tr("battle_result.leveled_up") % "Warrior")


func test_shows_this_battles_loot_read_live_from_game_session() -> void:
	GameSession.pending_reward = 5
	GameSession.pending_mana_crystals = {1: 2}
	GameSession.pending_gear = ["dagger_iron"]
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_eq(screen.get_node("Center/VBox/LootLabel").text, tr("battle_result.loot") % [5, 2, 1])


func test_ok_button_returns_to_the_world_map() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_result.gd")

	assert_string_contains(source, "GameManager.go_to_world_map()")


func test_ok_button_clears_the_summary() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	screen.get_node("Center/VBox/OkButton").emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary, {})
```

- [ ] **Run to verify they fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gunit_test_name=battle_result -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_result.gd -gexit
```
Expected: FAIL — the `battle_result.*` keys and `scenes/ui/
battle_result.tscn` don't exist yet.

- [ ] **Add the translation keys**

In `translations/en.tres`, add a new `battle_result.*` block (alongside
the other screen-specific blocks, e.g. near `party_details.*`):

```
"battle_result.title": "Victory!",
"battle_result.kills": "Enemies defeated: %s",
"battle_result.no_kills": "No enemies defeated.",
"battle_result.xp": "XP gained: %d total (%d each)",
"battle_result.leveled_up": "Leveled up: %s",
"battle_result.loot": "Loot: %d gold, %d mana crystals, %d gear",
"battle_result.ok": "OK",
```

- [ ] **Create `scripts/ui/battle_result.gd`**

```gdscript
extends Control

## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is
## deliberately NOT part of that summary dict: GameSession.pending_reward/
## pending_mana_crystals/pending_gear are already live and current by the
## time this scene loads (GameSession.complete_current_encounter() rolled
## them before Battlefield navigated here), so this screen just reads them
## directly, exactly as information_panel.gd's _refresh_carried_loot()
## already does for the World Map.

@onready var kills_label: Label = $Center/VBox/KillsLabel
@onready var xp_label: Label = $Center/VBox/XpLabel
@onready var level_up_label: Label = $Center/VBox/LevelUpLabel
@onready var loot_label: Label = $Center/VBox/LootLabel
@onready var ok_button: Button = $Center/VBox/OkButton


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var summary: Dictionary = GameManager.battle_result_summary
	kills_label.text = _format_kills(summary.get("kills_by_type", {}))

	var total_xp: float = summary.get("total_xp", 0.0)
	var member_count: int = maxi(summary.get("party_member_count", 1), 1)
	var each_xp: float = total_xp / member_count
	xp_label.text = tr("battle_result.xp") % [int(round(total_xp)), int(round(each_xp))]

	var leveled_up_ids: Array = summary.get("leveled_up_ids", [])
	level_up_label.visible = not leveled_up_ids.is_empty()
	if level_up_label.visible:
		var names: Array = []
		for adventurer_id in leveled_up_ids:
			names.append(GameSession.get_adventurer(adventurer_id).get("name", ""))
		level_up_label.text = tr("battle_result.leveled_up") % ", ".join(names)

	loot_label.text = _format_loot()


func _format_kills(kills_by_type: Dictionary) -> String:
	if kills_by_type.is_empty():
		return tr("battle_result.no_kills")
	var parts: Array = []
	for type_name in kills_by_type:
		parts.append("%s x%d" % [type_name, kills_by_type[type_name]])
	return tr("battle_result.kills") % ", ".join(parts)


func _format_loot() -> String:
	var mana_crystal_count := 0
	for tier in GameSession.pending_mana_crystals:
		mana_crystal_count += GameSession.pending_mana_crystals[tier]
	return tr("battle_result.loot") % [GameSession.pending_reward, mana_crystal_count, GameSession.pending_gear.size()]


func _on_ok_pressed() -> void:
	GameManager.battle_result_summary = {}
	GameManager.go_to_world_map()
```

- [ ] **Create `scenes/ui/battle_result.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/battle_result.gd" id="1_battle_result"]

[node name="BattleResult" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_battle_result")

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
text = "battle_result.title"
horizontal_alignment = 1

[node name="KillsLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="XpLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="LevelUpLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
visible = false
horizontal_alignment = 1

[node name="LootLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="OkButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "battle_result.ok"

[connection signal="pressed" from="Center/VBox/OkButton" to="." method="_on_ok_pressed"]
```

(`OkButton.pressed` is wired via this `.tscn` `[connection]` block, not
also in the script's `_ready()` — matching how every other screen in this
codebase wires its buttons, e.g. `party_details.gd`'s `AddMemberButton`/
`BackButton`.)

- [ ] **Run to verify they pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_result.gd -gexit
```
Expected: `N/N passed.` for both files.

- [ ] **Commit**

```bash
git add scenes/ui/battle_result.tscn scripts/ui/battle_result.gd translations/en.tres tests/unit/test_battle_result.gd tests/unit/test_localization.gd
git commit -m "feat: add the victory summary screen"
```

## Step 5d: Update the three affected integration tests

- [ ] **Run the full-loop integration file first, to see current state**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow.gd -gexit
```
Expected at this point: 1 pass
(`test_fresh_campaign_ui_reaches_a_deployed_first_party`), 1 pass
(`test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`
— per the Context section above, it never inspects the live scene tree,
so it already passes unmodified), and 2 **FAIL**
(`test_the_real_post_victory_scene_change_produces_a_selectable_world_
map` and `test_a_real_click_after_the_real_post_victory_scene_change_
selects_the_party` — both wait for `current_scene.name == "WorldMap"`
right after victory, but the real scene now lands on `"BattleResult"`
first).

- [ ] **Fix `test_the_real_post_victory_scene_change_produces_a_selectable_world_map`**

In `tests/unit/test_first_campaign_ui_flow.gd`, find this test and
replace its comment-plus-loop right after
`assert_eq(GameSession.selected_encounter, "", ...)`:

```gdscript
	# GameManager.complete_battle() just called go_to_world_map(), which
	# calls the REAL get_tree().change_scene_to_file() -- that's deferred to
	# the end of the frame, so give it a few frames to actually take effect.
	var scene_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "WorldMap") and scene_settle_frames < 10:
		await get_tree().process_frame
		scene_settle_frames += 1
```

with:

```gdscript
	# Battlefield._finish_victory() now routes through GameManager.go_to_
	# battle_result() (the new victory summary screen) before ever reaching
	# the World Map -- both scene changes go through the REAL get_tree().
	# change_scene_to_file(), each deferred to the end of its frame, so
	# settle for the summary screen first, dismiss it with its real OK
	# button exactly as a player would, then settle again for the World Map
	# underneath it.
	var result_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "BattleResult") and result_settle_frames < 10:
		await get_tree().process_frame
		result_settle_frames += 1
	assert_eq(get_tree().current_scene.name, "BattleResult", "Victory must land on the summary screen first")

	get_tree().current_scene.get_node("Center/VBox/OkButton").emit_signal("pressed")

	var scene_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "WorldMap") and scene_settle_frames < 10:
		await get_tree().process_frame
		scene_settle_frames += 1
```

(Everything below this block — `var live_world_map: Node = get_tree().
current_scene` onward — is unchanged.)

- [ ] **Fix `test_a_real_click_after_the_real_post_victory_scene_change_selects_the_party`**

In the same file, find this test's identical
`assert_eq(GameSession.selected_encounter, "", ...)` followed by the same
`scene_settle_frames` loop shape, and apply the exact same replacement
shown above (settle for `"BattleResult"`, click its `OkButton`, then
settle for `"WorldMap"`). The rest of that test (the real
`push_input()`-based click on the live World Map) is unchanged.

- [ ] **Run to verify all four tests in the file pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow.gd -gexit
```
Expected: `N/N passed.`

- [ ] **Commit**

```bash
git add tests/unit/test_first_campaign_ui_flow.gd
git commit -m "test: update post-victory integration tests for the new summary screen"
```

## Manual verification

1. `make play`
2. Debug menu (**FN+F9**) → **Goblin Camp** (a staffed single-Warrior
   party, already deployed at the Goblin Camp tile — quickest path to a
   winnable one-enemy fight).
3. Click the party tile twice (select, then enter) to start the battle.
4. Defeat the goblin and end turns as needed until the battle resolves.
5. Confirm you land on a new **Victory!** screen (not straight back to the
   World Map) showing: `Enemies defeated: Goblin x1`, an XP line, loot
   (gold/mana crystals/gear — the Goblin Camp always rolls at least some
   gold), and — only if a level-up happened — a `Leveled up: ...` line.
6. Click **OK**: confirm you land on the World Map with the party
   present, matching today's existing post-victory behavior otherwise
   unchanged (party is still on the goblin camp's tile, still selectable).
7. Repeat via **Ruined Fortress** (defeat all fielded Kobolds) to confirm
   multi-kill counts group correctly (`Kobold x3`, etc., not one line
   per kill) and that a mid-battle level-up's modal still shows and
   resolves *before* the summary screen appears (per the existing
   level-up-gates-completion behavior, now gating the summary instead of
   a direct World Map jump).

## Full run and merge

```bash
make check
```
Expected: `N/N passed.` / `---- All tests passed! ----`, exit 0.

```bash
git checkout main
git merge victory-summary-screen
git branch -d victory-summary-screen
```

Then, per this plan's index, run `make check` once more from `main` to
confirm the full five-step sequence is clean end to end.
