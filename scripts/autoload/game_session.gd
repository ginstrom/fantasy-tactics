extends Node

const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(0, 0)
const GOBLIN_CAMP_ID := "goblin_camp"
const ORC_OUTPOST_ID := "orc_outpost"
const EXPEDITIONS: Dictionary = {
	"goblin_camp": {
		"position": Vector2i(4, 4),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"reward": 10,
		# XP: 5 for a Goblin kill, 10 for clearing its site (see the campaign
		# progression design doc). BattleController/Battlefield read these
		# rather than hard-coding the values a second time.
		"kill_xp": 5,
		"clear_xp": 10,
		"enemy": {
			"name_key": "battle.enemy.goblin",
			"attack_name_key": "battle.enemy.goblin.attack",
			"max_health": 3,
			"attack_damage": 1,
			"hit_chance": 0.3,
		},
	},
	"orc_outpost": {
		"position": Vector2i(4, 0),
		"name_key": "expedition.orc_outpost.name",
		"danger_key": "expedition.danger.high",
		"reward": 25,
		# XP: 10 for an Orc kill, 20 for clearing its site.
		"kill_xp": 10,
		"clear_xp": 20,
		"enemy": {
			"name_key": "battle.enemy.orc",
			"attack_name_key": "battle.enemy.orc.attack",
			"max_health": 5,
			"attack_damage": 2,
			"hit_chance": 0.5,
		},
	},
}
# Progression domain constants (see docs/plans/2026-08-06-campaign-progression-and-population).
# Cumulative XP threshold for level N is 5*N*(N+1) - 10: level 1 costs 0, level
# 2 costs 20, level 3 costs 50, level 4 costs 90, each step costing 10 XP more
# than the previous one. See get_level_xp_threshold().
const BASE_ATTACK := 60
const BASE_MAX_HEALTH := 3
const BASE_MOVE_RANGE := 3
const LEVEL_UP_MAX_HEALTH_BONUS := 1
const LEVEL_UP_SKILL_POINTS := 10
const PERK_LEVEL_INTERVAL := 3
const BONUS_MOVE_PERK_ID := "bonus_move"
const EFFECTIVE_HIT_CHANCE_CAP := 0.95
const ATTACK_TO_HIT_CHANCE_DIVISOR := 100.0

# Vacancy-timed population (see docs/plans/2026-08-06-campaign-progression-and-population).
# A campaign starts sparse (one active encounter, one active recruitment
# offer) and refills each cleared/hired slot only after its own category's
# wait, and only while under that category's cap. See EXPEDITIONS/
# RECRUITMENT_CANDIDATE_TEMPLATES for the template pools these instances/
# offers are spawned from.
const ENCOUNTER_INSTANCE_CAP := 2
const RECRUITMENT_OFFER_CAP := 4
const ENCOUNTER_VACANCY_TURNS := 15
const RECRUITMENT_VACANCY_TURNS := 30
# Deterministic template cycling order for encounter refills. Must mirror
# EXPEDITIONS' keys exactly (order matters for repeatable tests/screenshots).
const ENCOUNTER_TEMPLATE_ORDER := ["goblin_camp", "orc_outpost"]
# Mirrors world_map.gd's GRID_WIDTH/GRID_HEIGHT. Duplicated here (rather than
# cross-referenced) because GameSession is an autoload with no dependency on
# the world scene script; keep both in sync if the map grid ever resizes.
const WORLD_GRID_WIDTH := 5
const WORLD_GRID_HEIGHT := 5

