extends GutTest

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const TEST_SAVE_PATH := "user://test_game_manager_campaign.json"


## A minimal double exposing the same save_campaign()/load_campaign()/
## has_valid_save() surface as SaveRepository (see GameManager.
## save_repository's own doc comment), used by the boundary-guard tests
## below so they can prove exactly whether the repository was ever asked to
## write -- without touching real disk I/O the way a real SaveRepository
## pointed at TEST_SAVE_PATH would.
class FakeSaveRepository extends RefCounted:
	var save_called: bool = false
	var save_result: Dictionary = {"ok": true, "error": ""}

	func save_campaign(_session: Object) -> Dictionary:
		save_called = true
		return save_result

	func load_campaign(_session: Object) -> Dictionary:
		return {"ok": false, "snapshot": {}, "error": "not used by these tests", "status": SaveRepositoryScript.LoadStatus.ABSENT}

	func has_valid_save() -> bool:
		return false


func after_each() -> void:
	# A failed assertion in an open_game_menu test can skip its manual
	# close_game_menu() cleanup, leaving the tree paused for later tests.
	get_tree().paused = false
	GameManager.add_member_return_party_id = ""
	GameManager.battle_result_summary = {}
	GameManager.create_party_on_open = false
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()

	# Save-related tests inject a repository pointed at TEST_SAVE_PATH instead
	# of the real campaign-save.json; put GameManager back on a fresh default
	# repository and remove any file this run may have left behind so no test
	# leaks save state into another.
	GameManager.save_repository = SaveRepositoryScript.new()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

	# The Step 3 debug-launch tests below load a synthetic manifest at
	# TEST_MANIFEST_PATH, replacing DebugScenarios' shared static cache --
	# always reload the real one afterward so no test here can leak a
	# synthetic scenario list into another test file (see test_debug_
	# scenarios.gd's after_each for the same rationale).
	if FileAccess.file_exists(TEST_MANIFEST_PATH):
		DirAccess.remove_absolute(TEST_MANIFEST_PATH)
	DebugScenariosScript.load_scenarios()


func test_battle_route_uses_battlefield_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(
		source,
		"res://scenes/battle/battlefield.tscn",
		"The tactical route must use the battle-domain scene"
	)


func test_party_manager_and_encampment_routes_are_available() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "open_party_manager()")
	assert_string_contains(source, "go_to_encampment()")
	assert_string_contains(source, "res://scenes/ui/encampment.tscn")


func test_start_menu_route_uses_start_menu_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/start_menu.tscn")
	assert_string_contains(source, "go_to_start_menu()")


## Step 1 of docs/plans/2026-08-18-core-loop-and-engagement streamlines
## onboarding: New Game must land directly on party formation with the
## first objective already active, not the old generic settlement intro.
func test_new_game_routes_to_party_formation() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "func go_to_game(")
	assert_string_contains(source, "return go_to_parties(true)")


## Functional companion to the source-inspection test above: New Game must
## flag Parties to create party_001 immediately, the same affordance the
## Encampment's own "form your first party" dialog uses (see
## test_encampment.gd's test_first_party_dialog_uses_the_exact_prompt_and_
## create_routes_to_parties), so the party-formation screen genuinely
## prompts the player to assign initial members to it rather than just
## landing on an empty party list.
func test_go_to_game_flags_parties_to_create_the_first_party_immediately() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	GameSession.reset()

	var err: Error = manager.go_to_game("Aria")

	assert_eq(err, OK)
	assert_eq(GameSession.player_name, "Aria")
	assert_true(manager.create_party_on_open, "New Game must flag Parties to create party_001 immediately")


## --- Side-effect-free debug launch (Step 3) --------------------------------
##
## run_debug_scenario() must reach its manifest-declared launch.scene without
## going through go_to_encampment()/go_to_world_map()/enter_battle() -- those
## carry real reward-banking/encounter-entry side effects a debug launch must
## not trigger (see docs/plans/2026-08-16-debug-menu-json-config/index.md's
## acceptance criteria). Every test below writes its own scenario(s) to
## TEST_MANIFEST_PATH (the same test-injectable-path convention test_debug_
## scenarios.gd establishes) rather than editing config/debug_scenarios.json,
## and after_each() always reloads the real manifest afterward.

const DebugScenariosScript := preload("res://scripts/debug/debug_scenarios.gd")
const TEST_MANIFEST_PATH := "user://test_game_manager_debug_manifest.json"


func _write_debug_manifest(scenarios: Array) -> void:
	var file := FileAccess.open(TEST_MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"manifest_version": 1, "scenarios": scenarios}))
	file.close()


## Builds a manifest scenario entry from a REAL shipped scenario's own
## fixture (so the embedded campaign_snapshot always passes CampaignSnapshot
## validation) with campaign_snapshot field overrides layered on top -- e.g.
## a non-default selected_encounter a real "encampment"-launch fixture never
## has.
func _scenario_with_snapshot_overrides(id: String, base_id: String, launch_scene: String, snapshot_overrides: Dictionary) -> Dictionary:
	var base := DebugScenariosScript.get_scenario(base_id)
	var snapshot: Dictionary = (base.campaign_snapshot as Dictionary).duplicate(true)
	for key in snapshot_overrides:
		snapshot[key] = snapshot_overrides[key]
	return {
		"id": id,
		"name_key": "debug.test_scenario",
		"category": "Test",
		"description": "Synthetic scenario for a test-injected manifest.",
		"launch": {"scene": launch_scene},
		"campaign_snapshot": snapshot,
	}


func _run(scenario_id: String) -> Error:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	return manager.run_debug_scenario(scenario_id)


## OS.is_debug_build() can't be stubbed in a real Godot process (test runs
## are themselves debug builds, so this guard can't be exercised at
## runtime) -- verified by source inspection instead, matching this file's
## established convention for scene-routing guards it can't drive directly
## (see e.g. test_battle_route_uses_battlefield_scene()).
func test_run_debug_scenario_reports_unavailable_outside_debug_builds() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "func run_debug_scenario(")
	assert_string_contains(source, "if not OS.is_debug_build():\n\t\treturn ERR_UNAVAILABLE")


