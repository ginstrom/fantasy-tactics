class_name CampaignSim
extends RefCounted
## Headless, scene-free campaign-level simulator (docs/plans/2026-08-18-
## core-loop-and-engagement/06-campaign-simulation-and-balance-harness.md).
## Drives an entire campaign run -- fresh session through the 12-battle
## authored ladder to Final Boss victory -- purely through existing public
## GameSession/BattleStateFactory/BattleController/BattleBot APIs, the exact
## scene-free battle-resolution boundary test_battle_controller.gd's
## _build_four_warriors_vs_ogre_controller()/_run_to_resolution() and Step
## 5's config/campaign_scenarios.json fixtures already establish. Never
## touches battlefield.gd, a .tscn, or any UI script.
##
## Fielding scope: FIELDABLE_CLASSES covers all three root classes -- Warrior,
## Scout, and Cleric (see docs/plans/2026-08-19-core-loop-verification-
## remediation/01-cleric-scenario-and-campaign-sim.md). ScenarioContract.
## KNOWN_PLAYER_TEMPLATES and BattleStateFactory._build_player_unit() both
## hydrate a Cleric's spells/mp_max/mp_remaining from GameSession.CLASS_
## DEFINITIONS the same way the real BattleController._ready() does for a
## scene battle, so a fielded Cleric can actually cast Heal/Bless through the
## real ScenarioContract -> BattleStateFactory -> BattleBot pipeline.
## _refill_party() prioritizes recruiting one of each missing FIELDABLE_
## CLASSES member before spending gold on a duplicate, so a representative
## run fields Warrior/Scout/Cleric together rather than only ever doubling up
## on whichever class happens to be cheapest.
##
## Travel simplification: GameSession.enter_encounter() never gates on
## world_position (see its own body) and deploy_party()/return_deployed_
## party_to_settlement() always reset world_position to the settlement tile
## regardless of where the party stood before -- so pixel/tile-accurate
## route-following (world_map.gd's build_route() + one take_next_route_step()
## per world turn) has no gameplay effect this simulator needs to reproduce.
## _travel_to_objective() instead snaps the party's recorded position
## straight to the objective and spends one GameSession.end_world_turn() per
## Manhattan tile of distance, preserving the real per-turn pacing (passive
## income, natural recovery, vacancy timers) without reimplementing grid
## pathfinding.