const WARRIOR_ID := "warrior_001"
const DEFAULT_WARRIOR := {
	"id": WARRIOR_ID,
	"name": "Warrior",
	"class": "warrior",
	"weapon": "sword",
	"level": 1,
	"availability_status": "available",
	# Authored base combat values; effective values (hit chance, max health,
	# move range) are derived from these plus progression by GameSession.
	"stats": {
		"max_health": BASE_MAX_HEALTH,
		"attack": BASE_ATTACK,
		"move_range": BASE_MOVE_RANGE,
	},
	# Durable leveling state. xp is a float so fractional party XP awards are
	# never truncated; display-facing rounding is a UI concern.
	"progression": {
		"xp": 0.0,
		"skill_points": 0,
		"perks": [],
	},
}
const FIRST_PARTY_ID := "party_001"
const DEFAULT_PLAYER_NAME := "Player"
# Fixed, individually identified recruitment offers (see the encampment
# roster/recruitment design). All three use existing Warrior behavior; the
# record shape is intentionally extensible for future candidates.
const RECRUITMENT_CANDIDATE_TEMPLATES: Array[Dictionary] = [
	{
		"id": "warrior_002",
		"name": "Warrior 2",
		"class": "warrior",
		"weapon": "sword",
		"level": 1,
		"availability_status": "available",
		"stats": {},
		"progression": {},
		"cost": 10,
	},
	{
		"id": "warrior_003",
		"name": "Warrior 3",
		"class": "warrior",
		"weapon": "sword",
		"level": 1,
		"availability_status": "available",
		"stats": {},
		"progression": {},
		"cost": 10,
	},
	{
		"id": "warrior_004",
		"name": "Warrior 4",
		"class": "warrior",
		"weapon": "sword",
		"level": 1,
		"availability_status": "available",
		"stats": {},
		"progression": {},
		"cost": 10,
	},
]

var adventurers: Array[Dictionary] = []
# Active recruitment OFFERS (not the template pool — see
# RECRUITMENT_CANDIDATE_TEMPLATES). A fresh campaign seeds exactly one
# (warrior_002); purchasing one starts a RECRUITMENT_VACANCY_TURNS clock that
# may add another later, capped at RECRUITMENT_OFFER_CAP.
var recruitment_candidates: Array[Dictionary] = []
# One pending clock per open recruitment vacancy: {"turns_remaining": int}.
var recruitment_vacancies: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var selected_party_id: String = ""
var selected_encounter: String = ""
var completed_encounters: Array[String] = []
# Active encounter INSTANCES (not the template pool — see EXPEDITIONS). Each
# instance is a spawned record: {id, template_id, position, ...copied
# template fields}. A fresh campaign seeds exactly one (the Goblin Camp, id
# "goblin_camp", at its documented position). Clearing one starts an
# ENCOUNTER_VACANCY_TURNS clock that may add another later, capped at
# ENCOUNTER_INSTANCE_CAP. A cleared instance is never reopened; it is only
# ever recorded (by its own id) in completed_encounters.
var active_encounters: Array[Dictionary] = []
# One pending clock per open encounter vacancy: {"turns_remaining": int}.
var encounter_vacancies: Array[Dictionary] = []
# Every template id ever spawned as an active instance (initial seed plus
# every refill), so a refill prefers a template variety has not yet shown the
# player before falling back to reusing one (see _choose_encounter_template).
# Recruitment offers do not need an equivalent: a purchased offer's id lives
# on in the roster forever, so _is_warrior_id_taken already answers "has this
# template been used" for that category.
var _used_encounter_template_ids: Array[String] = []
var world_turn: int = 1
var gold: int = 0
var pending_reward: int = 0
var player_name: String = DEFAULT_PLAYER_NAME


func _init() -> void:
	reset()


func start_new_game(new_player_name: String = DEFAULT_PLAYER_NAME) -> void:
	reset()
	player_name = new_player_name


func reset() -> void:
	# The roster owns a copy so a session cannot mutate the shared default data.
	adventurers = [DEFAULT_WARRIOR.duplicate(true)]
	recruitment_candidates = [RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)]
	recruitment_vacancies = []
	parties = []
	selected_party_id = ""
	selected_encounter = ""
	completed_encounters = []
	active_encounters = [
		_make_encounter_instance(GOBLIN_CAMP_ID, GOBLIN_CAMP_ID, EXPEDITIONS[GOBLIN_CAMP_ID].position)
	]
	encounter_vacancies = []
	_used_encounter_template_ids = [GOBLIN_CAMP_ID]
	world_turn = 1
	gold = 0
	pending_reward = 0
	player_name = DEFAULT_PLAYER_NAME


func create_party() -> bool:
	if not parties.is_empty():
		return false

	parties.append({
		"id": FIRST_PARTY_ID,
		"member_ids": [] as Array[String],
		"location_id": STARTING_SETTLEMENT_ID,
		"world_position": STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": false,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
		"name": "Party 1",
		# TBD: party-level progression data. Placeholder only.
		"progression": {},
		# TBD: free-form party metadata. Placeholder only.
		"metadata": {},
	})
	selected_party_id = FIRST_PARTY_ID
	return true


func get_selected_party() -> Dictionary:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return {}
	return parties[party_index]


