extends GutTest
## Step 5 (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 05-domain-extraction-and-stage-6-exit.md): the Stage 6 exit-gate journey.
## Drives one real fresh campaign through public GameSession/GameManager-
## facade APIs, composing every Stage 6 slice in a single arc:
##
##  - Two parties created and deployed independently, each auto-stepping its
##    own route on the same end_world_turn() (Party Carry Isolation /
##    multi-party invariant, index.md).
##  - Party 1 travels to the JSON-authored `obj_tier1_1_goblin_outpost`
##    encounter; a real BattleContext is claimed (blocking Party 2 from
##    claiming any battle while it is active, G4's carried-forward lock);
##    the real battlefield.tscn scene is built from it and its board/cover/
##    spawns are proven to come from the ContentCatalog JSON file, not a
##    hardcoded EXPEDITIONS/BattleController fallback.
##  - Victory is resolved through the exact same GameSession call sequence
##    battlefield.gd's own _finish_victory()/_persist_battle_aftermath() use
##    -- loot lands in party_001's own carry while party_002's carry (which
##    never fought) stays completely empty (Party Carry Isolation).
##  - The Party 1 Warrior levels to a promoted Knight and chooses the new
##    Stage 6 Step 4 branching pair: Discipline then Shield Bash, with a
##    real assertion that Chain Blow is now permanently foreclosed (sibling
##    mutual exclusion) -- then Shield Bash's granted action is proven to
##    land and off-balance a real target in an actual battle resolution
##    (PerkEffectResolver-driven, not just a static DAG-state check).
##  - Party 1 returns home and banks its carry while Party 2 -- which never
##    left its own independent route -- is proven untouched by any of it.
##  - A full CampaignSnapshot export -> reset -> import round trip over all
##    of the above is proven to restore every durable field byte-identical.
##
## This test does NOT re-derive:
##  - Full tactical AP/turn-order combat resolution (test_battle_controller.gd
##    already owns that exhaustively) -- the battle above is decided by the
##    same health/loot write-back sequence battlefield.gd itself calls, not
##    by manually playing every unit's turn.
##  - Defeat/retreat's own party-carry-forfeiture guard paths (already
##    proven, both before and after this step's extraction, by test_game_
##    session.gd's resolve_battle_defeat()/forfeit_party_carry() suites,
##    which this step's extraction left with their ORIGINAL assertions
##    unchanged).
##  - CampaignSnapshot's general triple-direction aliasing contract
##    (test_campaign_snapshot.gd owns that) -- this is a single straight
##    round trip over this journey's own accumulated state.

const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactoryScript := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const PerkEffectResolverScript := preload("res://scripts/battle/perk_effect_resolver.gd")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")

const GOBLIN_OUTPOST_ID := "obj_tier1_1_goblin_outpost"


func before_each() -> void:
	GameSession.reset()