func test_run_debug_scenario_launches_the_starting_settlement() -> void:
	GameSession.reset()
	assert_eq(_run("new_campaign"), OK)


func test_run_debug_scenario_launches_the_encampment() -> void:
	GameSession.reset()
	assert_eq(_run("encampment"), OK)


func test_run_debug_scenario_launches_the_party_manager() -> void:
	GameSession.reset()
	assert_eq(_run("party_manager"), OK)


func test_run_debug_scenario_launches_the_world_map() -> void:
	GameSession.reset()
	assert_eq(_run("world_map"), OK)


func test_run_debug_scenario_launches_stores() -> void:
	GameSession.reset()
	assert_eq(_run("stocked_stores"), OK)


func test_run_debug_scenario_launches_the_battlefield_with_its_fixtures_selected_encounter() -> void:
	GameSession.reset()

	assert_eq(_run("goblin_camp"), OK)

	assert_eq(
		GameSession.selected_encounter, GameSession.GOBLIN_CAMP_ID,
		"The fixture's own selected_encounter should reach GameSession untouched -- this dispatcher never calls GameSession.enter_encounter() itself"
	)


## Every permitted launch.scene reaches its screen without banking a party's
## carried gold, resolving battle loot, or otherwise touching any field the
## fixture itself declared -- in particular Encampment (which normally
## deposits a party's carry) and World Map (which normally resolves the
## active battle context). Reuses one manager for the whole test, rather
## than this file's usual
## _run() helper (which builds a fresh manager per call): a manager's own
## _ready() reloads the REAL default manifest (see GameManager._ready()),
## which would silently replace the synthetic scenarios this test loads
## below if a fresh manager were created after that load.
func test_run_debug_scenario_leaves_every_fixtures_snapshot_unchanged_after_routing() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var cases := [
		["settlement", "new_campaign"],
		["encampment", "encampment"],
		["party_manager", "party_manager"],
		["world_map", "world_map"],
		["stores", "stocked_stores"],
		["battlefield", "goblin_camp"],
	]
	var scenarios: Array = []
	for case in cases:
		var launch_scene: String = case[0]
		var base_id: String = case[1]
		scenarios.append(_scenario_with_snapshot_overrides(
			"test_%s" % launch_scene, base_id, launch_scene,
			{
				# GOBLIN_CAMP_ID is always a valid EXPEDITIONS template id
				# (CampaignSnapshot's selected_encounter check falls back to
				# EXPEDITIONS when the id names no active instance), so it's
				# a safe "some encounter is selected" value for every launch
				# scene, not just battlefield.
				"selected_encounter": GameSession.GOBLIN_CAMP_ID,
			}
		))
	_write_debug_manifest(scenarios)
	assert_true(DebugScenariosScript.load_scenarios(TEST_MANIFEST_PATH).ok)

	for case in cases:
		var launch_scene: String = case[0]
		var scenario_id := "test_%s" % launch_scene
		var expected_snapshot: Dictionary = DebugScenariosScript.get_scenario(scenario_id).campaign_snapshot

		assert_eq(manager.run_debug_scenario(scenario_id), OK, "launching %s should succeed" % launch_scene)
		assert_eq(
			GameSession.export_campaign_snapshot(), expected_snapshot,
			"launching %s must not mutate any fixture field, including a party's own carry" % launch_scene
		)


func test_run_debug_scenario_with_an_unknown_id_changes_neither_scene_nor_session() -> void:
	GameSession.reset()
	assert_true(_run("party_ready") == OK)
	var before := GameSession.export_campaign_snapshot()

	assert_eq(_run("unknown"), ERR_INVALID_DATA)

	assert_eq(GameSession.export_campaign_snapshot(), before)


## GameManager keeps its own explicit, narrow launch-scene allow-list (see
## _debug_launch_scene_path()) rather than trusting DebugScenarios.
## ALLOWED_LAUNCH_SCENES to stay in lockstep forever -- e.g. a future
## manifest version might validate "assign_equipment" as a syntactically
## known scene before GameManager is taught to route a stable item id there
## (see Step 3's own plan notes). Tested directly rather than through a real
## scenario: DebugScenarios.load_scenarios() already rejects any manifest
## entry whose launch.scene isn't in its own allow-list, so there is no way
## to get an "unrecognized" scene into a loaded scenario end-to-end today.
func test_debug_launch_scene_path_is_empty_for_an_unrecognized_scene() -> void:
	assert_eq(GameManager._debug_launch_scene_path("assign_equipment"), "")
	assert_eq(GameManager._debug_launch_scene_path(""), "")


## See test_run_debug_scenario_leaves_every_fixtures_snapshot_unchanged_
## after_routing()'s own comment on why this reuses one manager instead of
## this file's usual _run() helper.
func test_run_debug_scenario_for_a_battlefield_fixture_without_a_selected_encounter_changes_neither_scene_nor_session() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_true(manager.run_debug_scenario("party_ready") == OK)
	var before := GameSession.export_campaign_snapshot()

	# "encampment"'s own fixture has selected_encounter == "" -- reused here
	# under a "battlefield" launch to exercise the missing-encounter guard.
	_write_debug_manifest([
		_scenario_with_snapshot_overrides("test_no_encounter", "encampment", "battlefield", {}),
	])
	assert_true(DebugScenariosScript.load_scenarios(TEST_MANIFEST_PATH).ok)

	assert_eq(manager.run_debug_scenario("test_no_encounter"), ERR_INVALID_DATA)

	assert_eq(GameSession.export_campaign_snapshot(), before)


func test_depart_selected_party_deploys_before_changing_scene() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.depart_selected_party()

	assert_true(GameSession.has_deployed_party())


func test_create_party_wraps_the_one_party_session_contract_without_routing() -> void:
	GameSession.reset()
	GameManager.route_context_id = "existing_context"

	assert_eq(GameManager.create_party(), OK)
	assert_eq(GameManager.create_party(), ERR_INVALID_DATA)
	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameManager.route_context_id, "existing_context")
	GameManager.route_context_id = ""


func test_create_party_passes_the_given_name_through_to_game_session() -> void:
	GameSession.reset()

	GameManager.create_party("Alpha Party")

	assert_eq(GameSession.parties[0].name, "Alpha Party")