func get_party(party_id: String) -> Dictionary:
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return {}
	return parties[party_index].duplicate(true)


func get_adventurer(adventurer_id: String) -> Dictionary:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return {}
	return adventurers[adventurer_index].duplicate(true)


func get_deployable_encamped_parties() -> Array[Dictionary]:
	var deployable: Array[Dictionary] = []
	for party in parties:
		if _is_party_eligible_for_deployment(party):
			deployable.append(party.duplicate(true))
	return deployable


## Every encamped party (settlement, not deployed), regardless of whether it
## has room or an available member — unlike get_deployable_encamped_parties(),
## a full-but-encamped party is still a valid unit-assignment target. Shares
## the encamped half of that same "ready" concept via _is_party_encamped so
## the two queries cannot silently drift apart.
func get_encamped_parties() -> Array[Dictionary]:
	var encamped: Array[Dictionary] = []
	for party in parties:
		if _is_party_encamped(party):
			encamped.append(party.duplicate(true))
	return encamped


func deploy_party(party_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if party_index == -1 or not _is_party_eligible_for_deployment(parties[party_index]):
		return false

	selected_party_id = party_id
	parties[party_index].deployed = true
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func get_available_adventurers() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for adventurer in adventurers:
		if is_adventurer_available(adventurer.id):
			available.append(adventurer)
	return available


func is_adventurer_available(adventurer_id: String) -> bool:
	var adventurer := get_adventurer(adventurer_id)
	return not adventurer.is_empty() and adventurer.availability_status == "available" and not _is_adventurer_assigned(adventurer_id)


func has_recruitment_candidate(candidate_id: String) -> bool:
	return _get_recruitment_candidate_index(candidate_id) != -1


func is_party_deployable(party_id: String) -> bool:
	var party := get_party(party_id)
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


## Rejects a target party that is not encamped (deployed, or outside the
## starting settlement) in addition to the existing unknown-party/unknown-
## adventurer/already-assigned checks — a party that is out in the field has
## nowhere to receive a new member.
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if (
		party_index == -1
		or not _is_party_encamped(parties[party_index])
		or not _has_adventurer(adventurer_id)
		or _is_adventurer_assigned(adventurer_id)
	):
		return false

	var member_ids: Array = parties[party_index].member_ids
	member_ids.append(adventurer_id)
	return true


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	return assign_adventurer_to_party(selected_party_id, adventurer_id)


## Debug-only convenience for populating the roster (see the debug menu).
## Mints a warrior_NNN id/name pair, scanning upward from adventurers.size() +
## 1 until it finds a number that collides with neither an existing
## adventurer nor a still-live recruitment candidate. RECRUITMENT_CANDIDATE_
## TEMPLATES fixes warrior_002/warrior_003/warrior_004 as separately tracked
## candidates, so a naive adventurers.size()-based count can otherwise mint
## an id one of them is still offering (or one an earlier debug recruit
## already used), silently corrupting the roster with duplicate ids.
## purchase_recruit() carries the matching guard for the other direction
## (buying a candidate whose id a debug recruit already claimed).
func recruit_adventurer() -> void:
	var recruit_number := adventurers.size() + 1
	var candidate_id := "warrior_%03d" % recruit_number
	while _is_warrior_id_taken(candidate_id):
		recruit_number += 1
		candidate_id = "warrior_%03d" % recruit_number

	var adventurer: Dictionary = DEFAULT_WARRIOR.duplicate(true)
	adventurer.id = candidate_id
	adventurer.name = "Warrior %d" % recruit_number
	adventurers.append(adventurer)


## Shared id-collision predicate for both the debug recruit-mint path above
## and the recruitment-offer overflow mint path (see
## _spawn_next_recruitment_offer). A "warrior_NNN" id is taken if it already
## names either a roster adventurer or a still-live recruitment offer.
func _is_warrior_id_taken(candidate_id: String) -> bool:
	return _has_adventurer(candidate_id) or _get_recruitment_candidate_index(candidate_id) != -1


func get_recruitment_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for candidate in recruitment_candidates:
		candidates.append(candidate.duplicate(true))
	return candidates


## The only normal (non-debug) path onto the roster: validates the candidate
## is still on offer, affordable, and not already claimed by an id-colliding
## adventurer (e.g. an earlier debug recruit — see recruit_adventurer()'s
## matching guard), deducts its cost exactly once, removes it from the
## catalog, and appends the purchased adventurer (its "cost" field dropped,
## since that is a recruitment-only concern).
func purchase_recruit(candidate_id: String) -> bool:
	var candidate_index := _get_recruitment_candidate_index(candidate_id)
	if (
		candidate_index == -1
		or gold < recruitment_candidates[candidate_index].cost
		or _has_adventurer(candidate_id)
	):
		return false

	var candidate: Dictionary = recruitment_candidates[candidate_index].duplicate(true)
	gold -= candidate.cost
	recruitment_candidates.remove_at(candidate_index)
	candidate.erase("cost")
	adventurers.append(candidate)
	_start_recruitment_vacancy()
	return true


func remove_adventurer_from_selected_party(adventurer_id: String) -> bool:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return false

	var member_ids: Array = parties[party_index].member_ids
	var member_index := member_ids.find(adventurer_id)
	if member_index == -1:
		return false

	member_ids.remove_at(member_index)
	return true


## Shares its eligibility rule with deploy_party()/get_deployable_encamped_parties()
## (see _is_party_eligible_for_deployment) so there is exactly one definition
## of "ready to depart" rather than two that can silently drift apart.
func can_depart_selected_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and _is_party_eligible_for_deployment(party)


func depart_selected_party() -> bool:
	if not can_depart_selected_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = true
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func has_deployed_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and party.deployed


func get_deployed_party_position() -> Vector2i:
	if not has_deployed_party():
		return STARTING_SETTLEMENT_WORLD_POSITION
	return get_selected_party().world_position


func set_deployed_party_position(position: Vector2i) -> bool:
	if not has_deployed_party():
		return false

	parties[_get_selected_party_index()].world_position = position
	return true


func get_deployed_party_route() -> Array[Vector2i]:
	if not has_deployed_party():
		return []
	return get_selected_party().travel_route


func set_deployed_party_route(route: Array[Vector2i]) -> bool:
	if not has_deployed_party() or route.is_empty():
		return false

	var previous: Vector2i = get_selected_party().world_position
	for step in route:
		if _grid_distance(previous, step) != 1:
			return false
		previous = step

	parties[_get_selected_party_index()].travel_route = route
	return true


func clear_deployed_party_route() -> void:
	if not has_deployed_party():
		return
	parties[_get_selected_party_index()].travel_route = [] as Array[Vector2i]


func take_next_route_step() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	var party: Dictionary = parties[party_index]
	if party.movement_spent or party.travel_route.is_empty():
		return false

	var route: Array = party.travel_route
	party.world_position = route[0]
	route.remove_at(0)
	party.movement_spent = true
	return true


func end_world_turn() -> bool:
	# A selected encounter is the durable marker for an unresolved battle. The
	# World Map may be opened to inspect it, but time cannot pass until the
	# player resumes and resolves (or loses) that battle.
	if selected_encounter != "":
		return false

	var auto_moved := false
	if has_deployed_party() and not get_selected_party().movement_spent:
		auto_moved = take_next_route_step()

	world_turn += 1
	if has_deployed_party():
		parties[_get_selected_party_index()].movement_spent = false
	_advance_encounter_vacancies()
	_advance_recruitment_vacancies()
	return auto_moved


func return_deployed_party_to_settlement() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = false
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	parties[party_index].travel_route = [] as Array[Vector2i]
	parties[party_index].movement_spent = false
	return true


func _get_selected_party_index() -> int:
	return _get_party_index(selected_party_id)


func _get_party_index(party_id: String) -> int:
	for party_index in parties.size():
		if parties[party_index].id == party_id:
			return party_index
	return -1


func _get_adventurer_index(adventurer_id: String) -> int:
	for adventurer_index in adventurers.size():
		if adventurers[adventurer_index].id == adventurer_id:
			return adventurer_index
	return -1


func _has_adventurer(adventurer_id: String) -> bool:
	return _get_adventurer_index(adventurer_id) != -1


func _get_recruitment_candidate_index(candidate_id: String) -> int:
	for candidate_index in recruitment_candidates.size():
		if recruitment_candidates[candidate_index].id == candidate_id:
			return candidate_index
	return -1


func _party_has_available_member(party: Dictionary) -> bool:
	for adventurer in adventurers:
		if adventurer.id in party.member_ids and adventurer.availability_status == "available":
			return true
	return false


func _is_party_eligible_for_deployment(party: Dictionary) -> bool:
	return _is_party_encamped(party) and _party_has_available_member(party)


## The shared "encamped" half of both deployment eligibility and unit
## assignment: in the starting settlement and not out in the field. Neither
## caller should duplicate this boolean expression on its own.
func _is_party_encamped(party: Dictionary) -> bool:
	return party.location_id == STARTING_SETTLEMENT_ID and not party.deployed


func _is_adventurer_assigned(adventurer_id: String) -> bool:
	for party in parties:
		if adventurer_id in party.member_ids:
			return true
	return false


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id


## Marks the current selection complete (once — a re-completion of an
## already-completed id is a no-op) and, only when it names a still-live
## active instance, removes that instance and opens an encounter vacancy.
## Ids that name a template directly rather than a live instance (e.g. the
## debug menu's raw battlefield shortcuts) still record history and queue
## their reward, but never touch active_encounters/encounter_vacancies since
## there was no real instance to clear.
func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
		pending_reward += expedition.get("reward", 0)
		_clear_active_encounter(selected_encounter)
	selected_encounter = ""


func abandon_current_encounter() -> void:
	selected_encounter = ""


func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	return deposited


func is_encounter_complete(encounter_id: String) -> bool:
	return completed_encounters.has(encounter_id)


## Resolves either a live active-encounter-instance id or a raw template id
## from EXPEDITIONS (checked in that order), returning a safe copy either
## way. The instance branch is what keeps World Map's normal flow working;
## the template branch is what keeps direct template-id callers (the debug
## menu's raw battlefield shortcuts, and get_expedition(GOBLIN_CAMP_ID/
## ORC_OUTPOST_ID) callers generally) working unchanged.
func get_expedition(encounter_id: String) -> Dictionary:
	var instance_index := _get_active_encounter_index(encounter_id)
	if instance_index != -1:
		return active_encounters[instance_index].duplicate(true)
	if not EXPEDITIONS.has(encounter_id):
		return {}
	return EXPEDITIONS[encounter_id].duplicate(true)


func get_active_encounters() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	for instance in active_encounters:
		instances.append(instance.duplicate(true))
	return instances


func _make_encounter_instance(instance_id: String, template_id: String, position: Vector2i) -> Dictionary:
	var instance: Dictionary = EXPEDITIONS[template_id].duplicate(true)
	instance["id"] = instance_id
	instance["template_id"] = template_id
	instance["position"] = position
	return instance


func _get_active_encounter_index(instance_id: String) -> int:
	for index in active_encounters.size():
		if active_encounters[index].id == instance_id:
			return index
	return -1


## No-ops for an id that does not name a live active instance (e.g. a raw
## template id entered via the debug menu) — see complete_current_encounter().
func _clear_active_encounter(instance_id: String) -> void:
	var index := _get_active_encounter_index(instance_id)
	if index == -1:
		return
	active_encounters.remove_at(index)
	_start_encounter_vacancy()


## Distinguishes "no new cooldown starts if already at capacity" (this guard,
## evaluated once at vacancy-open time) from "a clock exists but is capped
## from firing" (the symmetric guard inside _advance_encounter_vacancies).
func _start_encounter_vacancy() -> void:
	if active_encounters.size() >= ENCOUNTER_INSTANCE_CAP:
		return
	encounter_vacancies.append({"turns_remaining": ENCOUNTER_VACANCY_TURNS})


## Ticks every pending encounter vacancy clock down by one World Map turn. A
## clock that reaches zero fires exactly once: if the cap still has room it
## spawns a new instance; either way the clock is then discarded — a vacancy
## blocked by a full cap does not reschedule itself or catch up later.
func _advance_encounter_vacancies() -> void:
	var still_pending: Array[Dictionary] = []
	for vacancy in encounter_vacancies:
		vacancy.turns_remaining -= 1
		if vacancy.turns_remaining > 0:
			still_pending.append(vacancy)
			continue
		if active_encounters.size() < ENCOUNTER_INSTANCE_CAP:
			active_encounters.append(_spawn_next_encounter_instance())
	encounter_vacancies = still_pending


func _spawn_next_encounter_instance() -> Dictionary:
	var template_id := _choose_encounter_template()
	var position := _choose_encounter_position(template_id)
	if not _used_encounter_template_ids.has(template_id):
		_used_encounter_template_ids.append(template_id)
	return _make_encounter_instance(_mint_encounter_instance_id(), template_id, position)


## Deterministic and two-tiered: prefer the first template in
## ENCOUNTER_TEMPLATE_ORDER that is both not currently active AND has never
## been spawned before (so the player sees each known site at least once
## before any is reused). Once every known template has been seen at least
## once, fall back to the first merely-not-currently-active template (a
## previously seen template reused at a fresh instance, per design.md). Falls
## back to the first template outright if every known one is already active
## (cannot happen while ENCOUNTER_INSTANCE_CAP <= ENCOUNTER_TEMPLATE_ORDER.
## size(), but keeps this deterministic rather than failing outright if that
## ever changes).
func _choose_encounter_template() -> String:
	for template_id in ENCOUNTER_TEMPLATE_ORDER:
		if not _is_encounter_template_active(template_id) and not _used_encounter_template_ids.has(template_id):
			return template_id
	for template_id in ENCOUNTER_TEMPLATE_ORDER:
		if not _is_encounter_template_active(template_id):
			return template_id
	return ENCOUNTER_TEMPLATE_ORDER[0]


func _is_encounter_template_active(template_id: String) -> bool:
	for instance in active_encounters:
		if instance.template_id == template_id:
			return true
	return false


## Prefers the template's own documented position; only scans for another
## in-bounds, unoccupied, non-settlement tile (row-major) if that position is
## already occupied by another active instance.
func _choose_encounter_position(template_id: String) -> Vector2i:
	var documented_position: Vector2i = EXPEDITIONS[template_id].position
	if not _is_position_occupied(documented_position):
		return documented_position
	for y in WORLD_GRID_HEIGHT:
		for x in WORLD_GRID_WIDTH:
			var candidate := Vector2i(x, y)
			if candidate != STARTING_SETTLEMENT_WORLD_POSITION and not _is_position_occupied(candidate):
				return candidate
	return documented_position


func _is_position_occupied(position: Vector2i) -> bool:
	for instance in active_encounters:
		if instance.position == position:
			return true
	return false


## Mints an "encounter_NNN" id that collides with neither a currently-active
## instance nor a historically-completed one (completed_encounters), so a
## cleared site's old id is never reused by an unrelated later spawn.
func _mint_encounter_instance_id() -> String:
	var instance_number := 1
	var instance_id := "encounter_%03d" % instance_number
	while _get_active_encounter_index(instance_id) != -1 or completed_encounters.has(instance_id):
		instance_number += 1
		instance_id = "encounter_%03d" % instance_number
	return instance_id


## Mirrors _start_encounter_vacancy()/_advance_encounter_vacancies() for the
## recruitment category (see their docstrings for the capacity-guard split).
func _start_recruitment_vacancy() -> void:
	if recruitment_candidates.size() >= RECRUITMENT_OFFER_CAP:
		return
	recruitment_vacancies.append({"turns_remaining": RECRUITMENT_VACANCY_TURNS})


func _advance_recruitment_vacancies() -> void:
	var still_pending: Array[Dictionary] = []
	for vacancy in recruitment_vacancies:
		vacancy.turns_remaining -= 1
		if vacancy.turns_remaining > 0:
			still_pending.append(vacancy)
			continue
		if recruitment_candidates.size() < RECRUITMENT_OFFER_CAP:
			recruitment_candidates.append(_spawn_next_recruitment_offer())
	recruitment_vacancies = still_pending


## Deterministic: the first fixed template (in RECRUITMENT_CANDIDATE_TEMPLATES
## order) not already claimed by a live offer or a roster adventurer. Once
## every fixed template has been claimed, mints a fresh "warrior_NNN"
## candidate via the same collision-avoiding convention recruit_adventurer()
## uses, so a refill never silently fails once the small fixed pool is
## exhausted.
func _spawn_next_recruitment_offer() -> Dictionary:
	for template in RECRUITMENT_CANDIDATE_TEMPLATES:
		if not _is_warrior_id_taken(template.id):
			return template.duplicate(true)

	var overflow_number := adventurers.size() + recruitment_candidates.size() + 1
	var overflow_id := "warrior_%03d" % overflow_number
	while _is_warrior_id_taken(overflow_id):
		overflow_number += 1
		overflow_id = "warrior_%03d" % overflow_number

	var offer: Dictionary = RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)
	offer.id = overflow_id
	offer.name = "Warrior %d" % overflow_number
	return offer


