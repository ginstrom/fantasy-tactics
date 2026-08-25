extends RefCounted

## Stage 6 Step 5 domain service (docs/plans/2026-08-24-stage-6-content-and-
## domain-foundations/05-domain-extraction-and-stage-6-exit.md): pure party
## domain logic extracted verbatim out of game_session.gd -- party creation,
## capacity limits, member assignment, deployment, movement/route
## consumption, in-field carry equipping, and carry deposit/forfeiture.
##
## Owns NO state of its own. Every function here reads and writes GameSession's
## own durable fields (parties, adventurers, banked_gear, mana_crystals,
## owned_item_instances, banked_item_instance_ids, selected_party_id) through
## the `_gs` reference below -- there is no private/duplicated copy of any
## dictionary here, so there is nothing that can desync from what GameSession
## itself (or another service) reads/writes elsewhere. GameSession keeps a
## thin one-line forwarding method for every function moved here (the facade
## pattern this step's plan requires), so every existing internal self-call
## and every external `GameSession.foo(...)` call site (UI, World Map, battle,
## tools, tests) keeps working completely unchanged -- only what runs behind
## each name moved.
var _gs: Node


func _init(game_session: Node) -> void:
	_gs = game_session


## Mints the next sequential party id ("party_001", "party_002", ...).
func _new_party_id() -> String:
	return "party_%03d" % (_gs.parties.size() + 1)


## The canonical empty PartyCarry/BattleContext-reward shape (decision-ledger.md's
## PartyCarry contract).
func _empty_carry() -> Dictionary:
	return {
		"gold": 0,
		"gear": {} as Dictionary,
		"mana_crystals": {} as Dictionary,
		"item_instance_ids": [] as Array[String],
	}


func create_party(party_name: String = "Party 1") -> bool:
	if _gs.parties.size() >= _gs.get_max_party_count():
		return false

	var party_id := _new_party_id()
	_gs.parties.append({
		"id": party_id,
		"member_ids": [] as Array[String],
		"location_id": _gs.STARTING_SETTLEMENT_ID,
		"world_position": _gs.STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": false,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
		"name": party_name,
		# TBD: party-level progression data. Placeholder only.
		"progression": {},
		# TBD: free-form party metadata. Placeholder only.
		"metadata": {},
		# PartyCarry (Stage 6 Step 2, decision-ledger.md): everything this
		# party has picked up in the field but not yet banked at the
		# Encampment.
		"carry": _empty_carry(),
	})
	_gs.selected_party_id = party_id
	return true


## Switches which party the World Map (and every other "selected party"
## reader) treats as "the" party, without deploying, moving, or otherwise
## mutating anything. False (no change) for an unknown party id.
func select_party(party_id: String) -> bool:
	if _get_party_index(party_id) == -1:
		return false
	_gs.selected_party_id = party_id
	return true


func get_selected_party() -> Dictionary:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return {}
	return _gs.parties[party_index]


func get_party(party_id: String) -> Dictionary:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return {}
	return _gs.parties[party_index].duplicate(true)


func get_deployable_encamped_parties() -> Array[Dictionary]:
	var deployable: Array[Dictionary] = []
	for party in _gs.parties:
		if _is_party_eligible_for_deployment(party):
			deployable.append(party.duplicate(true))
	return deployable


## Every encamped party (settlement, not deployed), regardless of whether it
## has room or an available member.
func get_encamped_parties() -> Array[Dictionary]:
	var encamped: Array[Dictionary] = []
	for party in _gs.parties:
		if _is_party_encamped(party):
			encamped.append(party.duplicate(true))
	return encamped


## Every currently deployed party (out in the field), regardless of
## eligibility for anything else.
func get_deployed_parties() -> Array[Dictionary]:
	var deployed: Array[Dictionary] = []
	for party in _gs.parties:
		if bool(party.get("deployed", false)):
			deployed.append(party.duplicate(true))
	return deployed