func test_return_party_to_encampment_returns_party_and_deposits_reward() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.parties[0].carry.gold = 15
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.return_party_to_encampment()

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.gold, 15, "Returning to the encampment must bank any queued reward")


func test_go_to_world_map_merges_the_battle_store_into_the_party_store() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.create_battle_context(party_id, GameSession.GOBLIN_CAMP_ID)
	GameSession._battle_context.reward = {"gold": 5, "gear": {"dagger_iron": 1}, "mana_crystals": {1: 1}, "item_instance_ids": [] as Array[String]}
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_world_map()

	var carry: Dictionary = GameSession.get_party_carry(party_id)
	assert_eq(carry.gold, 5)
	assert_eq(carry.mana_crystals, {1: 1})
	assert_eq(carry.gear, {"dagger_iron": 1})
	assert_eq(GameSession.get_active_battle_context().status, "victory")


func test_go_to_encampment_deposits_pending_gold_once() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	# Pinned explicitly (not just left at the real-random default) so this
	# test's expected gold total does not depend on some earlier test in this
	# file leaving GameSession.enemy_count_roll pinned to a different value --
	# GameSession.reset() deliberately never touches injectable rolls.
	GameSession.reset_injectable_rolls()
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.go_to_world_map()

	manager.go_to_encampment()

	# 1 Goblin (Goblin Camp's only composition option is a fixed count of 1)
	# at loot_gold_roll's pinned minimum of 1, plus the flat completion bonus
	# loot_gold_roll(18, 22) * difficulty(1) = 18.
	assert_eq(GameSession.gold, 19, "Entering the encampment must bank the queued reward")
	assert_eq(GameSession.get_party_carry(party_id).gold, 0)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 19, "A second visit must not pay the reward again")
	assert_eq(GameSession.get_party_carry(party_id).gold, 0)



func test_go_to_encampment_does_not_bank_the_reward_while_the_party_is_still_deployed() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var queued_reward: int = GameSession.get_active_battle_context().reward.gold
	assert_true(queued_reward > 0, "Test setup must actually queue a reward")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_encampment()

	assert_eq(GameSession.gold, 0, "Gold must not be banked while the party is still deployed away from home")
	assert_eq(
		GameSession.get_active_battle_context().reward.gold, queued_reward,
		"The queued reward must remain untouched until the party actually returns"
	)
	assert_true(
		GameSession.has_deployed_party(),
		"CampNav's Encampment shortcut must not silently return the party"
	)


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


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: fail_battle()'s
## only real call site (is_battle_lost()) always means a full party wipe, so
## it must apply the same forfeiture GameSession.resolve_battle_defeat()
## defines -- returning the party to the Encampment settlement position and
## forfeiting the wiped party's own carry -- while completed objectives and
## building levels (and, per Stage 6 Step 2's PartyCarry contract, the
## shared Encampment bank and any other party) survive untouched.
func test_fail_battle_wipe_returns_party_position_to_the_encampment_settlement() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.set_deployed_party_position(Vector2i(6, 6))
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	assert_eq(GameSession.get_deployed_party_position(), Vector2i(3, 3))
	assert_eq(GameSession.get_deployed_party_position(), GameSession.STARTING_SETTLEMENT_WORLD_POSITION)


func test_fail_battle_wipe_forfeits_pending_loot_and_gold_but_preserves_progress_and_buildings() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context(party_id, "goblin_camp")
	GameSession.enter_encounter("goblin_camp")
	GameSession.gold = 80
	GameSession.parties[0].carry.gold = 25
	GameSession.parties[0].carry.gear = {"dagger_iron": 1}
	GameSession.guild_hall_level = 2
	GameSession.completed_objectives = ["obj_tier1_1_goblin_outpost"]
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	# Stage 6 Step 2 (decision-ledger.md's PartyCarry contract) narrows the
	# pre-Stage-6 "a wipe loses all gold" rule: only the wiped party's own
	# carry is forfeited; the shared Encampment bank is untouched (see
	# GameSession.forfeit_party_carry()'s own doc comment).
	assert_eq(GameSession.gold, 80, "The shared Encampment bank must never be touched by a wipe")
	assert_eq(GameSession.get_party_carry(party_id).gold, 0)
	assert_eq(GameSession.get_party_carry(party_id).gear, {})
	assert_eq(GameSession.guild_hall_level, 2, "Building levels survive a wipe")
	assert_eq(
		GameSession.completed_objectives, ["obj_tier1_1_goblin_outpost"],
		"Completed campaign objectives survive a wipe"
	)