## Divides amount evenly across party_id's members and adds each member's
## share to their stored (float) xp, applying as many level-ups as the new
## total crosses (see get_level_xp_threshold()). Silently ignores an unknown
## or memberless party. Returns the ids of members who gained at least one
## level from this award.
func award_party_xp(party_id: String, amount: float) -> Array[String]:
	var leveled_up: Array[String] = []
	var party_index := _get_party_index(party_id)
	if party_index == -1:
		return leveled_up

	var member_ids: Array = parties[party_index].member_ids
	if member_ids.is_empty():
		return leveled_up

	var share := amount / member_ids.size()
	for member_id in member_ids:
		if _award_adventurer_xp(member_id, share):
			leveled_up.append(member_id)
	return leveled_up


func _award_adventurer_xp(adventurer_id: String, amount: float) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = adventurers[adventurer_index]
	adventurer.progression.xp += amount

	var leveled_up := false
	while adventurer.progression.xp >= get_level_xp_threshold(adventurer.level + 1):
		adventurer.level += 1
		adventurer.stats.max_health += LEVEL_UP_MAX_HEALTH_BONUS
		adventurer.progression.skill_points += LEVEL_UP_SKILL_POINTS
		leveled_up = true
	return leveled_up


## The single source of truth for cumulative XP thresholds: level 1 costs 0,
## level 2 costs 20, level 3 costs 50, level 4 costs 90 — each level costing
## 10 XP more than the previous step. Equivalent to 5*level*(level+1) - 10.
func get_level_xp_threshold(level: int) -> float:
	return float(5 * level * (level + 1) - 10)