const BattleStateFactoryScript := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleBotScript := preload("res://scripts/tools/battle_bot.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

## The three root classes the scene-free battle path can field (see this
## file's own header comment).
const FIELDABLE_CLASSES: Array[String] = ["warrior", "scout", "cleric"]

## The representative seed set this simulator's own bot/gear/upgrade policy
## is verified (see test_campaign_sim.gd's
## test_run_campaign_reaches_victory_on_the_representative_seed_set()) to
## carry all the way to Final Boss victory. Per docs/plans/2026-08-19-core-
## loop-verification-remediation/02-representative-seed-command.md ("reach
## victory on an explicitly listed representative seed set ... report
## failures for every other seed; do not claim a universal completion
## percentage from ten arbitrary samples"), this is a deliberately small,
## hand-verified set -- not a claim that every seed outside it fails, only
## that these are the ones a victory guarantee is locked to. This is the
## single production-owned copy: campaign_sim_main.gd (the `make
## campaign-sim` CLI), campaign_sim_metrics.gd, and the test suite all read
## this constant rather than keeping independent copies of the same five
## numbers.
##
## A wider sweep (seeds 1-80, re-run after a prior review's fix addendum --
## see that step's report for the full table) shows the campaign is
## completable on nearly every seed (78/80 in that range; only seeds 3 and
## 25 fail). That's a sharp rise from an earlier report's 60-65%, and not
## from reordering findings alone: fixing them surfaced a third,
## previously-undiscovered bug in this same code -- _fight_objective()'s
## `kill_xp` accumulator was a GDScript lambda closure over a plain float,
## which GDScript captures BY VALUE, so every battle's kill XP was silently
## discarded and only clear_xp was ever actually awarded (see that report's
## fix addendum for the full explanation and fix). Restoring the missing
## kill XP raises the leveling pace enough that the pre-Boss repeated-wipe
## spiral this suite originally locked seeds 1/2/5/7 out of essentially
## stops happening. Seeds 4, 9, 10, 12, and 14 are the first five winning
## seeds in the post-fix sweep, chosen in ascending order rather than
## cherry-picked for any other property.
##
## HISTORICAL CONTEXT, READ BEFORE CITING: the "78/80", "seeds 3 and 25",
## and "first five winning seeds in the post-fix sweep" figures above were
## measured BEFORE docs/plans/2026-08-19-core-loop-verification-remediation/
## made Cleric fieldable and changed recruitment/assignment priority (both
## of which affect every seed's outcome) -- they describe the sweep this
## five-seed set was originally drawn from, not a claim still verified true
## of the current code. What IS still true and hand-verified today (see
## test_run_campaign_reaches_victory_on_the_representative_seed_set()): these
## five seeds still resolve to victory under the current bot/gear/recruit/
## upgrade policy. A fresh 80-seed sweep has not been re-run post-Cleric, so
## the exact current pass count/fail set is unknown -- do not repeat the old
## numbers as if they still hold.
const REPRESENTATIVE_VICTORY_SEEDS: Array[int] = [4, 9, 10, 12, 14]

## Safety caps -- generous enough that a genuinely winnable seed always
## resolves, tight enough that a soft-locked or stuck run still terminates
## instead of hanging a batch of simulations.
const MAX_WORLD_TURNS := 400
const MAX_OBJECTIVE_ATTEMPTS := 400
const MAX_BATTLE_ROUNDS := 40
## Bound on how many consecutive world turns the encampment phase will spend
## just waiting for enough gold to field a minimally viable party (see
## _wait_for_ready_party()) before giving up on this attempt cycle -- keeps a
## true zero-income deadlock (should not exist; see test_campaign_recovery.gd)
## from spinning forever.
const MAX_ENCAMPMENT_WAIT_TURNS := 60

var sim_seed: int = 12345


## Runs one full, deterministic campaign from a fresh session and returns its
## telemetry (see _new_telemetry()). Never touches GameManager (no scene
## navigation exists to drive) -- every state transition a real playthrough
## would make via GameManager's thin wrappers is reproduced here directly
## against the same underlying GameSession calls those wrappers make.
func run_campaign(seed: int) -> Dictionary:
	sim_seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_wire_deterministic_rolls(rng)

	GameSession.start_new_game()
	var telemetry := _new_telemetry(seed)

	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	_refill_party(telemetry)
	GameSession.deploy_party(party_id)

	var attempts := 0
	while (
		not GameSession.is_campaign_completed
		and GameSession.world_turn < MAX_WORLD_TURNS
		and attempts < MAX_OBJECTIVE_ATTEMPTS
	):
		attempts += 1

		# Per-objective-record hooks start here (docs/plans/2026-08-22-stage-
		# 3-campaign-assembly/02-campaign-telemetry-and-comparison.md): every
		# value captured below is read-only evidence gathered at existing
		# public transition points, never a second rules model -- battle
		# state itself is still built exclusively through _fight_objective()'s
		# own ScenarioContract/BattleStateFactory call. A record is only ever
		# appended to telemetry.objective_records once an objective is
		# actually fought (see the append below); a cycle that breaks out
		# early (campaign already completed, no objective left, or no
		# fieldable member could be recruited) has nothing to report and
		# leaves these locals discarded.
		var record_world_turn_start: int = GameSession.world_turn
		var record_gold_before: int = GameSession.gold
		var record_vitals_before := _party_vitals_snapshot()
		var record_upgrades_purchased: Array[String] = []

		_run_encampment_phase(telemetry, record_upgrades_purchased)
		if GameSession.is_campaign_completed:
			break

		var encounter_id: String = GameSession.campaign_objective_id
		if encounter_id == "" or not GameSession.can_enter_encounter(encounter_id):
			break
		if not GameSession.has_deployed_party():
			GameSession.deploy_party(party_id)
		if not GameSession.has_deployed_party():
			# No fieldable member could be recruited within the encampment
			# phase's own wait budget -- further looping cannot help.
			break

		_record_level_curve(telemetry, encounter_id)
		_travel_to_objective(encounter_id, telemetry)

		# Snapshotting party composition/level/vitals here (after travel,
		# immediately before combat) captures who was actually fielded for
		# this fight and how much HP/MP the world-turns spent waiting and
		# traveling since the previous objective recovered -- the exact
		# "recovery interval" the step's manual check asks a reviewer to be
		# able to identify from the report alone. _vitals_recovered() excludes
		# any member recruited mid-cycle (present in `after`, absent from
		# `before`) so a recruit's full starting HP/MP is never misread as
		# rest recovery -- see that function's own doc comment.
		var record_vitals_after := _party_vitals_snapshot()
		var record_party_composition := _party_composition_snapshot()
		var record_level_summary := _party_level_summary()
		var record_vitals_recovered := _vitals_recovered(record_vitals_before, record_vitals_after)

		var record_party_losses: Array[String] = []
		var outcome := _fight_objective(encounter_id, telemetry, record_party_losses)
		_return_to_encampment(telemetry)

		telemetry.objective_records.append({
			"objective_id": encounter_id,
			"outcome": outcome,
			"world_turn_start": record_world_turn_start,
			"world_turn_end": GameSession.world_turn,
			"party_losses": record_party_losses,
			"hp_recovered": int(record_vitals_recovered.hp),
			"mp_recovered": int(record_vitals_recovered.mp),
			"gold_before": record_gold_before,
			"gold_after": GameSession.gold,
			"upgrades_purchased": record_upgrades_purchased,
			"party_composition": record_party_composition,
			"level_summary": record_level_summary,
		})

	telemetry.victory = GameSession.is_campaign_completed
	telemetry.world_turns = GameSession.world_turn
	if telemetry.victory:
		telemetry.reason = "victory"
	elif GameSession.world_turn >= MAX_WORLD_TURNS:
		telemetry.reason = "max_turns_exceeded"
	else:
		telemetry.reason = "max_attempts_exceeded"
	telemetry.final_average_level = _average_party_level()
	return telemetry


func _new_telemetry(seed: int) -> Dictionary:
	return {
		"seed": seed,
		"victory": false,
		"reason": "",
		"world_turns": 0,
		"battles_fought": 0,
		"battles_won": 0,
		"battles_retreated": 0,
		"stalemates": 0,
		"party_wipes": 0,
		"unit_deaths": 0,
		"gold_earned": 0,
		"gold_spent_upgrades": 0,
		"gold_spent_recruits": 0,
		"gold_spent_gear": 0,
		"gold_lost_wipes": 0,
		"upgrade_progression_turns": {},
		"party_level_curve": {},
		"final_average_level": 0.0,
		# Set true the first time the party simultaneously contains one
		# member of every FIELDABLE_CLASSES entry (see _record_full_triad())
		# -- proof a representative run actually fields the full Warrior/
		# Scout/Cleric triad together, not just that a Cleric was recruited
		# at some unrelated point. full_triad_party_size records the party
		# size at that moment (3 at the Guild Hall level-1 party cap, before
		# any Guild Hall upgrade).
		"fielded_full_triad": false,
		"full_triad_party_size": 0,
		# Total BattleBot spell casts (Heal/Bless) across every battle this
		# run fought, derived from the "spell"-typed action records
		# BattleBot.take_player_turn() returns (see _run_battle_to_
		# resolution()) -- never a separate hand-counted mechanism.
		"spell_casts": 0,
		# Ordered (append-only, one entry per objective actually fought) --
		# see run_campaign()'s own per-objective-record hooks and this file's
		# _party_vitals_snapshot()/_party_composition_snapshot()/_party_
		# level_summary() helpers. Each entry: objective_id, outcome,
		# world_turn_start/world_turn_end, party_losses (adventurer ids that
		# died this fight), hp_recovered/mp_recovered (observed since the
		# previous objective), gold_before/gold_after, upgrades_purchased
		# (first purchased during this cycle's encampment phase),
		# party_composition (fielded class ids), and level_summary
		# ({levels, average}) -- the full-arc evidence docs/plans/2026-08-22-
		# stage-3-campaign-assembly/02-campaign-telemetry-and-comparison.md
		# requires (see that step's own manual-check requirement: identify a
		# setback, recovery interval, objective reached, upgrade timing, and
		# final outcome from the report alone).
		"objective_records": [],
	}


## --- Encampment phase: recruit, upgrade, gear, wait for viability ---------

## `upgrades_out`, if supplied, collects the upgrade keys first purchased
## during this call (see _mark_upgrade()) -- run_campaign()'s per-objective-
## record hook uses this to report which upgrade(s) landed during this
## objective's own encampment cycle. Optional (defaults to a throwaway
## Array) so every other caller/test keeps working unchanged.
func _run_encampment_phase(telemetry: Dictionary, upgrades_out: Array[String] = []) -> void:
	_refill_party(telemetry)
	_purchase_affordable_upgrades(telemetry, upgrades_out)
	_equip_best_gear(telemetry)
	_refill_party(telemetry)
	_wait_for_ready_party(telemetry)
	_purchase_affordable_upgrades(telemetry, upgrades_out)
	_equip_best_gear(telemetry)


## Minimum combat viability for another objective attempt: at least one
## fieldable (Warrior/Scout) party member. A weak-but-nonempty party can
## still be sent in -- losing and rebuilding is a valid, expected outcome
## this simulator measures (party_wipes), not something to gate on.
func _party_ready() -> bool:
	return not _fieldable_member_ids().is_empty()


func _wait_for_ready_party(telemetry: Dictionary) -> void:
	var waited := 0
	while (
		not _party_ready()
		and GameSession.world_turn < MAX_WORLD_TURNS
		and waited < MAX_ENCAMPMENT_WAIT_TURNS
	):
		_advance_world_turn(telemetry)
		waited += 1
		_refill_party(telemetry)


## Assigns every already-owned, unassigned Warrior/Scout/Cleric to the party
## (up to its Guild Hall-gated size cap), then spends gold on affordable
## Warrior/Scout/Cleric recruitment offers while the roster still has room --
## preferring the cheapest offer for a class the party doesn't yet field over
## a cheaper duplicate of a class it already has (see _next_recruitment_
## candidate()), so a representative run fields all three classes together
## rather than only ever doubling up on whichever offer happens to be
## cheapest. `telemetry` is optional so callers that only care about party
## membership (e.g. a unit test) can omit it.
func _refill_party(telemetry: Dictionary = {}) -> void:
	var party := GameSession.get_selected_party()
	if party.is_empty():
		return
	var capacity: int = GameSession.get_max_party_size()

	_assign_owned_fieldable_members(capacity)

	party = GameSession.get_selected_party()
	while party.member_ids.size() < capacity and GameSession.adventurers.size() < GameSession.get_roster_cap():
		var candidate := _next_recruitment_candidate()
		if candidate.is_empty():
			break
		var before: int = GameSession.gold
		if not GameSession.purchase_recruit_for_party(String(candidate.id), party.id):
			break
		if not telemetry.is_empty():
			telemetry.gold_spent_recruits += before - GameSession.gold
		party = GameSession.get_selected_party()

	if not telemetry.is_empty():
		_record_full_triad(telemetry)


## Assigns already-owned, available (unassigned) fieldable adventurers to the
## party up to `capacity`, preferring -- for each newly opened slot -- an
## available member whose class the party doesn't yet field (see _missing_
## fieldable_classes()) over an available member whose class is already
## represented. Mirrors the same missing-class-first policy _next_
## recruitment_candidate() already applies to purchases (see this file's own
## header comment): before this fix, this loop had no such preference and
## simply walked GameSession.get_available_adventurers() in roster order, so
## a leftover starting-roster Warrior could fill a newly opened slot (e.g.
## from a Guild Hall upgrade) ahead of an already-owned, unassigned Scout or
## Cleric. (Representative seed 12 still never fields a Cleric even with
## this fix, for an unrelated reason: its RNG stream never rolls an
## affordable Cleric recruitment offer in the first place -- see
## REPRESENTATIVE_VICTORY_SEEDS' own doc comment and this fix's report.)
## `excluded` tracks candidate ids that failed to assign this call (e.g. the
## party isn't currently encamped -- see _next_owned_fieldable_member()) so a
## candidate GameSession.assign_adventurer_to_selected_party() keeps
## rejecting can never be retried forever: each iteration either grows the
## party or permanently excludes a candidate, so this always terminates
## within the roster's own finite size, exactly like the old plain for-loop
## over GameSession.get_available_adventurers() this replaced (which simply
## moved on to the next adventurer whenever an assign call failed).
func _assign_owned_fieldable_members(capacity: int) -> void:
	var excluded := {}
	var party := GameSession.get_selected_party()
	while party.member_ids.size() < capacity:
		var pick := _next_owned_fieldable_member(excluded)
		if pick == "":
			break
		if not GameSession.assign_adventurer_to_selected_party(pick):
			excluded[pick] = true
			continue
		party = GameSession.get_selected_party()


## The available (unassigned), fieldable adventurer _assign_owned_fieldable_
## members() assigns next (skipping any id already in `excluded`): the first
## (roster order) available member of a class the party doesn't yet field, if
## one exists, otherwise the first available fieldable member overall (which
## may duplicate a class already present) -- the same missing-class-first /
## duplicate-fallback shape _next_recruitment_candidate() uses for purchases.
func _next_owned_fieldable_member(excluded: Dictionary = {}) -> String:
	var missing := _missing_fieldable_classes()
	if not missing.is_empty():
		for adventurer in GameSession.get_available_adventurers():
			if excluded.has(String(adventurer.id)):
				continue
			if _is_fieldable(adventurer) and String(adventurer.get("class", "")) in missing:
				return String(adventurer.id)
	for adventurer in GameSession.get_available_adventurers():
		if excluded.has(String(adventurer.id)):
			continue
		if _is_fieldable(adventurer):
			return String(adventurer.id)
	return ""


func _is_fieldable(adventurer: Dictionary) -> bool:
	return String(adventurer.get("class", "")) in FIELDABLE_CLASSES


func _fieldable_member_ids() -> Array:
	var ids: Array = []
	for member_id in GameSession.get_selected_party().get("member_ids", []):
		var adventurer := GameSession.get_adventurer(member_id)
		if not adventurer.is_empty() and _is_fieldable(adventurer):
			ids.append(member_id)
	return ids


## The recruit _refill_party() actually purchases next: the cheapest
## affordable offer for a FIELDABLE_CLASSES entry the party doesn't yet
## field, if one exists and is affordable, otherwise the overall cheapest
## affordable fieldable offer (which may duplicate a class already present).
func _next_recruitment_candidate() -> Dictionary:
	var missing := _missing_fieldable_classes()
	if not missing.is_empty():
		var priority_candidate := _cheapest_affordable_fieldable_candidate_of_classes(missing)
		if not priority_candidate.is_empty():
			return priority_candidate
	return _cheapest_affordable_fieldable_candidate()


## FIELDABLE_CLASSES entries with no current party member of that class.
func _missing_fieldable_classes() -> Array:
	var present := {}
	for member_id in GameSession.get_selected_party().get("member_ids", []):
		var adventurer := GameSession.get_adventurer(member_id)
		if not adventurer.is_empty():
			present[String(adventurer.get("class", ""))] = true
	var missing: Array = []
	for class_id in FIELDABLE_CLASSES:
		if not present.has(class_id):
			missing.append(class_id)
	return missing


func _cheapest_affordable_fieldable_candidate() -> Dictionary:
	return _cheapest_affordable_fieldable_candidate_of_classes(FIELDABLE_CLASSES)


func _cheapest_affordable_fieldable_candidate_of_classes(classes: Array) -> Dictionary:
	var best := {}
	for candidate in GameSession.get_recruitment_candidates():
		if not _is_fieldable(candidate):
			continue
		if not (String(candidate.get("class", "")) in classes):
			continue
		if int(candidate.cost) > GameSession.gold:
			continue
		if best.is_empty() or int(candidate.cost) < int(best.cost):
			best = candidate
	return best


## Marks telemetry.fielded_full_triad the first time the party simultaneously
## contains a member of every FIELDABLE_CLASSES entry -- see _new_telemetry()
## and the header comment's fielding-scope note. A no-op once already
## recorded (telemetry only ever records the first occurrence).
func _record_full_triad(telemetry: Dictionary) -> void:
	if telemetry.get("fielded_full_triad", false):
		return
	var present := {}
	for member_id in GameSession.get_selected_party().get("member_ids", []):
		var adventurer := GameSession.get_adventurer(member_id)
		if not adventurer.is_empty():
			present[String(adventurer.get("class", ""))] = true
	for class_id in FIELDABLE_CLASSES:
		if not present.has(class_id):
			return
	telemetry.fielded_full_triad = true
	telemetry.full_triad_party_size = GameSession.get_selected_party().get("member_ids", []).size()


## Building purchase priority mirrors the technical design's own macro-loop
## bullet verbatim ("Prioritize and purchase Encampment upgrades (Guild
## Hall, Temple, Shop, Blacksmith) as gold permits") -- one purchase per
## matched priority per pass, looped until a pass buys nothing, so a
## windfall can chain multiple tiers in one encampment visit without this
## policy trying to be any smarter than "buy what's next and affordable."
## `upgrades_out` -- see _run_encampment_phase()'s identical parameter doc
## comment; threaded through unchanged to _mark_upgrade().
func _purchase_affordable_upgrades(telemetry: Dictionary, upgrades_out: Array[String] = []) -> void:
	var iterations := 0
	var purchased := true
	while purchased and iterations < 10:
		iterations += 1
		purchased = false
		var before: int = GameSession.gold
		if GameSession.can_upgrade_guild_hall() and GameSession.upgrade_guild_hall():
			purchased = true
			telemetry.gold_spent_upgrades += before - GameSession.gold
			_mark_upgrade(telemetry, "guild_hall_level_%d" % GameSession.guild_hall_level, upgrades_out)
			continue
		before = GameSession.gold
		if GameSession.can_build_temple() and GameSession.build_temple():
			purchased = true
			telemetry.gold_spent_upgrades += before - GameSession.gold
			_mark_upgrade(telemetry, "temple", upgrades_out)
			continue
		before = GameSession.gold
		if GameSession.can_upgrade_shop() and GameSession.upgrade_shop():
			purchased = true
			telemetry.gold_spent_upgrades += before - GameSession.gold
			_mark_upgrade(telemetry, "shop_level_%d" % GameSession.shop_level, upgrades_out)
			continue
		before = GameSession.gold
		if GameSession.can_build_blacksmith() and GameSession.build_blacksmith():
			purchased = true
			telemetry.gold_spent_upgrades += before - GameSession.gold
			_mark_upgrade(telemetry, "blacksmith", upgrades_out)
			continue
		before = GameSession.gold
		if GameSession.can_upgrade_blacksmith() and GameSession.upgrade_blacksmith():
			purchased = true
			telemetry.gold_spent_upgrades += before - GameSession.gold
			_mark_upgrade(telemetry, "blacksmith_level_%d" % GameSession.blacksmith_level, upgrades_out)
			continue


## `upgrades_out`, if supplied, also receives `key` -- but only the first
## time this particular key is ever marked for the whole run (mirrors the
## telemetry.upgrade_progression_turns guard immediately below), so a caller
## reusing the same Array across multiple _purchase_affordable_upgrades()
## calls within one objective's encampment phase (see _run_encampment_
## phase()) only records an upgrade once, at the cycle it actually first
## landed.
func _mark_upgrade(telemetry: Dictionary, key: String, upgrades_out: Array[String] = []) -> void:
	if not telemetry.upgrade_progression_turns.has(key):
		telemetry.upgrade_progression_turns[key] = GameSession.world_turn
		upgrades_out.append(key)


## Equips each fielded party member with the best owned (banked) weapon of
## their currently-equipped weapon's own category and the best owned armor,
## "best" meaning highest catalog price -- a simple, monotonic proxy for
## power that avoids re-deriving the full damage/defense formula here. Gear
## reaches banked_gear organically: Shop purchases (buy_item(), iron/steel
## weapons only) and battle loot (_roll_and_queue_loot()'s gear drops, which
## include armor). This is deliberately not a crafting/sharpening policy --
## Blacksmith jobs are a deeper system than "prioritize and purchase
## upgrades as gold permits" calls for.
func _equip_best_gear(telemetry: Dictionary = {}) -> void:
	for member_id in _fieldable_member_ids():
		_buy_best_shop_weapon(member_id, telemetry)
		_equip_best_weapon(member_id)
		_equip_best_armor(member_id)


## Buys the highest-price catalog weapon (see get_shop_catalogue_item_ids())
## affordable and matching member_id's own weapon category, if it beats
## their currently-equipped weapon -- banked immediately so _equip_best_
## weapon() picks it up right after. A no-op once the Shop's catalogue has
## nothing left worth buying (already own the best, or nothing affordable
## beats it).
func _buy_best_shop_weapon(member_id: String, telemetry: Dictionary) -> void:
	var adventurer := GameSession.get_adventurer(member_id)
	if adventurer.is_empty():
		return
	var current_id: String = String(adventurer.equipment.get("weapon", ""))
	var current: Dictionary = GameSession.WEAPONS.get(current_id, {})
	var category: String = String(current.get("category", ""))
	var best_price: int = int(current.get("price", 0))
	var best_id := ""
	for item_id in GameSession.get_shop_catalogue_item_ids():
		var item: Dictionary = GameSession.WEAPONS.get(item_id, {})
		if String(item.get("category", "")) != category:
			continue
		var price := int(item.get("price", 0))
		if price > best_price and price <= GameSession.gold:
			best_price = price
			best_id = item_id
	if best_id == "":
		return
	var before: int = GameSession.gold
	if GameSession.buy_item(best_id) and not telemetry.is_empty():
		telemetry.gold_spent_gear = telemetry.get("gold_spent_gear", 0) + (before - GameSession.gold)


func _equip_best_weapon(member_id: String) -> void:
	var adventurer := GameSession.get_adventurer(member_id)
	if adventurer.is_empty():
		return
	var current_id: String = String(adventurer.equipment.get("weapon", ""))
	var current: Dictionary = GameSession.WEAPONS.get(current_id, {})
	var category: String = String(current.get("category", ""))
	var best_price: int = int(current.get("price", 0))
	var best_id := ""
	for item_id in GameSession.banked_gear.keys():
		if int(GameSession.banked_gear[item_id]) <= 0:
			continue
		var item: Dictionary = GameSession.WEAPONS.get(item_id, {})
		if item.is_empty() or String(item.get("category", "")) != category:
			continue
		if int(item.get("price", 0)) > best_price:
			best_price = int(item.get("price", 0))
			best_id = item_id
	if best_id != "":
		GameSession.equip_item_from_bank(member_id, best_id)


func _equip_best_armor(member_id: String) -> void:
	var adventurer := GameSession.get_adventurer(member_id)
	if adventurer.is_empty():
		return
	var current_id: String = String(adventurer.equipment.get("armor", ""))
	var current: Dictionary = GameSession.ARMORS.get(current_id, {})
	var best_price: int = int(current.get("price", 0))
	var best_id := ""
	for item_id in GameSession.banked_gear.keys():
		if int(GameSession.banked_gear[item_id]) <= 0:
			continue
		var item: Dictionary = GameSession.ARMORS.get(item_id, {})
		if item.is_empty():
			continue
		if int(item.get("price", 0)) > best_price:
			best_price = int(item.get("price", 0))
			best_id = item_id
	if best_id != "":
		GameSession.equip_item_from_bank(member_id, best_id)


func _average_party_level() -> float:
	var ids := _fieldable_member_ids()
	if ids.is_empty():
		return 0.0
	var total := 0
	for member_id in ids:
		total += int(GameSession.get_adventurer(member_id).get("level", 1))
	return float(total) / float(ids.size())


## Records current HP and current MP -- the same durable roster values
## get_effective_max_mp()/get_current_mp() already read elsewhere in this
## file, not a battle Unit's transient state -- per fielded (Warrior/Scout/
## Cleric) member id, at the instant this is called. Keyed by member id
## (rather than pre-summed) so _vitals_recovered() below can compute a
## before/after delta restricted to members who were actually present at
## BOTH snapshots -- a member recruited between the two snapshots (see
## _refill_party(), called during the encampment phase between run_
## campaign()'s "before" and "after" calls) must never have their full
## starting HP/MP counted as "recovered": that would be roster growth, not
## downtime healing, and would corrupt the recovery-interval evidence a
## reviewer reads from objective_records (see this step's own manual-check
## requirement). MP only recorded for a class that actually has one
## (get_effective_max_mp() returns 0 for a non-caster) -- mirrors _build_
## player_units()'s identical mp_current guard.
func _party_vitals_snapshot() -> Dictionary:
	var hp_by_member := {}
	var mp_by_member := {}
	for member_id in _fieldable_member_ids():
		hp_by_member[member_id] = GameSession.get_current_health(member_id)
		if GameSession.get_effective_max_mp(member_id) > 0:
			mp_by_member[member_id] = GameSession.get_current_mp(member_id)
	return {"hp_by_member": hp_by_member, "mp_by_member": mp_by_member}


## HP/MP actually recovered between two _party_vitals_snapshot() calls,
## summed only across member ids present in BOTH `before` and `after` --
## see _party_vitals_snapshot()'s own doc comment for why a same-cycle
## recruit (present in `after` but not `before`) must be excluded rather
## than having their starting HP/MP misread as recovery. A member present
## only in `before` (e.g. lost mid-cycle, which does not happen on this
## snapshot pair today since no combat occurs between them) is excluded the
## same way. Clamped at 0 per resource: natural recovery only ever restores
## HP/MP toward max, never below the "before" reading, for any member this
## delta actually counts.
func _vitals_recovered(before: Dictionary, after: Dictionary) -> Dictionary:
	var hp_delta := 0
	var before_hp: Dictionary = before.hp_by_member
	for member_id in after.hp_by_member:
		if before_hp.has(member_id):
			hp_delta += maxi(0, int(after.hp_by_member[member_id]) - int(before_hp[member_id]))
	var mp_delta := 0
	var before_mp: Dictionary = before.mp_by_member
	for member_id in after.mp_by_member:
		if before_mp.has(member_id):
			mp_delta += maxi(0, int(after.mp_by_member[member_id]) - int(before_mp[member_id]))
	return {"hp": hp_delta, "mp": mp_delta}


## Ordered (party.member_ids order, via _fieldable_member_ids()) class ids of
## the currently fielded party -- e.g. ["warrior", "warrior", "cleric"] --
## for an objective_records entry's party_composition field.
func _party_composition_snapshot() -> Array[String]:
	var classes: Array[String] = []
	for member_id in _fieldable_member_ids():
		classes.append(String(GameSession.get_adventurer(member_id).get("class", "")))
	return classes


## Per-member level list (same order as _party_composition_snapshot()) plus
## the average _average_party_level() already computes, for an objective_
## records entry's level_summary field.
func _party_level_summary() -> Dictionary:
	var levels: Array[int] = []
	for member_id in _fieldable_member_ids():
		levels.append(int(GameSession.get_adventurer(member_id).get("level", 1)))
	return {"levels": levels, "average": _average_party_level()}


func _record_level_curve(telemetry: Dictionary, encounter_id: String) -> void:
	var tier := int(GameSession.CAMPAIGN_OBJECTIVES.get(encounter_id, {}).get("tier", 0))
	if tier == 0:
		return
	var key := "boss" if tier == 5 else "tier%d" % tier
	if telemetry.party_level_curve.has(key):
		return
	telemetry.party_level_curve[key] = _average_party_level()


## --- Travel ------------------------------------------------------------

func _travel_to_objective(encounter_id: String, telemetry: Dictionary) -> void:
	var expedition := GameSession.get_expedition(encounter_id)
	var target: Vector2i = expedition.get("position", GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
	var current: Vector2i = GameSession.get_deployed_party_position()
	var distance: int = absi(target.x - current.x) + absi(target.y - current.y)
	GameSession.set_deployed_party_position(target)
	for _step in distance:
		if GameSession.world_turn >= MAX_WORLD_TURNS:
			return
		_advance_world_turn(telemetry)


func _advance_world_turn(telemetry: Dictionary) -> void:
	var before: int = GameSession.gold
	GameSession.end_world_turn()
	var delta := GameSession.gold - before
	if delta > 0:
		telemetry.gold_earned += delta


## --- Battle: same scene-free construction/resolution boundary as
## test_battle_controller.gd's _build_four_warriors_vs_ogre_controller()/
## _run_to_resolution() -----------------------------------------------------

## `party_losses_out`, if supplied, receives the adventurer ids permadeath
## removed this specific fight (see _persist_battle_state()'s own dead_ids
## return) -- run_campaign()'s per-objective-record hook uses this to report
## which member(s), if any, were lost at this objective. Optional (defaults
## to a throwaway Array) so the existing direct call in test_campaign_sim.gd
## (test_victory_xp_is_split_across_the_pre_death_roster_not_just_survivors())
## keeps working unchanged.
func _fight_objective(encounter_id: String, telemetry: Dictionary, party_losses_out: Array[String] = []) -> String:
	GameSession.enter_encounter(encounter_id)
	var expedition := GameSession.get_expedition(encounter_id)
	var scenario := _build_scenario(encounter_id, expedition)
	var errors := ScenarioContractScript.validate(scenario)
	if not errors.is_empty():
		push_error("[campaign_sim] invalid scenario for %s: %s" % [encounter_id, errors])
		GameSession.abandon_current_encounter()
		return "error"

	var battle_seed := ScenarioContractScript.derive_iteration_seed(sim_seed, encounter_id, telemetry.battles_fought)
	var controller: Node2D = BattleStateFactoryScript.build(scenario, battle_seed)

	# Boxed in a single-element array, not a plain float, because a GDScript
	# lambda captures an outer local variable BY VALUE (a snapshot at lambda-
	# creation time) -- mutating it inside the lambda would silently leave
	# the outer `kill_xp` read below always 0.0, never actually accumulating
	# any kill XP (found while verifying the Finding 1 fix: total_xp was
	# always exactly clear_xp, with every battle's kill XP silently dropped).
	# _wire_deterministic_rolls()'s own `minted := [0]` uses the identical
	# array-box idiom for the same reason.
	var kill_xp := [0.0]
	var on_enemy_defeated := func(unit) -> void: kill_xp[0] += float(unit.kill_xp)
	controller.enemy_defeated.connect(on_enemy_defeated)

	var outcome := _run_battle_to_resolution(controller, telemetry)

	telemetry.battles_fought += 1

	match outcome:
		"victory":
			# Mirrors battlefield.gd's real ordering exactly: kill XP accrues
			# progressively during the battle (via enemy_defeated above) and
			# clear XP is awarded in _apply_battle_outcome() -- both always
			# BEFORE _finish_victory()'s _persist_battle_aftermath() resolves
			# permadeath (see battlefield.gd:377-392,502-503). award_party_xp()
			# divides evenly across the party's CURRENT member_ids, so XP must
			# be awarded while any member who died this battle is still on
			# the roster, or survivors get an inflated per-capita share.
			telemetry.battles_won += 1
			var total_xp: float = float(kill_xp[0]) + float(expedition.get("clear_xp", 0))
			var leveled_up := GameSession.award_party_xp(GameSession.selected_party_id, total_xp)
			var dead_ids := _persist_battle_state(controller)
			telemetry.unit_deaths += dead_ids.size()
			party_losses_out.append_array(dead_ids)
			_resolve_pending_perks(leveled_up)
			GameSession.complete_current_encounter()
			GameSession.merge_battle_loot_into_party()
		"defeat":
			var dead_ids := _persist_battle_state(controller)
			telemetry.unit_deaths += dead_ids.size()
			party_losses_out.append_array(dead_ids)
			var lost: int = GameSession.gold + GameSession.pending_reward + GameSession.battle_reward
			GameSession.abandon_current_encounter()
			GameSession.resolve_party_wipe()
			telemetry.gold_lost_wipes += lost
			telemetry.party_wipes += 1
		_:
			var dead_ids := _persist_battle_state(controller)
			telemetry.unit_deaths += dead_ids.size()
			party_losses_out.append_array(dead_ids)
			telemetry.stalemates += 1
			GameSession.abandon_current_encounter()
			GameSession.discard_battle_loot()

	controller.free()
	return outcome


## Runs full player/enemy rounds (the same take_player_turn/end_turn/
## run_enemy_turn/end_turn cadence as test_battle_controller.gd's
## _run_to_resolution()) until one side is eliminated or MAX_BATTLE_ROUNDS is
## hit ("stalemate" -- the same third outcome battle_sim.gd already reports
## for a bot that cannot resolve a fight in time). Tallies telemetry.
## spell_casts from the "spell"-typed action records BattleBot.take_player_
## turn() returns for a Cleric (or any other spell-capable class) fielded
## this battle -- `telemetry` is optional, mirroring every other telemetry
## parameter in this file.
func _run_battle_to_resolution(controller: Node2D, telemetry: Dictionary = {}) -> String:
	var rounds := 0
	while rounds < MAX_BATTLE_ROUNDS:
		rounds += 1
		var player_steps: Array = BattleBotScript.take_player_turn(controller)
		if not telemetry.is_empty():
			for step in player_steps:
				if String(step.get("type", "")) == "spell":
					telemetry.spell_casts += 1
		controller.end_turn()
		if controller.is_battle_lost():
			return "defeat"
		controller.run_enemy_turn()
		controller.end_turn()
		if controller.is_battle_won():
			return "victory"
		if controller.is_battle_lost():
			return "defeat"
	return "stalemate"


## Shared aftermath persistence for every battle outcome (win, defeat, or
## stalemate/abandon alike) -- mirrors battlefield.gd's own _persist_battle_
## aftermath(): permadeath resolves before the health write-back so a unit
## whose reported health is <= 0 is removed from the roster rather than
## clamped to 1 HP, and a surviving caster's leftover MP writes back
## alongside health (see GameSession.apply_battle_mp_aftermath(), the MP
## twin of apply_battle_aftermath() below). Returns the ids permadeath
## removed this battle.
func _persist_battle_state(controller: Node2D) -> Array:
	var health_by_id := {}
	var mp_by_id := {}
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
			health_by_id[unit.adventurer_id] = unit.health
			if unit.mp_max > 0:
				mp_by_id[unit.adventurer_id] = unit.mp_remaining
	for adventurer_id in controller.defeated_player_health_by_id:
		health_by_id[adventurer_id] = controller.defeated_player_health_by_id[adventurer_id]
	var dead_ids := GameSession.resolve_battle_deaths(health_by_id)
	GameSession.apply_battle_aftermath(health_by_id)
	GameSession.apply_battle_mp_aftermath(mp_by_id)
	return dead_ids


## Resolves every pending perk slot (there can be more than one if a single
## XP award crossed more than one PERK_LEVEL_INTERVAL multiple) by picking
## the first still-available class-owned perk each time, same as battle_
## sim.gd's own _resolve_level_up().
func _resolve_pending_perks(leveled_up: Array) -> void:
	for adventurer_id in leveled_up:
		while GameSession.is_perk_choice_pending(adventurer_id):
			var available: Array[String] = GameSession.get_available_perks(adventurer_id)
			if available.is_empty():
				push_error("[campaign_sim] unresolvable perk choice for %s" % adventurer_id)
				break
			GameSession.choose_perk(adventurer_id, available[0])


func _return_to_encampment(telemetry: Dictionary) -> void:
	GameSession.return_deployed_party_to_settlement()
	var before: int = GameSession.gold
	GameSession.deposit_pending_reward()
	var delta := GameSession.gold - before
	if delta > 0:
		telemetry.gold_earned += delta


## --- ScenarioContract construction from live GameSession state -----------

## Builds the exact ScenarioContract JSON shape config/campaign_scenarios.json
## hand-authors per node (see that file and test_battle_state_factory.gd),
## except the player side reflects the simulator's actual current roster
## (level, equipped gear) rather than a fixed fixture.
func _build_scenario(encounter_id: String, expedition: Dictionary) -> Dictionary:
	var raw := {
		"scenario_id": "campaign_sim_%s" % encounter_id,
		"player": {"units": _build_player_units()},
		"enemy": {"units": _build_enemy_units(expedition)},
		"rules": {"round_limit": MAX_BATTLE_ROUNDS},
		"randomness": {"root_seed": sim_seed, "iterations": 1},
	}
	return ScenarioContractScript.normalize(raw)


func _build_player_units() -> Array:
	var units: Array = []
	for member_id in GameSession.get_selected_party().get("member_ids", []):
		var adventurer := GameSession.get_adventurer(member_id)
		if adventurer.is_empty() or not _is_fieldable(adventurer):
			continue
		var unit_spec := {
			"id": member_id,
			"template_id": String(adventurer.get("class", "warrior")),
			"weapon_id": String(adventurer.equipment.get("weapon", GameSession.DEFAULT_WEAPON_ID)),
			"armor_id": String(adventurer.equipment.get("armor", GameSession.DEFAULT_ARMOR_ID)),
			"level": int(adventurer.get("level", 1)),
		}
		# Durable MP (docs/designs/campaign-loop.md's "Cleric current MP is
		# durable adventurer state" paragraph): this simulator plays many
		# battles back to back off the same live roster, so a Cleric's MP
		# must carry over between them exactly like production battle start
		# does (see BattleController._ready()) -- not the scenario-contract
		# default of always-full, which would silently let every simulated
		# Cleric refill to 3 MP before every fight. get_effective_max_mp()
		# returns 0 for a non-caster, so this only ever sets the field for a
		# class that actually has one.
		if GameSession.get_effective_max_mp(member_id) > 0:
			unit_spec["mp_current"] = GameSession.get_current_mp(member_id)
		# Class-owned perks (docs/plans/2026-08-21-stage-2-party-readiness/
		# final-review fix wave's Fix 1): without this, every simulated battle
		# built through BattleStateFactory silently ignored Juggernaut/
		# Bulwark/Quickdraw/Devout even though _resolve_pending_perks() below
		# dutifully spends every perk slot a simulated party earns -- this
		# threads the party's real chosen perks into the scenario so campaign-
		# sim's balance evidence actually reflects them, mirroring mp_current's
		# identical durable-state-threading pattern just above.
		var chosen_perks: Array = adventurer.progression.get("perks", [])
		if not chosen_perks.is_empty():
			unit_spec["perks"] = chosen_perks.duplicate()
		units.append(unit_spec)
	return units


func _build_enemy_units(expedition: Dictionary) -> Array:
	var units: Array = []
	var index := 0
	if expedition.has("enemies"):
		for group in expedition.enemies:
			var stats: Dictionary = group.get("enemy", {})
			var template_id := _enemy_template_id(stats)
			for _i in int(group.get("count", 1)):
				units.append({"id": "enemy_%d" % index, "template_id": template_id})
				index += 1
	else:
		var stats: Dictionary = expedition.get("enemy", {})
		var template_id := _enemy_template_id(stats)
		for _i in int(stats.get("count", 1)):
			units.append({"id": "enemy_%d" % index, "template_id": template_id})
			index += 1
	return units


## Every GameSession *_ENEMY_STATS const's "name_key" follows the exact
## "battle.enemy.<template_id>" pattern ScenarioContract.KNOWN_ENEMY_
## TEMPLATES names are drawn from (verified for all twelve templates against
## game_session.gd) -- reversing it here is more robust than a hand-maintained
## name->id switch table that could silently drift from a new template.
func _enemy_template_id(stats: Dictionary) -> String:
	return String(stats.get("name_key", "")).trim_prefix("battle.enemy.")


## --- Deterministic entropy wiring -----------------------------------------

## Overrides every one of GameSession's injectable world-level rolls (loot
## amounts, enemy composition for non-authored expeditions, vacancy timers,
## recruitment class rolls, minted instance ids) with a seeded RNG so a
## whole campaign run is 100% reproducible from sim_seed alone -- the same
## injectable-Callable pattern GameSession's own tests already use, just
## wired to one shared seeded source instead of pinned constants. Battle-
## internal randomness (hit/crit/damage) is unaffected: BattleStateFactory.
## build() seeds those directly from the per-battle iteration seed (see
## _fight_objective()).
func _wire_deterministic_rolls(rng: RandomNumberGenerator) -> void:
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return rng.randf()
	GameSession.enemy_composition_roll = func(option_count: int) -> int: return rng.randi() % option_count
	GameSession.star_weight_roll = func(total_weight: int) -> int: return rng.randi() % total_weight
	GameSession.enemy_count_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)
	GameSession.vacancy_delay_roll = func(minimum: int, maximum: int) -> int: return rng.randi_range(minimum, maximum)
	GameSession.recruitment_class_roll = func() -> String: return "scout" if rng.randi() % 2 == 0 else "warrior"
	GameSession.cleric_offer_roll = func() -> bool: return rng.randf() < 0.25
	GameSession.skill_gain_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)
	# Intelligence & Guild Hall quests (Stage 5 Step 2, docs/designs/
	# intelligence.md) are deliberately NOT wired to this shared seeded
	# source: campaign_sim never calls accept_quest() or otherwise lets a
	# quest/intel outcome influence its own scripted decisions, so wiring
	# detection_roll/intel_tier_roll/quest_posting_roll here would only add
	# three unconsumed-by-the-sim RNG draws per relevant turn/instance --
	# shifting every *other* shared-stream roll's sequence downstream (loot,
	# enemy composition, vacancy timing, ...) and, in testing, broke the
	# Stage 3 seed-locked "party level at Ogre entry" balance band
	# (test_campaign_sim.gd) for no corresponding benefit. The dedicated
	# GameSession-level tests in test_game_session.gd already prove
	# detection/intel/quest determinism via direct injected-roll sequences,
	# satisfying decision-ledger.md's D1 deterministic-scenario requirement
	# without perturbing this shared stream. Both real play and campaign_sim
	# alike fall back to these three rolls' own real-random defaults.
	# Deterministic but collision-free: a per-run counter mixed with the
	# campaign seed, rather than reproducing production's GUID/time-fragment
	# format (which this simulator has no use for beyond uniqueness).
	var minted := [0]
	GameSession.instance_id_roll = func() -> String:
		minted[0] += 1
		return "sim-%d-%d" % [rng.seed, minted[0]]