## Stage 5 D5 (Step 6 task 6): a party wipe must recover only the wiped
## party -- a second, independently deployed party must keep its own
## position/route/deployment completely untouched. This is the "wipe
## recovery" scenario the step file's task 6 requires focused coverage for.
func test_fail_battle_wipe_recovers_only_the_wiped_party_leaving_a_second_deployed_party_untouched() -> void:
	GameSession.reset()
	GameSession.guild_hall_level = GameSession.GUILD_HALL_MAX_LEVEL
	GameSession.create_party("Alpha")
	var alpha_id: String = GameSession.selected_party_id
	GameSession.assign_adventurer_to_party(alpha_id, "warrior_001")
	GameSession.deploy_party(alpha_id)
	GameSession.enter_encounter("goblin_camp")
	GameSession.create_party("Bravo")
	var bravo_id: String = GameSession.selected_party_id
	GameSession.adventurers.append(GameSession.get_default_warrior("warrior_bravo", "Bravo Warrior"))
	GameSession.assign_adventurer_to_party(bravo_id, "warrior_bravo")
	GameSession.deploy_party(bravo_id)
	GameSession.set_deployed_party_position(Vector2i(1, 1), bravo_id)
	GameSession.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i], bravo_id)
	# Alpha's Enter claimed the battle -- see GameManager.enter_battle().
	GameSession.create_battle_context(alpha_id, "goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	assert_false(GameSession.has_deployed_party(alpha_id), "Alpha's wipe must send it home")
	assert_true(GameSession.has_deployed_party(bravo_id), "Bravo must stay deployed and untouched")
	assert_eq(GameSession.get_deployed_party_position(bravo_id), Vector2i(1, 1))
	assert_eq(GameSession.get_deployed_party_route(bravo_id), [Vector2i(1, 0)] as Array[Vector2i])
	assert_eq(GameSession.get_active_battle_context().status, "defeat", "The battle claim must be released")
	assert_true(GameSession.can_party_enter_battle(bravo_id), "Bravo must be free to claim its own battle next")


func test_retreat_from_battle_routes_survivors_to_the_world_map_leaving_the_encounter_active() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_position: Vector2i = GameSession.get_expedition("goblin_camp").position
	GameSession.set_deployed_party_position(encounter_position)
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.retreat_from_battle()

	assert_eq(GameSession.selected_encounter, "")
	assert_false(GameSession.is_encounter_complete("goblin_camp"), "Retreat leaves the encounter unconquered")
	assert_true(GameSession.has_deployed_party(), "Survivors keep the party deployed, not sent home")
	assert_eq(GameSession.get_deployed_party_position(), encounter_position)


func test_retreat_from_battle_wipe_routes_home_and_forfeits_loot() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context(party_id, "goblin_camp")
	GameSession.enter_encounter("goblin_camp")
	GameSession.resolve_battle_deaths({"warrior_001": 0})
	GameSession.gold = 60
	GameSession.parties[0].carry.gold = 30
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.retreat_from_battle()

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_deployed_party_position(), GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
	assert_eq(GameSession.gold, 60, "The shared Encampment bank must never be touched by a wipe")
	assert_eq(GameSession.get_party_carry(party_id).gold, 0, "The wiped party's own carried gold is forfeited")


## Step 1 of docs/plans/2026-08-21-stage-1-campaign-spine: withdraw_from_
## encounter() is the thin manager wrapper over GameSession.withdraw_from_
## encounter() -- see that function's own doc comment for the HP/route rules
## this wrapper deliberately does not reimplement.
func test_withdraw_from_encounter_routes_the_deployed_party_home_without_entering_battle() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var result: Error = manager.withdraw_from_encounter(encounter_id)

	assert_eq(result, OK)
	assert_eq(GameSession.selected_encounter, "", "Withdraw must never select the encounter for battle")
	assert_false(GameSession.get_deployed_party_route().is_empty(), "A homeward route must be recorded")
	assert_true(GameSession.has_deployed_party(), "The party must not be teleported home")
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain enterable")


func test_withdraw_from_encounter_is_a_no_op_for_an_out_of_position_encounter() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var result: Error = manager.withdraw_from_encounter("obj_tier1_1_goblin_outpost")

	assert_eq(result, ERR_INVALID_DATA)
	assert_true(GameSession.get_deployed_party_route().is_empty(), "Session routing must be untouched")
	assert_eq(GameSession.get_current_health("warrior_001"), 10, "Session health must be untouched")


## --- Step 6: multi-party battle-party tie-break (decision-ledger.md's D5) --


func test_enter_battle_claims_the_battle_for_the_currently_selected_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var party_id := GameSession.selected_party_id
	GameSession.set_deployed_party_position(GameSession.get_expedition("goblin_camp").position)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var result: Error = manager.enter_battle("goblin_camp")

	assert_eq(result, OK)
	assert_eq(GameSession.get_active_battle_context().owner_party_id, party_id)
	assert_eq(GameSession.selected_encounter, "goblin_camp")


## Part A regression (independent review finding against Stage 5 D5's own
## "Arrival-visibility clarification", decision-ledger.md): mirrors the exact
## position guard GameSession.withdraw_from_encounter() already applies -- a
## party that is not actually standing at an encounter's own position must
## never be able to claim/enter battle there, however it names the encounter
## id (a stale arrival panel, a hand-typed debug call, etc). No claim, no
## encounter selection, no scene change.
func test_enter_battle_is_rejected_for_a_party_not_at_the_encounters_position() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	# Setup: depart_selected_party() places the party at the settlement tile
	# (3, 3) -- goblin_camp's own expedition position, (4, 4), is different.
	assert_ne(
		GameSession.get_deployed_party_position(), GameSession.get_expedition("goblin_camp").position,
		"Setup: the deployed party must not already be standing at goblin_camp"
	)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var result: Error = manager.enter_battle("goblin_camp")

	assert_eq(result, ERR_INVALID_DATA)
	assert_eq(GameSession.selected_encounter, "", "A rejected claim must never select the encounter")
	assert_eq(GameSession.get_active_battle_context(), {}, "A rejected claim must never be granted")


## Whichever party's Enter is clicked first claims the active battle; a
## second party's Enter attempt must be rejected outright -- it must not
## select the encounter for battle or change scene at all.
func test_enter_battle_is_rejected_while_another_party_already_owns_the_active_battle() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context("some_other_party", "goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var result: Error = manager.enter_battle("goblin_camp")

	assert_eq(result, ERR_INVALID_DATA)
	assert_eq(GameSession.selected_encounter, "", "A rejected claim must never select the encounter")
	assert_eq(GameSession.get_active_battle_context().owner_party_id, "some_other_party", "The existing claim must be untouched")


func test_complete_battle_releases_the_battle_claim() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context(GameSession.selected_party_id, "goblin_camp")
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.complete_battle()

	assert_ne(GameSession.get_active_battle_context().status, "active")


func test_fail_battle_releases_the_battle_claim() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context(GameSession.selected_party_id, "goblin_camp")
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.fail_battle()

	assert_ne(GameSession.get_active_battle_context().status, "active")


func test_retreat_from_battle_releases_the_battle_claim() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.create_battle_context(GameSession.selected_party_id, "goblin_camp")
	GameSession.enter_encounter("goblin_camp")
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.retreat_from_battle()

	assert_ne(GameSession.get_active_battle_context().status, "active")


func test_apply_super_power_reports_unavailable_without_an_active_battlefield() -> void:
	assert_eq(GameManager.apply_super_power(), ERR_UNAVAILABLE)


func test_apply_super_power_maxes_out_player_units_on_the_active_battlefield() -> void:
	GameSession.reset()
	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(GameManager.apply_super_power(), OK)

	assert_eq(warrior.max_action_points, BattleControllerScript.SUPER_POWER_ACTION_POINTS)
	assert_eq(warrior.damage_min, 100)
	assert_eq(warrior.damage_max, 100)
	assert_eq(warrior.hit_chance, 1.0)


func test_change_scene_reports_error_for_missing_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager._change_scene("res://scenes/missing_scene.tscn")

	assert_ne(err, OK, "Missing scene should return an Error")
	assert_push_error("missing_scene.tscn")
	# Missing resources also emit engine load errors; those are expected here.
	for tracked in get_errors():
		tracked.handled = true


func test_units_route_points_to_the_units_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/units.tscn")
	assert_string_contains(source, "func go_to_units()")


func test_parties_route_points_to_the_parties_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/parties.tscn")
	assert_string_contains(source, "func go_to_parties(")



func test_party_details_route_points_to_the_party_details_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/party_details.tscn")
	assert_string_contains(source, "func go_to_party_details(")


func test_unit_details_route_points_to_the_unit_details_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/unit_details.tscn")
	assert_string_contains(source, "func go_to_unit_details(")


func test_deploy_party_route_points_to_the_deploy_party_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/deploy_party.tscn")
	assert_string_contains(source, "func go_to_deploy_party()")


func test_route_context_id_starts_empty() -> void:
	GameSession.reset()

	assert_eq(GameManager.route_context_id, "")


func test_going_to_party_details_with_an_unknown_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_party_details("no_such_party")

	assert_ne(err, OK, "An unknown party id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_going_to_unit_details_with_an_unknown_id_is_invalid_and_leaves_the_route_context_empty() -> void:
	GameSession.reset()

	var err: Error = GameManager.go_to_unit_details("no_such_adventurer")

	assert_ne(err, OK, "An unknown adventurer id must not be treated as a valid route")
	assert_eq(GameManager.route_context_id, "")


func test_deploy_party_route_reuses_the_world_map_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "func deploy_party(")
	assert_string_contains(source, "GameSession.deploy_party(")


func test_deploy_party_reports_invalid_data_for_an_ineligible_party_and_does_not_deploy_it() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.deploy_party("no_such_party")

	assert_ne(err, OK, "An ineligible party id must not be treated as a valid deployment")
	assert_false(GameSession.has_deployed_party())


func test_deploy_party_deploys_the_selected_party_before_routing_to_the_world_map() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.deploy_party(GameSession.FIRST_PARTY_ID)

	assert_eq(err, OK)
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)


func test_open_game_menu_shows_the_overlay_and_pauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.open_game_menu()

	assert_true(manager.is_game_menu_open())
	assert_true(get_tree().paused)

	manager.close_game_menu()


func test_close_game_menu_hides_the_overlay_and_unpauses_the_tree() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.open_game_menu()

	manager.close_game_menu()

	assert_false(manager.is_game_menu_open())
	assert_false(get_tree().paused)


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
	assert_eq(GameSession.adventurers.size(), 5)
	assert_false(GameSession.adventurers[4].id.is_empty())


func test_roster_route_points_to_the_roster_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/roster.tscn")
	assert_string_contains(source, "func go_to_roster()")


func test_recruitment_route_points_to_the_recruitment_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/recruitment.tscn")
	assert_string_contains(source, "func go_to_recruitment()")


func test_buildings_route_points_to_the_buildings_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/buildings.tscn")
	assert_string_contains(source, "func go_to_buildings()")


func test_guild_hall_route_points_to_the_guild_hall_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/guild_hall.tscn")
	assert_string_contains(source, "func go_to_guild_hall()")


func test_temple_route_points_to_the_temple_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/temple.tscn")
	assert_string_contains(source, "func go_to_temple()")


func test_blacksmith_route_points_to_the_blacksmith_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/blacksmith.tscn")
	assert_string_contains(source, "func go_to_blacksmith()")


func test_alchemy_workshop_route_points_to_its_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/alchemy_workshop.tscn")
	assert_string_contains(source, "func go_to_alchemy_workshop()")


func test_runic_workshop_route_points_to_its_scene() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/runic_workshop.tscn")
	assert_string_contains(source, "func go_to_runic_workshop()")


func test_entering_buildings_clears_a_stale_route_context_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_buildings()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_entering_guild_hall_clears_a_stale_route_context_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_guild_hall()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_entering_temple_clears_a_stale_route_context_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_temple()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_go_to_roster_clears_stale_route_context_before_changing_scene() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_roster()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")


func test_go_to_unit_details_from_roster_sets_route_context_and_marks_the_roster_origin() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.go_to_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, GameSession.WARRIOR_ID)
	assert_eq(manager.unit_details_origin, manager.UNIT_DETAILS_ORIGIN_ROSTER)