## True once an adventurer has reached a level divisible by PERK_LEVEL_INTERVAL
## for which no perk has been chosen yet. choose_perk() is the only way to
## resolve a pending choice.
func is_perk_choice_pending(adventurer_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	return _pending_perk_slot_count(adventurers[adventurer_index]) > 0


func _pending_perk_slot_count(adventurer: Dictionary) -> int:
	var earned_slots: int = adventurer.level / PERK_LEVEL_INTERVAL
	return earned_slots - adventurer.progression.perks.size()


## Rejects a non-positive amount, an amount greater than the adventurer's
## unspent skill points, or an unknown adventurer id, without mutating
## anything. Otherwise decrements skill_points by amount and adds amount to
## the adventurer's raw (uncapped) Attack.
func spend_attack_points(adventurer_id: String, amount: int) -> bool:
	if amount <= 0:
		return false

	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = adventurers[adventurer_index]
	if amount > adventurer.progression.skill_points:
		return false

	adventurer.progression.skill_points -= amount
	adventurer.stats.attack += amount
	return true


## Only accepts BONUS_MOVE_PERK_ID, only while is_perk_choice_pending() is
## true for adventurer_id, and only once per adventurer (a perk already in
## progression.perks cannot be re-chosen).
func choose_perk(adventurer_id: String, perk_id: String) -> bool:
	if perk_id != BONUS_MOVE_PERK_ID:
		return false

	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var adventurer: Dictionary = adventurers[adventurer_index]
	if adventurer.progression.perks.has(perk_id):
		return false
	if _pending_perk_slot_count(adventurer) <= 0:
		return false

	adventurer.progression.perks.append(perk_id)
	return true


## Centralized effective-hit-chance formula: min(raw Attack / 100.0, 0.95).
## Raw Attack itself is never capped (it feeds future defence/debuff math);
## only the chance derived from it is. Returns 0.0 for an unknown adventurer.
func get_effective_hit_chance(adventurer_id: String) -> float:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0.0
	return minf(adventurer.stats.attack / ATTACK_TO_HIT_CHANCE_DIVISOR, EFFECTIVE_HIT_CHANCE_CAP)


## Centralized effective max health: the adventurer's stored max_health,
## which leveling already keeps current. Returns 0 for an unknown adventurer.
func get_effective_max_health(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	return adventurer.stats.max_health


## Centralized effective move range: base move_range plus one extra tile if
## the bonus_move perk has been chosen. Returns 0 for an unknown adventurer.
func get_effective_move_range(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var bonus := 1 if adventurer.progression.perks.has(BONUS_MOVE_PERK_ID) else 0
	return adventurer.stats.move_range + bonus