func test_full_stage_6_journey_two_parties_catalog_battle_carry_isolation_branching_perk_and_snapshot_round_trip() -> void:
	# =========================================================================
	# PART 1 -- fresh campaign, two parties created and deployed independently.
	# =========================================================================

	assert_eq(GameSession.world_turn, 1, "Setup: a fresh campaign starts on world turn 1")
	assert_true(GameSession.parties.is_empty(), "Setup: a fresh campaign starts with no parties")

	var warrior_a_id: String = GameSession.WARRIOR_ID
	var warrior_b_id: String = GameSession.adventurers[1].id

	assert_true(GameSession.create_party("Party 1"))
	var party_001_id: String = GameSession.selected_party_id
	assert_true(GameSession.assign_adventurer_to_party(party_001_id, warrior_a_id))
	assert_true(GameSession.deploy_party(party_001_id))

	# A second party is only possible once the Guild Hall reaches its top
	# tier (Stage 5 D5, carried into Stage 6's PartyService capacity-limit
	# logic unchanged -- see get_max_party_count()).
	GameSession.gold += 1000
	while GameSession.can_upgrade_guild_hall():
		assert_true(GameSession.upgrade_guild_hall())
	assert_eq(GameSession.guild_hall_level, GameSession.GUILD_HALL_MAX_LEVEL)
	assert_eq(GameSession.get_max_party_count(), 2)

	assert_true(GameSession.create_party("Party 2"))
	var party_002_id: String = GameSession.selected_party_id
	assert_ne(party_002_id, party_001_id, "Setup: the two parties must have distinct ids")
	assert_true(GameSession.assign_adventurer_to_party(party_002_id, warrior_b_id))
	assert_true(GameSession.deploy_party(party_002_id))

	# obj_tier1_1_goblin_outpost's real catalog world_position (config/content/
	# encounters/obj_tier1_1_goblin_outpost.json) is (3, 4) -- one tile from
	# the starting settlement (3, 3). Party 2 is routed the opposite direction
	# so the two parties are provably travelling to different places.
	assert_true(GameSession.set_deployed_party_route([Vector2i(3, 4)] as Array[Vector2i], party_001_id))
	assert_true(GameSession.set_deployed_party_route([Vector2i(4, 3), Vector2i(5, 3)] as Array[Vector2i], party_002_id))

	GameSession.end_world_turn()  # every deployed party auto-steps its own unspent route independently

	assert_eq(GameSession.get_deployed_party_position(party_001_id), Vector2i(3, 4), "Party 1 must have arrived at the encounter's own catalog position")
	assert_true(GameSession.get_deployed_party_route(party_001_id).is_empty())
	assert_eq(GameSession.get_deployed_party_position(party_002_id), Vector2i(4, 3), "Party 2 must have taken its own first step, independently of Party 1")
	assert_eq(GameSession.get_deployed_party_route(party_002_id), [Vector2i(5, 3)] as Array[Vector2i], "Party 2 must still have its own remaining route -- it never reached, or was diverted toward, Party 1's destination")

	# =========================================================================
	# PART 2 -- Party 1 claims a real BattleContext for the JSON-authored
	# encounter (blocking Party 2 from claiming any battle while it is
	# active -- G4's carried-forward lock), and the real battlefield.tscn
	# scene is built from catalog-defined spawns and cover.
	# =========================================================================

	assert_true(GameSession.can_enter_encounter(GOBLIN_OUTPOST_ID))
	var context := GameSession.create_battle_context(party_001_id, GOBLIN_OUTPOST_ID)
	assert_false(context.is_empty())
	assert_eq(String(context.owner_party_id), party_001_id)
	assert_eq(String(context.status), "active")
	var battle_id: String = context.battle_id

	# G4 (decision-ledger.md), carried forward unchanged into BattleContext:
	# only one battle may be claimed at a time -- Party 2 cannot claim a
	# battle of its own (even a different encounter) while Party 1's is live.
	assert_true(
		GameSession.create_battle_context(party_002_id, GameSession.GOBLIN_CAMP_ID).is_empty(),
		"A second party must not be able to claim a battle while another party's battle is active"
	)

	GameSession.select_party(party_001_id)  # battle_controller.gd hydrates player units from the SELECTED party
	GameSession.enter_encounter(GOBLIN_OUTPOST_ID)
	assert_eq(GameSession.selected_encounter, GOBLIN_OUTPOST_ID)

	var catalog_definition: Dictionary = ContentCatalogScript.get_encounter_definition(GOBLIN_OUTPOST_ID)
	assert_false(catalog_definition.is_empty(), "Setup: obj_tier1_1_goblin_outpost must be a real, validated ContentCatalog entry")

	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	# battlefield.gd (the scene root) exposes its child BattleController node
	# as `grid`; BattleController's OWN `grid` field is the RefCounted board
	# (cover_tiles lives there) -- see scenes/battle/battlefield.tscn (the
	# "Grid" child node carries battle_controller.gd) and battlefield.gd's
	# own @onready `grid` reference to it. get_unit_at()/units are defined
	# directly on BattleController, so they are read off `controller`, not
	# `battlefield`, exactly like test_game_manager.gd's own established
	# `battlefield.grid.get_unit_at(...)` convention.
	var controller: Node2D = battlefield.grid

	assert_eq(
		controller.grid.cover_tiles, catalog_definition.cover_tiles,
		"The real battlefield scene's cover must come from the JSON catalog, not a hardcoded _cover_tiles_for_encounter() fallback"
	)
	# Party 1 fields exactly one member, so exactly the FIRST catalog
	# player_spawns tile is filled (BattleController._ready() bounds its
	# spawn loop by mini(player_adventurer_ids.size(), player_spawns.size())
	# -- see spawned_warrior's own assertion just below for the other two
	# catalog player_spawns tiles being unfilled is correct, not a gap).
	assert_not_null(controller.get_unit_at(catalog_definition.player_spawns[0]), "A player unit must be spawned on the first catalog-defined player_spawns tile")
	var enemy_units_found := 0
	for spawn_position in (catalog_definition.enemy_spawns as Array):
		var enemy_unit = controller.get_unit_at(spawn_position)
		if enemy_unit != null:
			enemy_units_found += 1
	assert_eq(enemy_units_found, (catalog_definition.enemy_composition as Array).reduce(func(total, group): return total + int(group.count), 0), "Every enemy the catalog's enemy_composition names must be spawned on a catalog-defined enemy_spawns tile")

	var spawned_warrior = controller.get_unit_at(catalog_definition.player_spawns[0])
	assert_eq(spawned_warrior.adventurer_id, warrior_a_id, "The spawned player unit must be Party 1's own member, hydrated from the SELECTED party (Party 1), not Party 2")

	# =========================================================================
	# PART 3 -- resolve victory through the exact same GameSession call
	# sequence battlefield.gd's own _finish_victory()/_persist_battle_
	# aftermath() use, and prove Party Carry Isolation: the loot lands in
	# Party 1's own carry only -- Party 2's carry (which never fought) stays
	# completely empty.
	# =========================================================================

	var health_by_id: Dictionary = {}
	var mp_by_id: Dictionary = {}
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
			health_by_id[unit.adventurer_id] = unit.health
			if unit.mp_max > 0:
				mp_by_id[unit.adventurer_id] = unit.mp_remaining
	assert_eq(health_by_id, {warrior_a_id: GameSession.get_current_health(warrior_a_id)}, "Setup: the spawned Warrior must have taken no damage in this proof")

	GameSession.resolve_battle_deaths(health_by_id)
	GameSession.apply_battle_aftermath(health_by_id)
	GameSession.apply_battle_mp_aftermath(mp_by_id)
	GameSession.complete_current_encounter()
	assert_true(GameSession.resolve_battle_victory(battle_id))

	assert_true(GameSession.completed_encounters.has(GOBLIN_OUTPOST_ID))
	assert_eq(GameSession.selected_encounter, "", "A resolved encounter must clear the current selection")

	var party_001_carry := GameSession.get_party_carry(party_001_id)
	assert_gt(int(party_001_carry.gold), 0, "Party 1's own carry must hold the loot from the battle it just won")

	var party_002_carry := GameSession.get_party_carry(party_002_id)
	assert_eq(party_002_carry.gold, 0, "Party Carry Isolation: Party 2 never fought -- its carry must not receive any of Party 1's loot")
	assert_true(party_002_carry.gear.is_empty(), "Party Carry Isolation: Party 2's gear carry must stay empty")
	assert_true(party_002_carry.mana_crystals.is_empty(), "Party Carry Isolation: Party 2's mana crystal carry must stay empty")
	assert_true(party_002_carry.item_instance_ids.is_empty(), "Party Carry Isolation: Party 2's item-instance carry must stay empty")

	# =========================================================================
	# PART 4 -- level the Party 1 Warrior into a promoted Knight and choose
	# the Stage 6 Step 4 branching pair: a shared "knight_discipline" root
	# gating a mutually exclusive choice between Shield Bash and Chain Blow.
	# =========================================================================

	GameSession._award_adventurer_xp(warrior_a_id, GameSession.get_level_xp_threshold(8))
	assert_eq(GameSession.get_adventurer(warrior_a_id).level, 8, "Setup: enough XP for one real leveling pass to earn both root perk slots plus both Knight perk slots")
	assert_true(GameSession.choose_perk(warrior_a_id, GameSession.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_true(GameSession.choose_perk(warrior_a_id, GameSession.WARRIOR_BULWARK_PERK_ID))
	assert_true(GameSession.get_available_specializations(warrior_a_id).has("knight"))
	assert_true(GameSession.promote_adventurer(warrior_a_id, "knight"))
	assert_eq(GameSession.get_adventurer_specialization(warrior_a_id), "knight")

	assert_false(
		GameSession.get_available_perks(warrior_a_id).has(GameSession.KNIGHT_SHIELD_BASH_PERK_ID),
		"Shield Bash must not be offered before its shared knight_discipline prerequisite is chosen"
	)
	assert_true(GameSession.choose_perk(warrior_a_id, GameSession.KNIGHT_DISCIPLINE_PERK_ID))
	assert_true(GameSession.choose_perk(warrior_a_id, GameSession.KNIGHT_SHIELD_BASH_PERK_ID))

	# Sibling mutual exclusion (G3, decision-ledger.md): once Shield Bash is
	# chosen, Chain Blow must be permanently foreclosed on this SAME
	# adventurer, even though a perk slot may still nominally exist.
	assert_false(
		GameSession.choose_perk(warrior_a_id, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID),
		"Shield Bash and Chain Blow are mutually exclusive -- choosing one must permanently foreclose the other"
	)
	var tree_status: Array[Dictionary] = GameSession.get_perk_tree_status(warrior_a_id)
	var chain_blow_state := ""
	for entry in tree_status:
		if entry.id == GameSession.KNIGHT_CHAIN_BLOW_PERK_ID:
			chain_blow_state = String(entry.state)
	assert_eq(chain_blow_state, "excluded", "Chain Blow's own DAG state must report excluded, not merely absent from the choosable list")

	# Combat-effect proof (not just a static DAG-state check): Shield Bash's
	# granted action actually lands and off-balances a real target in an
	# actual battle resolution, driven by PerkEffectResolver reading this
	# same adventurer's real progression.perks.
	var knight_adventurer := GameSession.get_adventurer(warrior_a_id)
	var shield_bash_scenario := ScenarioContractScript.normalize({
		"scenario_id": "stage6_exit_gate_knight_shield_bash",
		"player": {"units": [{
			"id": warrior_a_id,
			"template_id": "warrior",
			"weapon_id": GameSession.DEFAULT_WEAPON_ID,
			"armor_id": GameSession.DEFAULT_ARMOR_ID,
			"level": int(knight_adventurer.level),
			"perks": (knight_adventurer.progression.perks as Array).duplicate(),
			"specialization": "knight",
			"position": {"x": 0, "y": 0},
		}]},
		"enemy": {"units": [{"id": "shield_bash_target", "template_id": "kobold", "position": {"x": 1, "y": 0}}]},
		"rules": {"round_limit": 1},
	})
	var knight_controller: Node2D = BattleStateFactoryScript.build(shield_bash_scenario, 1)
	autofree(knight_controller)
	var knight_unit = knight_controller.get_unit_at(Vector2i(0, 0))
	var target_kobold = knight_controller.get_unit_at(Vector2i(1, 0))
	assert_true(
		PerkEffectResolverScript.has_granted_action(knight_unit.perks, "shield_bash"),
		"The battle unit's own hydrated perks must actually grant Shield Bash (PerkEffectResolver)"
	)
	assert_false(PerkEffectResolverScript.has_granted_action(knight_unit.perks, "chain_blow"))
	knight_controller.selected_unit = knight_unit
	knight_controller.hit_roll = func() -> float: return 0.0
	knight_controller.crit_roll = func() -> float: return 1.0
	assert_true(knight_controller.try_shield_bash_selected_unit(target_kobold.grid_position))
	assert_true(knight_controller.last_attack_result.hit)
	assert_true(target_kobold.off_balance_pending, "A landed Shield Bash must off-balance its target -- proves the granted action resolves a real combat effect, not just a DAG entry")

	# =========================================================================
	# PART 5 -- Party 1 routes home and banks its carry at the Encampment;
	# Party 2 -- which never left its own independent route -- must be
	# completely untouched by any of it.
	# =========================================================================

	assert_true(GameSession.return_deployed_party_to_settlement(party_001_id))
	assert_false(GameSession.has_deployed_party(party_001_id))

	var gold_before_deposit := GameSession.gold
	var deposited := GameSession.deposit_party_carry(party_001_id)
	assert_gt(int(deposited.gold), 0)
	assert_eq(GameSession.gold, gold_before_deposit + int(deposited.gold))
	assert_eq(GameSession.get_party_carry(party_001_id), GameSession._empty_carry(), "Party 1's carry must be cleared once deposited")

	assert_true(GameSession.has_deployed_party(party_002_id), "Party 2 must still be deployed -- Party 1's return/banking must not affect it")
	assert_eq(GameSession.get_deployed_party_position(party_002_id), Vector2i(4, 3), "Party 2's own position must be untouched by Party 1's return/banking")
	assert_eq(GameSession.get_deployed_party_route(party_002_id), [Vector2i(5, 3)] as Array[Vector2i], "Party 2's own remaining route must be untouched by Party 1's return/banking")
	assert_eq(GameSession.get_party_carry(party_002_id), GameSession._empty_carry(), "Party 2's carry must still be empty -- it never fought and never banked")

	# =========================================================================
	# PART 6 -- CHECKPOINT: a real export -> reset -> import round trip over
	# everything this journey accumulated, asserting zero state corruption.
	# =========================================================================

	var expected := _capture_durable_state()
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()
	var import_result := GameSession.import_campaign_snapshot(data)
	assert_true(import_result.ok, "Checkpoint import must succeed (%s)" % import_result.get("error", ""))
	_assert_durable_state_matches(expected)


## --- Checkpoint helpers ------------------------------------------------------

func _capture_durable_state() -> Dictionary:
	return {
		"adventurers": GameSession.adventurers.duplicate(true),
		"parties": GameSession.parties.duplicate(true),
		"selected_party_id": GameSession.selected_party_id,
		"world_turn": GameSession.world_turn,
		"gold": GameSession.gold,
		"banked_gear": GameSession.banked_gear.duplicate(true),
		"mana_crystals": GameSession.mana_crystals.duplicate(true),
		"banked_item_instance_ids": GameSession.banked_item_instance_ids.duplicate(true),
		"active_encounters": GameSession.active_encounters.duplicate(true),
		"completed_encounters": GameSession.completed_encounters.duplicate(true),
		"campaign_objective_id": GameSession.campaign_objective_id,
	}


func _assert_durable_state_matches(expected: Dictionary) -> void:
	assert_eq(GameSession.adventurers, expected.adventurers, "adventurers (roster, including the promoted Knight's level/perks/specialization)")
	assert_eq(GameSession.parties, expected.parties, "parties (both parties' member_ids/location/route/movement_spent/carry)")
	assert_eq(GameSession.selected_party_id, expected.selected_party_id, "selected_party_id")
	assert_eq(GameSession.world_turn, expected.world_turn, "world_turn")
	assert_eq(GameSession.gold, expected.gold, "gold (must include Party 1's deposited carry)")
	assert_eq(GameSession.banked_gear, expected.banked_gear, "banked_gear")
	assert_eq(GameSession.mana_crystals, expected.mana_crystals, "mana_crystals")
	assert_eq(GameSession.banked_item_instance_ids, expected.banked_item_instance_ids, "banked_item_instance_ids")
	assert_eq(GameSession.active_encounters, expected.active_encounters, "active_encounters")
	assert_eq(GameSession.completed_encounters, expected.completed_encounters, "completed_encounters")
	assert_eq(GameSession.campaign_objective_id, expected.campaign_objective_id, "campaign_objective_id")