func test_go_to_unit_details_from_add_member_preserves_a_valid_return_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(
		manager.go_to_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID), OK
	)
	assert_eq(manager.route_context_id, GameSession.WARRIOR_ID)
	assert_eq(manager.unit_details_origin, manager.UNIT_DETAILS_ORIGIN_ADD_MEMBER)
	assert_eq(manager.add_member_return_party_id, GameSession.FIRST_PARTY_ID)


func test_go_to_unit_details_from_add_member_rejects_missing_live_records_and_clears_context() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"
	manager.unit_details_origin = "stale"
	manager.add_member_return_party_id = "stale"

	assert_eq(manager.go_to_unit_details_from_add_member(GameSession.WARRIOR_ID, "missing_party"), ERR_INVALID_DATA)
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")
	assert_eq(manager.add_member_return_party_id, "")


func test_going_to_unit_details_from_roster_with_an_unknown_id_is_invalid_and_clears_both_fields() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_unit_details_from_roster("no_such_adventurer")

	assert_ne(err, OK, "An unknown adventurer id must not be treated as a valid route")
	assert_eq(manager.route_context_id, "")
	assert_eq(manager.unit_details_origin, "")


func test_go_to_unit_details_clears_a_stale_roster_origin_flag() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.unit_details_origin = manager.UNIT_DETAILS_ORIGIN_ROSTER

	var err: Error = manager.go_to_unit_details(GameSession.WARRIOR_ID)

	assert_eq(err, OK)
	assert_eq(
		manager.unit_details_origin,
		"",
		"The pre-Roster entry path must never leave a stale roster origin behind"
	)