func deploy_party(party_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1 or not _is_party_eligible_for_deployment(_gs.parties[party_index]):
		return false

	_gs.selected_party_id = party_id
	_gs.parties[party_index].deployed = true
	_gs.parties[party_index].location_id = _gs.STARTING_SETTLEMENT_ID
	_gs.parties[party_index].world_position = _gs.STARTING_SETTLEMENT_WORLD_POSITION
	return true


func is_party_deployable(party_id: String) -> bool:
	var party := get_party(party_id)
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


## Rejects a target party that is not encamped (deployed, or outside the
## starting settlement) in addition to the existing unknown-party/unknown-
## adventurer/already-assigned checks -- a party that is out in the field has
## nowhere to receive a new member. Also rejects if the party is at its size cap.
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if (
		party_index == -1
		or not _is_party_encamped(_gs.parties[party_index])
		or not _gs._has_adventurer(adventurer_id)
		or _gs._is_adventurer_assigned(adventurer_id)
		or _gs.parties[party_index].member_ids.size() >= get_max_party_size()
	):
		return false

	var member_ids: Array = _gs.parties[party_index].member_ids
	member_ids.append(adventurer_id)
	return true


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	return assign_adventurer_to_party(_gs.selected_party_id, adventurer_id)


func remove_adventurer_from_selected_party(adventurer_id: String) -> bool:
	return remove_adventurer_from_party(_gs.selected_party_id, adventurer_id)


func remove_adventurer_from_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1 or not _is_party_encamped(_gs.parties[party_index]):
		return false

	var member_ids: Array = _gs.parties[party_index].member_ids
	var member_index := member_ids.find(adventurer_id)
	if member_index == -1:
		return false

	member_ids.remove_at(member_index)
	return true


## Shares its eligibility rule with deploy_party()/get_deployable_encamped_parties()
## so there is exactly one definition of "ready to depart" rather than two
## that can silently drift apart.
func can_depart_selected_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


func depart_selected_party() -> bool:
	if not can_depart_selected_party():
		return false

	var party_index := _get_selected_party_index()
	_gs.parties[party_index].deployed = true
	_gs.parties[party_index].location_id = _gs.STARTING_SETTLEMENT_ID
	_gs.parties[party_index].world_position = _gs.STARTING_SETTLEMENT_WORLD_POSITION
	return true


## Resolves an explicit-or-defaulted party id: every travel/position/route
## function below takes an optional party_id, defaulting to "" which resolves
## to selected_party_id.
func _resolve_party_id(party_id: String) -> String:
	return party_id if party_id != "" else _gs.selected_party_id


func has_deployed_party(party_id: String = "") -> bool:
	var party := get_party(_resolve_party_id(party_id))
	return not party.is_empty() and party.deployed


func get_deployed_party_position(party_id: String = "") -> Vector2i:
	if not has_deployed_party(party_id):
		return _gs.STARTING_SETTLEMENT_WORLD_POSITION
	return get_party(_resolve_party_id(party_id)).world_position


func set_deployed_party_position(position: Vector2i, party_id: String = "") -> bool:
	if not has_deployed_party(party_id):
		return false

	_gs.parties[_get_party_index(_resolve_party_id(party_id))].world_position = position
	return true


func get_deployed_party_route(party_id: String = "") -> Array[Vector2i]:
	if not has_deployed_party(party_id):
		return []
	return get_party(_resolve_party_id(party_id)).travel_route


func set_deployed_party_route(route: Array[Vector2i], party_id: String = "") -> bool:
	if not has_deployed_party(party_id) or route.is_empty():
		return false

	var resolved_id := _resolve_party_id(party_id)
	var previous: Vector2i = get_party(resolved_id).world_position
	for step in route:
		if _gs._grid_distance(previous, step) != 1:
			return false
		previous = step

	_gs.parties[_get_party_index(resolved_id)].travel_route = route
	return true


func clear_deployed_party_route(party_id: String = "") -> void:
	if not has_deployed_party(party_id):
		return
	_gs.parties[_get_party_index(_resolve_party_id(party_id))].travel_route = [] as Array[Vector2i]


func take_next_route_step(party_id: String = "") -> bool:
	if not has_deployed_party(party_id):
		return false

	var party_index := _get_party_index(_resolve_party_id(party_id))
	var party: Dictionary = _gs.parties[party_index]
	if party.movement_spent or party.travel_route.is_empty():
		return false

	var route: Array = party.travel_route
	party.world_position = route[0]
	route.remove_at(0)
	party.movement_spent = true
	return true


func return_deployed_party_to_settlement(party_id: String = "") -> bool:
	if not has_deployed_party(party_id):
		return false

	var party_index := _get_party_index(_resolve_party_id(party_id))
	_gs.parties[party_index].deployed = false
	_gs.parties[party_index].location_id = _gs.STARTING_SETTLEMENT_ID
	_gs.parties[party_index].world_position = _gs.STARTING_SETTLEMENT_WORLD_POSITION
	_gs.parties[party_index].travel_route = [] as Array[Vector2i]
	_gs.parties[party_index].movement_spent = false
	return true


func _get_selected_party_index() -> int:
	return _get_party_index(_gs.selected_party_id)


func _get_party_index(party_id: String) -> int:
	for party_index in _gs.parties.size():
		if _gs.parties[party_index].id == party_id:
			return party_index
	return -1


func _party_has_available_member(party: Dictionary) -> bool:
	for adventurer in _gs.adventurers:
		if adventurer.id in party.member_ids and adventurer.availability_status == "available":
			return true
	return false


func _is_party_eligible_for_deployment(party: Dictionary) -> bool:
	return _is_party_encamped(party) and _party_has_available_member(party)


## The shared "encamped" half of both deployment eligibility and unit
## assignment: in the starting settlement and not out in the field. Neither
## caller should duplicate this boolean expression on its own.
func _is_party_encamped(party: Dictionary) -> bool:
	return party.location_id == _gs.STARTING_SETTLEMENT_ID and not party.deployed


## Maximum number of parties a campaign may have at once (Stage 5 D5,
## decision-ledger.md): 1 below Guild Hall level GUILD_HALL_MAX_LEVEL (today's
## behavior, unchanged), 2 once it reaches that top tier.
func get_max_party_count() -> int:
	return 2 if _gs.guild_hall_level >= _gs.GUILD_HALL_MAX_LEVEL else 1


func get_max_party_size() -> int:
	if _gs.guild_hall_level >= 3:
		return _gs.GUILD_HALL_LEVEL_3_PARTY_CAP
	if _gs.guild_hall_level >= 2:
		return _gs.GUILD_HALL_LEVEL_2_PARTY_CAP
	return _gs.GUILD_HALL_LEVEL_1_PARTY_CAP


## party_id's own carry (decision-ledger.md's PartyCarry contract): everything
## it has picked up in the field but not yet banked at the Encampment. An
## unknown party_id returns an empty carry rather than erroring, matching
## get_party()'s own "unknown id" convention.
func get_party_carry(party_id: String) -> Dictionary:
	var party := get_party(party_id)
	if party.is_empty():
		return _empty_carry()
	return (party.get("carry", _empty_carry()) as Dictionary).duplicate(true)


## Merges party_id's own carry into the Encampment's shared bank (gold,
## banked_gear, mana_crystals, banked_item_instance_ids) and clears that
## party's carry back to empty. A no-op (returns an empty carry, no state
## change) for an unknown party_id. Returns a duplicate of the carry that was
## just deposited, for callers that want to report what was banked.
func deposit_party_carry(party_id: String) -> Dictionary:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return _empty_carry()
	var carry: Dictionary = _gs.parties[party_index].get("carry", _empty_carry())
	var deposited: Dictionary = carry.duplicate(true)
	_gs.gold += int(carry.get("gold", 0))
	for item_id in carry.get("gear", {}):
		var count: int = int(carry.gear[item_id])
		if count > 0:
			_gs.banked_gear[item_id] = _gs.banked_gear.get(item_id, 0) + count
	for raw_instance_id in carry.get("item_instance_ids", []):
		var instance_id := str(raw_instance_id)
		if not _gs.banked_item_instance_ids.has(instance_id):
			_gs.banked_item_instance_ids.append(instance_id)
	_gs._merge_counts(carry.get("mana_crystals", {}), _gs.mana_crystals)
	_gs.parties[party_index]["carry"] = _empty_carry()
	return deposited


## Party-wipe forfeiture (docs/designs/campaign-loop.md's loss rule, narrowed
## to per-party scope by Stage 6 Step 2's PartyCarry split): party_id's own
## carry is lost outright, without touching any other party's carry or
## anything already banked at the Encampment. A forfeited item instance's own
## owned_item_instances record is erased too. A no-op for an unknown party_id.
func forfeit_party_carry(party_id: String) -> void:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return
	var carry: Dictionary = _gs.parties[party_index].get("carry", _empty_carry())
	for raw_instance_id in carry.get("item_instance_ids", []):
		_gs.owned_item_instances.erase(str(raw_instance_id))
	_gs.parties[party_index]["carry"] = _empty_carry()


## Requires item_id to currently be in party_id's own carry -- everything that
## party has picked up but not yet carried home and banked. Handles both a
## fungible stackable item id (carry.gear) and a unique owned-item instance id
## recovered from a slain party member (carry.item_instance_ids, see
## transfer_dead_unit_gear_to_party_carry()) -- an unknown party_id fails
## safely (mutates nothing) rather than erroring.
func equip_item_from_party_carry(party_id: String, adventurer_id: String, item_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return false
	var carry: Dictionary = _gs.parties[party_index].carry
	if _gs.owned_item_instances.has(item_id):
		return _gs._equip_item_instance_from(carry.item_instance_ids, adventurer_id, item_id)
	return _gs._equip_item_from(carry.gear, adventurer_id, item_id)


## Moves every item a slain adventurer carried -- weapons, armor, and
## potions, active or spare alike -- into party_id's own carry: an ordinary
## stackable item id into carry.gear (one count per id) and a unique owned-
## item instance id into carry.item_instance_ids instead, preserving its
## one-of-a-kind modifier record rather than folding it into a fungible
## count. A no-op for an unknown party_id.
func transfer_dead_unit_gear_to_party_carry(party_id: String, unit_id: String) -> void:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return
	var adventurer: Dictionary = _gs.get_adventurer(unit_id)
	var equipment: Dictionary = adventurer.get("equipment", {})
	var carry: Dictionary = _gs.parties[party_index].carry
	for slot in ["weapon", "armor", "potion"]:
		for item_id in equipment.get("%s_inventory" % slot, []):
			var id := str(item_id)
			if _gs.owned_item_instances.has(id):
				if not carry.item_instance_ids.has(id):
					carry.item_instance_ids.append(id)
			else:
				carry.gear[id] = carry.gear.get(id, 0) + 1