func test_go_to_recruitment_clears_stale_route_context_before_changing_scene() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale_id"

	var err: Error = manager.go_to_recruitment()

	assert_eq(err, OK)
	assert_eq(manager.route_context_id, "")


func test_purchase_recruit_reports_invalid_data_for_an_unknown_candidate() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit("no_such_candidate")

	assert_ne(err, OK, "An unknown candidate id must not be treated as a valid purchase")
	assert_eq(GameSession.adventurers.size(), 4)


func test_purchase_recruit_reports_invalid_data_when_funds_are_insufficient() -> void:
	GameSession.reset()
	GameSession.gold = 0
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit(cand_id)

	assert_ne(err, OK)
	assert_eq(GameSession.adventurers.size(), 4)
	assert_eq(GameSession.get_recruitment_candidates().size(), 4)


func test_purchase_recruit_deducts_gold_removes_the_candidate_and_adds_the_adventurer() -> void:
	GameSession.reset()
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	var err: Error = manager.purchase_recruit(cand_id)

	assert_eq(err, OK)
	assert_eq(GameSession.gold, 0)
	assert_eq(GameSession.adventurers.size(), 5)
	assert_eq(GameSession.adventurers[4].id, cand_id)
	assert_eq(GameSession.get_recruitment_candidates().size(), 3)


func test_targeted_purchase_keeps_an_eligible_party_as_the_recruitment_target() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	autofree(manager)
	manager.recruitment_target_party_id = GameSession.FIRST_PARTY_ID

	assert_eq(manager.purchase_recruit_for_target_party(cand_id), OK)
	assert_eq(manager.recruitment_target_party_id, GameSession.FIRST_PARTY_ID)


func test_targeted_purchase_clears_a_party_target_that_becomes_full() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[0].id)
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[1].id)
	GameSession.gold = 10
	var cand_id := str(GameSession.recruitment_candidates[0].id)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	autofree(manager)
	manager.recruitment_target_party_id = GameSession.FIRST_PARTY_ID

	assert_eq(manager.purchase_recruit_for_target_party(cand_id), OK)
	assert_eq(manager.recruitment_target_party_id, "")


func test_go_to_trade_changes_scene_and_clears_detail_context() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"

	assert_eq(manager.go_to_trade(), OK)
	assert_eq(manager.route_context_id, "")


func test_go_to_stores_changes_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_stores(), OK)


func test_go_to_trading_post_changes_scene() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_trading_post(), OK)


func test_go_to_assign_equipment_sets_route_context_and_changes_scene_for_a_known_item() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_assign_equipment("dagger_iron"), OK)
	assert_eq(manager.route_context_id, "dagger_iron")


func test_go_to_assign_equipment_rejects_an_unknown_item_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.route_context_id = "stale"

	assert_eq(manager.go_to_assign_equipment("no_such_item"), ERR_INVALID_DATA)
	assert_eq(manager.route_context_id, "")


func test_go_to_assign_equipment_with_a_party_id_scopes_and_records_the_origin() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(
		manager.go_to_assign_equipment(
			"dagger_iron", GameSession.FIRST_PARTY_ID, manager.AssignEquipmentOrigin.PARTY_DETAILS
		),
		OK
	)
	assert_eq(manager.route_context_id, "dagger_iron")
	assert_eq(manager.assign_equipment_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.PARTY_DETAILS)


func test_go_to_assign_equipment_rejects_an_unknown_party_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.assign_equipment_party_id = "stale"

	assert_eq(manager.go_to_assign_equipment("dagger_iron", "no_such_party"), ERR_INVALID_DATA)
	assert_eq(manager.assign_equipment_party_id, "")


func test_go_to_assign_equipment_defaults_to_the_stores_origin_and_no_party_scope() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_assign_equipment("dagger_iron")

	assert_eq(manager.assign_equipment_party_id, "")
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.STORES)


func test_go_to_battle_result_stores_the_summary_dictionary() -> void:
	var summary := {"kills_by_type": {"Goblin": 1}, "total_xp": 15.0, "party_member_count": 1, "leveled_up_ids": []}

	GameManager.go_to_battle_result(summary)

	assert_eq(GameManager.battle_result_summary, summary)


func test_battle_result_summary_starts_empty() -> void:
	assert_eq(GameManager.battle_result_summary, {})


## --- Step 5: Campaign Victory routing ---------------------------------------
## (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md)


func test_go_to_victory_screen_changes_scene_successfully() -> void:
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(manager.go_to_victory_screen(), OK)


## Defeating the final boss is the one victory Battlefield._finish_victory()
## routes to the dedicated Campaign Victory screen instead of the ordinary
## battle-result summary -- detected by diffing GameSession.is_campaign_
## completed around GameSession.complete_current_encounter() (see that
## method's own doc comment), not by hardcoding the boss's encounter id.
func test_defeating_final_boss_routes_to_the_victory_screen() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/battle/battlefield.gd")

	assert_string_contains(source, "GameManager.go_to_victory_screen()")
	assert_string_contains(source, "just_won_campaign")


## Regression for the Step 5 review's Finding 1: the ordinary go_to_world_
## map() path merges the battle store into the party before ever landing on
## a screen the player can act on, but go_to_victory_screen() skipped that
## merge entirely, leaving the boss's own loot stranded in the transient
## battle_* store forever (go_to_encampment()'s Continue-button deposit is
## itself gated on the party no longer being deployed, which it still is
## right after winning). Unmerged loot also meant has_unsettled_battle_loot()
## stayed true, so the player could not save immediately after winning the
## campaign, and the victory summary's own "gold_banked" figure under-
## reported by omitting the unmerged reward. go_to_victory_screen() must
## settle everything -- merge into the party's carried store, then all the
## way into the durable banked totals -- so the screen shown, a save taken
## from it, and its own stat line all agree.
func test_go_to_victory_screen_settles_battle_loot_so_saving_is_immediately_possible() -> void:
	GameSession.reset()
	GameSession.gold = 100
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.create_battle_context(party_id, GameSession.GOBLIN_CAMP_ID)
	GameSession._battle_context.reward = {"gold": 5, "gear": {"dagger_iron": 1}, "mana_crystals": {1: 1}, "item_instance_ids": [] as Array[String]}
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_victory_screen()

	assert_false(
		GameSession.has_unsettled_battle_loot(),
		"The boss battle's own loot must be fully settled the instant the victory screen is reached"
	)
	assert_true(
		manager.can_save_current_campaign(),
		"A save must be possible immediately after the campaign is won"
	)
	assert_eq(GameSession.gold, 105, "The battle's own reward must be folded all the way into banked gold")
	assert_eq(
		int(GameSession.get_campaign_victory_summary().get("gold_banked", 0)), 105,
		"The victory summary's gold figure must reflect the merged total, not the pre-victory bank alone"
	)
	assert_eq(GameSession.get_active_battle_context().status, "victory")
	assert_eq(GameSession.get_party_carry(party_id).gold, 0, "The resolved reward must be fully deposited, not left carried")
	assert_eq(GameSession.mana_crystals, {1: 1})
	assert_eq(GameSession.banked_gear, {"dagger_iron": 1})


## --- Save/load wrappers (Step 2 -- see docs/plans/2026-08-10-initial- ------
## --- campaign-and-automation/02-atomic-save-repository.md). These tests ---
## --- only prove GameManager delegates to an injectable SaveRepository ----
## --- instead of ever touching FileAccess/DirAccess itself. The boundary --
## --- guard and routing decision tests are below, in the Step 3 section. --


func test_game_manager_source_never_touches_file_or_dir_access_directly() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_false(source.contains("FileAccess"), "UI/manager code must go through SaveRepository, never FileAccess directly")
	assert_false(source.contains("DirAccess"), "UI/manager code must go through SaveRepository, never DirAccess directly")


func test_save_repository_is_test_injectable() -> void:
	var repository := SaveRepositoryScript.new(TEST_SAVE_PATH)

	GameManager.save_repository = repository

	assert_eq(GameManager.save_repository.save_path, TEST_SAVE_PATH)


func test_save_current_campaign_delegates_to_the_injected_repository() -> void:
	GameSession.reset()
	GameSession.gold = 77
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	var result: Dictionary = GameManager.save_current_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(TEST_SAVE_PATH)), OK)
	assert_eq(json.data.gold, 77)


func test_load_current_campaign_imports_into_game_session_via_the_injected_repository() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	var writer_session: Node = preload("res://scripts/autoload/game_session.gd").new()
	autofree(writer_session)
	writer_session.gold = 123
	writer_repository.save_campaign(writer_session)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.load_current_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.gold, 123)


func test_load_current_campaign_never_mutates_game_session_when_the_repository_load_fails() -> void:
	GameSession.reset()
	GameSession.gold = 5
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	var result: Dictionary = GameManager.load_current_campaign()

	assert_false(result.ok)
	assert_eq(GameSession.gold, 5)


func test_has_valid_save_reflects_the_injected_repository() -> void:
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)

	assert_false(GameManager.has_valid_save())

	GameSession.reset()
	GameManager.save_current_campaign()

	assert_true(GameManager.has_valid_save())


## --- Save boundaries and the resume-a-campaign decision (Step 3 -- see ----
## --- docs/plans/2026-08-10-initial-campaign-and-automation/ ---------------
## --- 03-save-boundaries-and-menu.md). can_save_current_campaign()/ --------
## --- save_current_campaign() are tested against a FakeSaveRepository so ---
## --- "no write happened" is a cheap, deterministic assertion rather than --
## --- an absence-of-a-file check; go_to_loaded_campaign()'s routing --------
## --- decision is tested against a real (throwaway-path) SaveRepository ----
## --- since it needs an actual round trip to prove which branch fired. -----


func test_can_save_current_campaign_is_true_outside_an_active_encounter() -> void:
	GameSession.reset()

	assert_true(GameManager.can_save_current_campaign())


func test_can_save_current_campaign_is_false_during_an_active_encounter() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	assert_false(GameManager.can_save_current_campaign())

	GameSession.abandon_current_encounter()


## complete_current_encounter() clears selected_encounter *before* the
## active battle context's own reward is resolved into the party's carry
## (that happens later, in go_to_world_map()) -- so on the Battle Result
## screen,
## selected_encounter == "" even though this battle's loot has not yet been
## settled. can_save_current_campaign() must not rely solely on
## selected_encounter to cover this window; see GameSession.
## has_unsettled_battle_loot().
func test_can_save_current_campaign_is_false_when_battle_loot_is_unsettled() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.create_battle_context(GameSession.selected_party_id, GameSession.GOBLIN_CAMP_ID)
	GameSession._battle_context.reward.gold = 5

	assert_eq(GameSession.selected_encounter, "", "Sanity check: no active encounter is blocking the save")
	assert_false(GameManager.can_save_current_campaign())


func test_can_save_current_campaign_is_true_again_once_unsettled_battle_loot_is_merged() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.create_battle_context(GameSession.selected_party_id, GameSession.GOBLIN_CAMP_ID)
	GameSession._battle_context.reward.gold = 5
	GameSession.resolve_battle_victory(GameSession.get_active_battle_context().battle_id)

	assert_true(GameManager.can_save_current_campaign())


func test_save_current_campaign_makes_no_write_during_an_active_encounter() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var fake := FakeSaveRepository.new()
	GameManager.save_repository = fake

	var result: Dictionary = GameManager.save_current_campaign()

	assert_false(result.ok)
	assert_false(fake.save_called, "A blocked save must never reach the repository")
	GameSession.abandon_current_encounter()


func test_save_current_campaign_writes_when_no_encounter_is_active() -> void:
	GameSession.reset()
	var fake := FakeSaveRepository.new()
	GameManager.save_repository = fake

	var result: Dictionary = GameManager.save_current_campaign()

	assert_true(result.ok)
	assert_true(fake.save_called)


func test_successful_save_does_not_change_reward_buckets() -> void:
	GameSession.reset()
	GameSession.gold = 42
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.parties[0].carry.gold = 7
	GameSession.mana_crystals = {1: 3}
	GameSession.banked_gear = {"dagger_iron": 2}
	GameManager.save_repository = FakeSaveRepository.new()

	GameManager.save_current_campaign()

	assert_eq(GameSession.gold, 42)
	assert_eq(GameSession.get_party_carry(party_id).gold, 7)
	assert_eq(GameSession.mana_crystals, {1: 3})
	assert_eq(GameSession.banked_gear, {"dagger_iron": 2})


func test_go_to_loaded_campaign_routes_to_the_world_map_for_a_deployed_party() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(GameSession.has_deployed_party())
	# go_to_world_map() is the only routing branch that clears
	# route_context_id (via _clear_detail_context()) -- go_to_encampment()
	# never touches it -- so this doubles as proof of which branch fired.
	assert_eq(GameManager.route_context_id, "", "A deployed party must route through go_to_world_map()")
	GameManager.route_context_id = ""


func test_go_to_loaded_campaign_routes_to_the_encampment_for_an_undeployed_party() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_false(GameSession.has_deployed_party())
	assert_eq(
		GameManager.route_context_id, "stale",
		"An undeployed party must route through go_to_encampment(), which never touches route_context_id"
	)
	GameManager.route_context_id = ""


## Reward buckets must be preserved across a load, never additionally
## settled by it -- the same guarantee test_successful_save_does_not_
## change_reward_buckets() proves for the save side. go_to_loaded_campaign()
## calls the underlying routing primitives directly (_clear_detail_context()
## / _change_scene()) rather than go_to_world_map()/go_to_encampment()
## themselves, so this is a structural guarantee, not merely an argument
## about which states a real save can reach: GameSession.
## resolve_battle_victory() and GameSession.deposit_party_carry() are never
## called from anywhere in the load path, for any state. These tests set
## every reward bucket nonzero -- including combinations (e.g. a nonzero
## carry on an undeployed party) that a real save could probably never
## actually contain -- specifically to prove the guarantee does not depend
## on reachability.
func test_go_to_loaded_campaign_preserves_settled_reward_buckets_when_routing_to_the_encampment() -> void:
	GameSession.reset()
	GameSession.gold = 10
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.parties[0].carry = {
		"gold": 12, "gear": {}, "mana_crystals": {}, "item_instance_ids": [] as Array[String],
	}
	GameSession.banked_gear = {"dagger_iron": 3}
	GameSession.mana_crystals = {1: 2}
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_false(GameSession.has_deployed_party(), "Sanity check: this must route through the Encampment branch")
	assert_eq(GameSession.gold, 10)
	assert_eq(GameSession.get_party_carry(party_id).gold, 12)
	assert_eq(GameSession.banked_gear, {"dagger_iron": 3})
	assert_eq(GameSession.mana_crystals, {1: 2})


## Step 2 of docs/plans/2026-08-21-stage-1-campaign-spine: a withdrawn
## party's health/route/objective state (see GameSession.withdraw_from_
## encounter()) must survive a real save/load exactly like any other
## deployed-party state -- go_to_loaded_campaign() must route it back to the
## World Map still walking home, never silently settling it at the
## Encampment or resetting its route.
func test_go_to_loaded_campaign_returns_a_withdrawn_deployed_party_to_the_world_map_still_en_route() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)
	var route_before := GameSession.get_deployed_party_route()
	var health_before := GameSession.get_current_health(GameSession.WARRIOR_ID)
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(
		GameSession.has_deployed_party(),
		"A withdrawn party must route through go_to_world_map(), not settle at the Encampment"
	)
	assert_eq(GameSession.get_deployed_party_route(), route_before, "The homeward route must not be cleared by a load")
	assert_eq(GameSession.get_current_health(GameSession.WARRIOR_ID), health_before)
	assert_eq(GameSession.selected_encounter, "")
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain available after a load")
	assert_eq(GameSession.get_party_carry(GameSession.selected_party_id).gold, 0)
	assert_eq(GameSession.get_party_carry(GameSession.selected_party_id).gear, {})


func test_go_to_loaded_campaign_preserves_reward_buckets_when_routing_to_the_world_map() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	GameSession.gold = 5
	GameSession.parties[0].carry = {
		"gold": 25, "gear": {"dagger_iron": 1}, "mana_crystals": {1: 4}, "item_instance_ids": [] as Array[String],
	}
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameSession.reset()
	GameManager.save_repository = writer_repository

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_true(result.ok, result.get("error", ""))
	assert_true(GameSession.has_deployed_party(), "Sanity check: this must route through the World Map branch")
	assert_eq(GameSession.gold, 5)
	var carry: Dictionary = GameSession.get_party_carry(party_id)
	assert_eq(carry.gold, 25)
	assert_eq(carry.gear, {"dagger_iron": 1})
	assert_eq(carry.mana_crystals, {1: 4})


func test_go_to_loaded_campaign_closes_an_open_pause_menu_on_success() -> void:
	GameSession.reset()
	var writer_repository := SaveRepositoryScript.new(TEST_SAVE_PATH)
	writer_repository.save_campaign(GameSession)
	GameManager.save_repository = writer_repository
	GameManager.open_game_menu()

	GameManager.go_to_loaded_campaign()

	assert_false(GameManager.is_game_menu_open())
	assert_false(get_tree().paused)


func test_go_to_loaded_campaign_leaves_game_session_and_routing_untouched_on_a_failed_load() -> void:
	GameSession.reset()
	GameSession.gold = 55
	GameManager.save_repository = SaveRepositoryScript.new(TEST_SAVE_PATH)
	GameManager.route_context_id = "stale"

	var result: Dictionary = GameManager.go_to_loaded_campaign()

	assert_false(result.ok)
	assert_eq(GameSession.gold, 55, "A failed load must never touch GameSession")
	assert_eq(GameManager.route_context_id, "stale", "A failed load must never route anywhere")
	GameManager.route_context_id = ""


func test_go_to_parties_with_create_immediately_flag_sets_and_consumes_flag() -> void:
	GameManager.create_party_on_open = false

	GameManager.go_to_parties(true)

	assert_true(GameManager.create_party_on_open)
	assert_true(GameManager.consume_create_party_on_open())
	assert_false(GameManager.create_party_on_open)

