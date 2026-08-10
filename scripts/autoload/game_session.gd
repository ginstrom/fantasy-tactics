extends Node

const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(3, 3)
const GOBLIN_CAMP_ID := "goblin_camp"
const ORC_OUTPOST_ID := "orc_outpost"
const RUINED_FORTRESS_ID := "ruined_fortress"

# First-campaign guide message ids (see get_campaign_guide_state() near the
# bottom of this file and docs/plans/2026-08-10-initial-campaign-and-
# automation/04-first-campaign-guidance.md). Order matters: it's the
# priority scan order get_campaign_guide_state() walks.
const CAMPAIGN_GUIDE_FORM_PARTY := "form_party"
const CAMPAIGN_GUIDE_DEPLOY := "deploy"
const CAMPAIGN_GUIDE_SELECT_ROUTE := "select_route"
const CAMPAIGN_GUIDE_ENTER_SITE := "enter_site"
const CAMPAIGN_GUIDE_RETURN_BANK := "return_bank"
const CAMPAIGN_GUIDE_FIRST_IMPROVEMENT := "first_improvement"
const CAMPAIGN_GUIDE_SEQUENCE: Array[String] = [
	CAMPAIGN_GUIDE_FORM_PARTY,
	CAMPAIGN_GUIDE_DEPLOY,
	CAMPAIGN_GUIDE_SELECT_ROUTE,
	CAMPAIGN_GUIDE_ENTER_SITE,
	CAMPAIGN_GUIDE_RETURN_BANK,
	CAMPAIGN_GUIDE_FIRST_IMPROVEMENT,
]

const EXPEDITIONS: Dictionary = {
	"goblin_camp": {
		"position": Vector2i(4, 4),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		# Clear XP: 10 for clearing its site (see the campaign progression
		# design doc). Kill XP now lives on each enemy's own *_ENEMY_STATS
		# const instead — see GOBLIN_ENEMY_STATS.kill_xp.
		"clear_xp": 10,
		"enemy": {
			"name_key": "battle.enemy.goblin",
			"attack_name_key": "battle.enemy.goblin.attack",
			"max_health": 13,
			"attack_damage": 2,
			"hit_chance": 0.3,
			"count": 1,
		},
	},
	"orc_outpost": {
		"position": Vector2i(4, 0),
		"name_key": "expedition.orc_outpost.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 2,
		# Clear XP: 20 for clearing its site. Kill XP lives on
		# GOBLIN_ENEMY_STATS/ORC_ENEMY_STATS depending on which composition
		# resolves.
		"clear_xp": 20,
		"enemy": {
			"name_key": "battle.enemy.orc",
			"attack_name_key": "battle.enemy.orc.attack",
			"max_health": 22,
			"attack_damage": 3,
			"hit_chance": 0.5,
			"count": 1,
		},
	},
	"ruined_fortress": {
		"position": Vector2i(0, 4),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.extreme",
		"difficulty": 3,
		# Clear XP: 30 for clearing the site. Kill XP lives on each
		# composition option's own enemy stats — see the reward table in
		# docs/plans/2026-08-08-monster-tiers-and-weighted-encounters/08-per-monster-kill-xp.md.
		"clear_xp": 30,
		"enemy": {
			"name_key": "battle.enemy.kobold",
			"attack_name_key": "battle.enemy.kobold.attack",
			"max_health": 6,
			"attack_damage": 1,
			"hit_chance": 0.25,
			"count": 4,
		},
	},
}
const GOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.goblin",
	"attack_name_key": "battle.enemy.goblin.attack",
	"max_health": 13,
	"attack_damage": 2,
	"hit_chance": 0.3,
	"kill_xp": 5,
	"loot_id": "goblin",
}
const ORC_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.orc",
	"attack_name_key": "battle.enemy.orc.attack",
	"max_health": 22,
	"attack_damage": 3,
	"hit_chance": 0.5,
	"kill_xp": 10,
	"loot_id": "orc",
}
const KOBOLD_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.kobold",
	"attack_name_key": "battle.enemy.kobold.attack",
	"max_health": 6,
	"attack_damage": 1,
	"hit_chance": 0.25,
	"kill_xp": 3,
	"loot_id": "kobold",
}
const HOBGOBLIN_ENEMY_STATS: Dictionary = {
	"name_key": "battle.enemy.hobgoblin",
	"attack_name_key": "battle.enemy.hobgoblin.attack",
	"max_health": 30,
	"attack_damage": 4,
	"hit_chance": 0.6,
	"kill_xp": 20,
	"loot_id": "hobgoblin",
}
# Star tier -> possible enemy compositions for an active instance at that
# tier (see docs/plans/campaign-loop-follow-up.md's battle balancing
# section). Tier 1 has one option, tier 2 has two, and tier 3 has four;
# whenever a tier has more than one option, entering an instance at that
# tier randomly resolves to one of them (see
# enemy_composition_roll/_resolve_enemy_composition/enter_encounter) so
# three orcs can no longer gang up on a level-1 party. Ordering within each
# tier's option list follows the design doc's phrasing for that tier: tiers
# 1-2 are Goblin-first, while tier 3 is Kobold-first, ascending danger.
const STAR_ENEMY_COMPOSITIONS: Dictionary = {
	1: [
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 1},
	],
	2: [
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 2, "count_max": 2},
		{"enemy": ORC_ENEMY_STATS, "count_min": 1, "count_max": 1},
	],
	3: [
		{"enemy": KOBOLD_ENEMY_STATS, "count_min": 4, "count_max": 8},
		{"enemy": GOBLIN_ENEMY_STATS, "count_min": 3, "count_max": 6},
		{"enemy": ORC_ENEMY_STATS, "count_min": 2, "count_max": 4},
		{"enemy": HOBGOBLIN_ENEMY_STATS, "count_min": 1, "count_max": 3},
	],
}
## Star-tier selection weight for a refill candidate at a given player
## power (see docs/plans/first-playable-campaign/game-design.md's
## "Vacancy-timed encounter and recruitment population" section for the
## worked example table). Floors at STAR_WEIGHT_MIN so no tier's odds
## ever reach exactly zero.
const STAR_WEIGHT_BASE: Dictionary = {1: 6, 2: 2, 3: -2}
const STAR_WEIGHT_PER_POWER: Dictionary = {1: -1, 2: 1, 3: 1}
const STAR_WEIGHT_MIN: int = 1
# Equipment catalog (see "Trade, equipment, and loot" in
# docs/plans/first-playable-campaign/game-design.md). Steel is
# +1 damage over Iron on both ends of the range. Armor's defense reduces an
# attacker's effective hit chance; resistance reduces incoming damage by that
# percent, rounded to the nearest integer when applied (see BattleController).
const WEAPONS: Dictionary = {
	"dagger_iron": {"name_key": "item.dagger_iron", "slot": "weapon", "damage_min": 1, "damage_max": 4, "price": 10},
	"dagger_steel": {"name_key": "item.dagger_steel", "slot": "weapon", "damage_min": 2, "damage_max": 5, "price": 30},
	"shortsword_iron": {"name_key": "item.shortsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 6, "price": 20},
	"shortsword_steel": {"name_key": "item.shortsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 7, "price": 60},
	"longsword_iron": {"name_key": "item.longsword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 8, "price": 30},
	"longsword_steel": {"name_key": "item.longsword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 9, "price": 90},
	"two_handed_sword_iron": {"name_key": "item.two_handed_sword_iron", "slot": "weapon", "damage_min": 1, "damage_max": 10, "price": 35},
	"two_handed_sword_steel": {"name_key": "item.two_handed_sword_steel", "slot": "weapon", "damage_min": 2, "damage_max": 11, "price": 105},
}
const ARMORS: Dictionary = {
	"leather_armor": {"name_key": "item.leather_armor", "slot": "armor", "defense": 10, "resistance": 10, "price": 10},
	"chainmail_armor": {"name_key": "item.chainmail_armor", "slot": "armor", "defense": 15, "resistance": 20, "price": 30},
	"split_armor": {"name_key": "item.split_armor", "slot": "armor", "defense": 15, "resistance": 25, "price": 50},
	"platemail_armor": {"name_key": "item.platemail_armor", "slot": "armor", "defense": 15, "resistance": 30, "price": 200},
	"full_plate_armor": {"name_key": "item.full_plate_armor", "slot": "armor", "defense": 15, "resistance": 35, "price": 500},
}
# Loot tables (see "Trade, equipment, and loot" in
# docs/plans/first-playable-campaign/game-design.md). Gold per kill is
# randi_range(gold_min, gold_max) * gold_multiplier. gear_item_id is always
# the enemy's documented Iron-tier weapon (see WEAPONS above); it drops with
# GEAR_DROP_CHANCE probability, independent of the (always-granted) mana
# crystal. Kobold and hobgoblin are both fightable via the Ruined Fortress
# (see STAR_ENEMY_COMPOSITIONS[3]), so their rows resolve for real loot
# whenever either is killed there, same as goblin/orc elsewhere.
const ENEMY_LOOT_TABLES: Dictionary = {
	"kobold": {"gold_min": 0, "gold_max": 5, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "dagger_iron"},
	"goblin": {"gold_min": 1, "gold_max": 6, "gold_multiplier": 1, "mana_crystal_tier": 1, "gear_item_id": "shortsword_iron"},
	"orc": {"gold_min": 1, "gold_max": 5, "gold_multiplier": 2, "mana_crystal_tier": 2, "gear_item_id": "longsword_iron"},
	"hobgoblin": {"gold_min": 1, "gold_max": 4, "gold_multiplier": 3, "mana_crystal_tier": 2, "gear_item_id": "two_handed_sword_iron"},
}
const MANA_CRYSTAL_VALUES: Dictionary = {1: 5, 2: 15}
const GEAR_DROP_CHANCE := 0.25
const DEFAULT_WEAPON_ID := "longsword_iron"
const DEFAULT_ARMOR_ID := "leather_armor"
# Progression domain constants (see docs/plans/2026-08-06-campaign-progression-and-population).
# Cumulative XP threshold for level N is 5*N*(N+1) - 10: level 1 costs 0, level
# 2 costs 20, level 3 costs 50, level 4 costs 90, each step costing 10 XP more
# than the previous one. See get_level_xp_threshold().
# Balance values below default to GameConfig's own DEFAULTS and are
# overwritten from config/game_config.json in _ready() (see
# docs/plans/2026-08-07-config-and-automation). They stay UPPER_SNAKE_CASE
# vars, not real consts, specifically so every existing
# GameSession.SOME_CONSTANT call site keeps working unchanged — GDScript
# exposes both consts and vars the same way through a singleton instance.
var BASE_ATTACK: int = 60
var BASE_MAX_HEALTH: int = 10
var BASE_MOVE_RANGE: int = 3
var LEVEL_UP_MAX_HEALTH_BONUS: int = 10
var LEVEL_UP_SKILL_POINTS: int = 10
var PERK_LEVEL_INTERVAL: int = 3
const BONUS_MOVE_PERK_ID := "bonus_move"
var GUILD_HALL_LEVEL_1_PARTY_CAP: int = 4
var GUILD_HALL_LEVEL_2_PARTY_CAP: int = 5
var GUILD_HALL_UPGRADE_COST: int = 50
var GUILD_HALL_MAX_LEVEL: int = 2
var TRADING_POST_PURCHASE_COST: int = 50
var TRADING_POST_INCOME_PER_TURN: int = 1
var EFFECTIVE_HIT_CHANCE_CAP: float = 0.95
var ATTACK_TO_HIT_CHANCE_DIVISOR: float = 100.0

# Vacancy-timed population (see docs/plans/2026-08-06-campaign-progression-and-population).
# A campaign starts sparse (two active encounters, one active recruitment
# offer) and refills each cleared/hired slot only after its own category's
# wait, and only while under that category's cap. See EXPEDITIONS/
# RECRUITMENT_CANDIDATE_TEMPLATES for the template pools these instances/
# offers are spawned from.
var ENCOUNTER_INSTANCE_CAP: int = 2
var RECRUITMENT_OFFER_CAP: int = 4
var ENCOUNTER_VACANCY_TURNS: int = 15
var RECRUITMENT_VACANCY_TURNS: int = 30
var ENCOUNTER_VACANCY_JITTER_TURNS: int = 5
var RECRUITMENT_VACANCY_JITTER_TURNS: int = 5
# The pool of candidate templates a refill's power-weighted picker chooses
# among (see _choose_encounter_template()) -- order no longer determines
# which template gets picked, only which is enumerated first when weights
# tie. Must mirror EXPEDITIONS' keys exactly.
const ENCOUNTER_TEMPLATE_ORDER := ["goblin_camp", "orc_outpost", "ruined_fortress"]
# Mirrors world_map.gd's GRID_WIDTH/GRID_HEIGHT. Duplicated here (rather than
# cross-referenced) because GameSession is an autoload with no dependency on
# the world scene script; keep both in sync if the map grid ever resizes.
const WORLD_GRID_WIDTH := 7
const WORLD_GRID_HEIGHT := 7

const WARRIOR_ID := "warrior_001"


func get_default_warrior() -> Dictionary:
	return {
		"id": WARRIOR_ID,
		"name": "Warrior",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
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
# A pool of recruitment templates that vacancy-timed refills draw from (see
# _spawn_next_recruitment_offer): the initial offer and every later refill
# claims the next not-yet-offered template here before falling back to
# minting an overflow "warrior_NNN" candidate. Templates intentionally omit
# stats/progression — every current template matches the Warrior baseline, so
# purchase_recruit() and _spawn_next_recruitment_offer() both seed real
# stats/progression from DEFAULT_WARRIOR (see
# _seed_adventurer_baseline_stats) rather than storing (and risking stale)
# copies here.
const RECRUITMENT_CANDIDATE_TEMPLATES: Array[Dictionary] = [
	{
		"id": "warrior_002",
		"name": "Warrior 2",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
	{
		"id": "warrior_003",
		"name": "Warrior 3",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
		"cost": 10,
	},
	{
		"id": "warrior_004",
		"name": "Warrior 4",
		"class": "warrior",
		"equipment": {
			"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
			"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID],
		},
		"level": 1,
		"availability_status": "available",
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
# Injectable so tests can force a specific composition (see hit_roll on
# BattleController for the same pattern) instead of depending on real
# randomness. Never reset by reset() — every call site that needs a specific
# outcome sets this immediately before its own enter_encounter() call.
var enemy_composition_roll: Callable = func(option_count: int) -> int: return randi() % option_count
## Injectable so tests can force a specific weighted-tier outcome instead
## of depending on real randomness (see enemy_composition_roll for the
## same pattern). Takes the candidates' total weight and returns a value
## in [0, total_weight) -- _choose_encounter_template() maps it onto each
## candidate's weight bucket via a cumulative sum.
var star_weight_roll: Callable = func(total_weight: int) -> int: return randi() % total_weight
## Injectable so tests can force a specific enemy count instead of
## depending on real randomness (see enemy_composition_roll for the same
## pattern). Called with the resolved composition option's
## (count_min, count_max).
var enemy_count_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
## Injectable so tests can force a specific vacancy delay instead of
## depending on real randomness (see enemy_composition_roll for the same
## pattern). Called by _resolve_vacancy_delay() with an inclusive
## [minimum, maximum] jitter range and expected to return a value in that
## range once per newly opened vacancy.
var vacancy_delay_roll: Callable = func(minimum: int, maximum: int) -> int: return randi_range(minimum, maximum)


## Restores enemy_composition_roll, enemy_count_roll, star_weight_roll, and
## vacancy_delay_roll to their real-random default implementations.
## Deliberately NOT called by reset() -- these Callables are intentionally
## never touched by reset() (see each var's own doc comment) so a test can
## pin one, then call reset() for unrelated setup, without losing its pin.
## Call sites that need a guaranteed clean slate (a fresh debug scenario, a
## test's after_each) call this explicitly instead.
func reset_injectable_rolls() -> void:
	enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
	enemy_count_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	star_weight_roll = func(total_weight: int) -> int: return randi() % total_weight
	vacancy_delay_roll = func(minimum: int, maximum: int) -> int: return randi_range(minimum, maximum)


# Injectable so tests can force deterministic loot instead of depending on
# real randomness (see enemy_composition_roll/hit_roll for the same
# pattern). Never reset by reset() — a test sets these immediately before
# its own complete_current_encounter() call, same as enemy_composition_roll.
var loot_gold_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
var loot_gear_roll: Callable = func() -> float: return randf()
var completed_encounters: Array[String] = []
# Active encounter INSTANCES (not the template pool — see EXPEDITIONS). Each
# instance is a spawned record: {id, template_id, position, ...copied
# template fields}. A fresh campaign seeds exactly two (the Goblin Camp, id
# "goblin_camp", and the Orc Outpost, id "orc_outpost", each at its
# documented position). Clearing one starts a vacancy clock (see
# _resolve_vacancy_delay) that may add another later, capped at
# ENCOUNTER_INSTANCE_CAP. A cleared instance is never reopened; it is only
# ever recorded (by its own id) in completed_encounters.
var active_encounters: Array[Dictionary] = []
# One pending clock per open encounter vacancy: {"turns_remaining": int}.
var encounter_vacancies: Array[Dictionary] = []
# Every template id ever spawned as an active instance (initial seed plus
# every refill). _choose_encounter_position() uses this to avoid handing a
# refill the exact tile a template's earlier instance was just cleared
# from (see that function's docstring) -- it no longer influences which
# template a refill chooses; see _choose_encounter_template() for that.
# Recruitment offers do not need an equivalent: a purchased offer's id lives
# on in the roster forever, so _is_warrior_id_taken already answers "has this
# template been used" for that category.
var _used_encounter_template_ids: Array[String] = []
var world_turn: int = 1
var gold: int = 0
var guild_hall_level: int = 1
var pending_reward: int = 0
var mana_crystals: Dictionary = {}
var banked_gear: Dictionary = {}
var pending_mana_crystals: Dictionary = {}
var pending_gear: Dictionary = {}
var battle_reward: int = 0
var battle_mana_crystals: Dictionary = {}
var battle_gear: Dictionary = {}
var has_trading_post: bool = false
var player_name: String = DEFAULT_PLAYER_NAME
# Compact durable record of which first-campaign guide messages have already
# been shown/dismissed (see docs/plans/2026-08-10-initial-campaign-and-
# automation/04-first-campaign-guidance.md's get_campaign_guide_state()). An
# arbitrary id -> bool map, empty until that step starts writing to it.
var tutorial_progress: Dictionary = {}


func _init() -> void:
	reset()


func _ready() -> void:
	_load_balance_config()
	reset()


func _load_balance_config() -> void:
	BASE_ATTACK = GameConfig.get_int("combat", "base_attack", BASE_ATTACK)
	BASE_MAX_HEALTH = GameConfig.get_int("combat", "base_max_health", BASE_MAX_HEALTH)
	BASE_MOVE_RANGE = GameConfig.get_int("combat", "base_move_range", BASE_MOVE_RANGE)
	EFFECTIVE_HIT_CHANCE_CAP = GameConfig.get_float("combat", "effective_hit_chance_cap", EFFECTIVE_HIT_CHANCE_CAP)
	ATTACK_TO_HIT_CHANCE_DIVISOR = GameConfig.get_float("combat", "attack_to_hit_chance_divisor", ATTACK_TO_HIT_CHANCE_DIVISOR)
	LEVEL_UP_MAX_HEALTH_BONUS = GameConfig.get_int("progression", "level_up_max_health_bonus", LEVEL_UP_MAX_HEALTH_BONUS)
	LEVEL_UP_SKILL_POINTS = GameConfig.get_int("progression", "level_up_skill_points", LEVEL_UP_SKILL_POINTS)
	PERK_LEVEL_INTERVAL = GameConfig.get_int("progression", "perk_level_interval", PERK_LEVEL_INTERVAL)
	GUILD_HALL_LEVEL_1_PARTY_CAP = GameConfig.get_int("guild_hall", "level_1_party_cap", GUILD_HALL_LEVEL_1_PARTY_CAP)
	GUILD_HALL_LEVEL_2_PARTY_CAP = GameConfig.get_int("guild_hall", "level_2_party_cap", GUILD_HALL_LEVEL_2_PARTY_CAP)
	GUILD_HALL_UPGRADE_COST = GameConfig.get_int("guild_hall", "upgrade_cost", GUILD_HALL_UPGRADE_COST)
	GUILD_HALL_MAX_LEVEL = GameConfig.get_int("guild_hall", "max_level", GUILD_HALL_MAX_LEVEL)
	TRADING_POST_PURCHASE_COST = GameConfig.get_int("trading_post", "purchase_cost", TRADING_POST_PURCHASE_COST)
	TRADING_POST_INCOME_PER_TURN = GameConfig.get_int("trading_post", "income_per_turn", TRADING_POST_INCOME_PER_TURN)
	ENCOUNTER_INSTANCE_CAP = GameConfig.get_int("population", "encounter_instance_cap", ENCOUNTER_INSTANCE_CAP)
	RECRUITMENT_OFFER_CAP = GameConfig.get_int("population", "recruitment_offer_cap", RECRUITMENT_OFFER_CAP)
	ENCOUNTER_VACANCY_TURNS = GameConfig.get_int("population", "encounter_vacancy_turns", ENCOUNTER_VACANCY_TURNS)
	RECRUITMENT_VACANCY_TURNS = GameConfig.get_int("population", "recruitment_vacancy_turns", RECRUITMENT_VACANCY_TURNS)
	ENCOUNTER_VACANCY_JITTER_TURNS = GameConfig.get_int("population", "encounter_vacancy_jitter_turns", ENCOUNTER_VACANCY_JITTER_TURNS)
	RECRUITMENT_VACANCY_JITTER_TURNS = GameConfig.get_int("population", "recruitment_vacancy_jitter_turns", RECRUITMENT_VACANCY_JITTER_TURNS)


func start_new_game(new_player_name: String = DEFAULT_PLAYER_NAME) -> void:
	reset()
	player_name = new_player_name


func reset() -> void:
	# The roster owns a copy so a session cannot mutate the shared default data.
	adventurers = [get_default_warrior()]
	recruitment_candidates = [RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)]
	recruitment_vacancies = []
	parties = []
	selected_party_id = ""
	selected_encounter = ""
	completed_encounters = []
	active_encounters = [
		_make_encounter_instance(GOBLIN_CAMP_ID, GOBLIN_CAMP_ID, EXPEDITIONS[GOBLIN_CAMP_ID].position),
		_make_encounter_instance(ORC_OUTPOST_ID, ORC_OUTPOST_ID, EXPEDITIONS[ORC_OUTPOST_ID].position),
	]
	encounter_vacancies = []
	_used_encounter_template_ids = [GOBLIN_CAMP_ID, ORC_OUTPOST_ID]
	world_turn = 1
	gold = 0
	guild_hall_level = 1
	pending_reward = 0
	mana_crystals = {}
	banked_gear = {}
	pending_mana_crystals = {}
	pending_gear = {}
	battle_reward = 0
	battle_mana_crystals = {}
	battle_gear = {}
	has_trading_post = false
	player_name = DEFAULT_PLAYER_NAME
	tutorial_progress = {}


func create_party(party_name: String = "Party 1") -> bool:
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
		"name": party_name,
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
## nowhere to receive a new member. Also rejects if the party is at its size cap.
func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> bool:
	var party_index := _get_party_index(party_id)
	if (
		party_index == -1
		or not _is_party_encamped(parties[party_index])
		or not _has_adventurer(adventurer_id)
		or _is_adventurer_assigned(adventurer_id)
		or parties[party_index].member_ids.size() >= get_max_party_size()
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

	var adventurer: Dictionary = get_default_warrior()
	adventurer.id = candidate_id
	adventurer.name = "Warrior %d" % recruit_number
	adventurers.append(adventurer)


## Seeds a template-derived record's stats/progression with real values,
## duplicating DEFAULT_WARRIOR's authored base stats and starting progression
## the same way recruit_adventurer() gets them by duplicating the whole
## DEFAULT_WARRIOR dict. RECRUITMENT_CANDIDATE_TEMPLATES intentionally omits
## stats/progression (see its comment), so purchase_recruit() and
## _spawn_next_recruitment_offer() both call this before a template-derived
## record can be purchased into the roster — without it, a purchased or
## refilled recruit would carry genuinely empty stats/progression dicts
## instead of zeroed real ones, breaking every reader that expects real keys
## (get_effective_max_health, _award_adventurer_xp, unit_details.gd, and the
## deployed-party stat derivation in BattleController).
func _seed_adventurer_baseline_stats(record: Dictionary) -> Dictionary:
	record["stats"] = get_default_warrior().stats.duplicate(true)
	record["progression"] = get_default_warrior().progression.duplicate(true)
	return record


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
	adventurers.append(_seed_adventurer_baseline_stats(candidate))
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
	if has_trading_post:
		gold += TRADING_POST_INCOME_PER_TURN
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


func _resolve_enemy_composition(difficulty: int) -> Dictionary:
	var options: Array = STAR_ENEMY_COMPOSITIONS.get(difficulty, STAR_ENEMY_COMPOSITIONS[1])
	var option: Dictionary = options[0]
	if options.size() > 1:
		option = options[enemy_composition_roll.call(options.size())]
	var enemy: Dictionary = option.enemy.duplicate(true)
	enemy["count"] = enemy_count_roll.call(option.count_min, option.count_max)
	return enemy


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id
	var instance_index := _get_active_encounter_index(encounter_id)
	if instance_index != -1:
		active_encounters[instance_index].enemy = _resolve_enemy_composition(
			active_encounters[instance_index].difficulty
		)


## Marks the current selection complete (once — a re-completion of an
## already-completed id is a no-op) and, only when it names a still-live
## active instance, removes that instance and opens an encounter vacancy.
## Ids that name a template directly rather than a live instance (e.g. the
## debug menu's raw battlefield shortcuts) still record history and queue
## their reward, but never touch active_encounters/encounter_vacancies since
## there was no real instance to clear. On first completion, a flat gold
## bonus is queued: randi_range(0, 5) * difficulty, scaled by the
## expedition's star difficulty.
func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
		_roll_and_queue_loot(expedition.get("enemy", {}))
		battle_reward += loot_gold_roll.call(0, 5) * int(expedition.get("difficulty", 1))
		_clear_active_encounter(selected_encounter)
	selected_encounter = ""


## Rolls loot once per kill in the resolved enemy composition (a battle can
# only complete once every fielded enemy is dead, so "once per kill" and
# "kill_count times at completion" are equivalent). A loot_id with no
# ENEMY_LOOT_TABLES row (should not happen for a real expedition's enemy)
# queues nothing rather than erroring.
func _roll_and_queue_loot(enemy: Dictionary) -> void:
	var loot_id: String = enemy.get("loot_id", "")
	if not ENEMY_LOOT_TABLES.has(loot_id):
		return
	var table: Dictionary = ENEMY_LOOT_TABLES[loot_id]
	var kill_count: int = enemy.get("count", 1)
	for _kill in kill_count:
		battle_reward += loot_gold_roll.call(table.gold_min, table.gold_max) * table.gold_multiplier
		var crystal_tier: int = table.mana_crystal_tier
		battle_mana_crystals[crystal_tier] = battle_mana_crystals.get(crystal_tier, 0) + 1
		if loot_gear_roll.call() < GEAR_DROP_CHANCE:
			battle_gear[table.gear_item_id] = battle_gear.get(table.gear_item_id, 0) + 1


func abandon_current_encounter() -> void:
	selected_encounter = ""


## Adds every count in source into dest in place -- both id/tier -> count
## Dictionaries sharing the exact shape battle_gear/pending_gear/banked_gear
## (and their mana-crystal counterparts) all use. The one function shared by
## both loot-store merges: battle -> party (merge_battle_loot_into_party())
## and party -> encampment (deposit_pending_reward()).
func _merge_counts(source: Dictionary, dest: Dictionary) -> void:
	for key in source:
		dest[key] = dest.get(key, 0) + source[key]


## Merges this battle's own loot store into the party's carried store. Called
## once the player leaves the victory summary screen for the World Map (see
## GameManager.go_to_world_map()) -- a no-op if the battle store is already
## empty, e.g. when go_to_world_map() is reached from anywhere other than
## straight out of a battle.
func merge_battle_loot_into_party() -> void:
	pending_reward += battle_reward
	battle_reward = 0
	_merge_counts(battle_gear, pending_gear)
	_merge_counts(battle_mana_crystals, pending_mana_crystals)
	battle_gear = {}
	battle_mana_crystals = {}


## True whenever this battle's own loot store (battle_reward/battle_gear/
## battle_mana_crystals) still holds anything merge_battle_loot_into_party()
## has not yet folded into the party's carried store -- i.e. the window
## between complete_current_encounter() clearing selected_encounter and the
## player leaving the Battle Result screen for the World Map. See
## GameManager.can_save_current_campaign(), which ANDs this in alongside the
## "no active encounter" guard so a save can never freeze loot in this
## transient, not-yet-settled bucket.
func has_unsettled_battle_loot() -> bool:
	return battle_reward != 0 or not battle_gear.is_empty() or not battle_mana_crystals.is_empty()


## Merges the party's carried store into the Encampment's bank -- the other
## half of the shared _merge_counts() pair (see merge_battle_loot_into_
## party() for the battle -> party merge).
func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	_merge_counts(pending_gear, banked_gear)
	_merge_counts(pending_mana_crystals, mana_crystals)
	pending_gear = {}
	pending_mana_crystals = {}
	return deposited


func get_max_party_size() -> int:
	if guild_hall_level >= GUILD_HALL_MAX_LEVEL:
		return GUILD_HALL_LEVEL_2_PARTY_CAP
	return GUILD_HALL_LEVEL_1_PARTY_CAP


func can_upgrade_guild_hall() -> bool:
	return guild_hall_level < GUILD_HALL_MAX_LEVEL and gold >= GUILD_HALL_UPGRADE_COST


func upgrade_guild_hall() -> bool:
	if not can_upgrade_guild_hall():
		return false
	gold -= GUILD_HALL_UPGRADE_COST
	guild_hall_level += 1
	return true


func can_purchase_trading_post() -> bool:
	return not has_trading_post and gold >= TRADING_POST_PURCHASE_COST


func purchase_trading_post() -> bool:
	if not can_purchase_trading_post():
		return false
	gold -= TRADING_POST_PURCHASE_COST
	has_trading_post = true
	return true


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


## Looks up an item id in WEAPONS then ARMORS, returning a safe copy either
## way (an empty Dictionary for an unknown id, matching get_adventurer()'s
## and get_party()'s not-found convention).
func get_item_definition(item_id: String) -> Dictionary:
	if WEAPONS.has(item_id):
		return WEAPONS[item_id].duplicate(true)
	if ARMORS.has(item_id):
		return ARMORS[item_id].duplicate(true)
	return {}


const MANA_CRYSTAL_ID_PREFIX := "mana_crystal_"


## Gear sells for half its catalog price (rounded to the nearest integer); a
## mana crystal id ("mana_crystal_<tier>") sells for its full listed value,
## since it was never purchased at a price to halve. An unknown id prices at
## 0 rather than erroring, matching get_item_definition()'s not-found style.
func get_item_sale_price(item_id: String) -> int:
	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
		return MANA_CRYSTAL_VALUES.get(tier, 0)
	var item := get_item_definition(item_id)
	return 0 if item.is_empty() else int(round(item.price / 2.0))


## The shared loot-row shape (id/name/type/count/price) every loot-listing
## screen renders through LootTable — Stores (banked_gear/mana_crystals),
## the victory summary (battle_gear/battle_mana_crystals), and the World
## Map's Party Details screen (pending_gear/pending_mana_crystals), each
## backed by a different pair of GameSession fields but sharing this exact
## row shape and this exact pricing/naming logic.
func build_loot_rows(gear_counts: Dictionary, mana_crystal_counts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in gear_counts:
		var count: int = gear_counts[item_id]
		if count <= 0:
			continue
		var item := get_item_definition(item_id)
		rows.append({
			"id": item_id,
			"name": tr(item.name_key),
			"type": tr("stores.type.%s" % item.slot),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	for tier in mana_crystal_counts:
		var count: int = mana_crystal_counts[tier]
		if count <= 0:
			continue
		var item_id: String = "%s%d" % [MANA_CRYSTAL_ID_PREFIX, tier]
		rows.append({
			"id": item_id,
			"name": tr("stores.mana_crystal") % tier,
			"type": tr("stores.type.mana_crystal"),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	return rows


## Requires a Trading Post (design doc: selling is only available "if we have
## a Trading Post") and at least `quantity` of item_id in stock (banked_gear
## for gear, mana_crystals for a "mana_crystal_<tier>" id). Rejects and
## mutates nothing otherwise.
func sell_item(item_id: String, quantity: int = 1) -> bool:
	if not has_trading_post or quantity <= 0:
		return false
	if item_id.begins_with(MANA_CRYSTAL_ID_PREFIX):
		var tier := int(item_id.trim_prefix(MANA_CRYSTAL_ID_PREFIX))
		if mana_crystals.get(tier, 0) < quantity:
			return false
		mana_crystals[tier] -= quantity
		gold += get_item_sale_price(item_id) * quantity
		return true
	if banked_gear.get(item_id, 0) < quantity:
		return false
	banked_gear[item_id] -= quantity
	gold += get_item_sale_price(item_id) * quantity
	return true


## Requires a Trading Post and enough gold for item_id's full catalog price.
## Buys exactly one unit, banking it into banked_gear.
func buy_item(item_id: String) -> bool:
	if not has_trading_post:
		return false
	var item := get_item_definition(item_id)
	if item.is_empty() or gold < int(item.price):
		return false
	gold -= int(item.price)
	banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
	return true


## Requires item_id to currently be in banked_gear. See _equip_item_from()
## for the shared add-and-activate logic -- this is identical to
## equip_item_from_party_store() below except which pool it draws from.
func equip_item_from_bank(adventurer_id: String, item_id: String) -> bool:
	return _equip_item_from(banked_gear, adventurer_id, item_id)


## Requires item_id to currently be in the party's own store (pending_gear
## -- everything the deployed party has picked up but not yet carried home
## and banked). Used by the victory summary and World Map Party Details'
## Equip actions, both scoped to the currently deployed party, as opposed
## to Stores' Equip, which always draws from the (encamped) bank via
## equip_item_from_bank() above.
func equip_item_from_party_store(adventurer_id: String, item_id: String) -> bool:
	return _equip_item_from(pending_gear, adventurer_id, item_id)


## Shared by equip_item_from_bank()/equip_item_from_party_store(): makes
## item_id the active item for its slot, taking one unit from source_gear
## (a Dictionary of the exact same id -> count shape banked_gear and
## pending_gear both use) unless the unit already carries item_id, in
## which case source_gear is untouched and the already-carried copy is
## just re-activated. Rejects (mutates nothing) for an item not currently
## in source_gear, an unknown item id, or an unknown adventurer.
func _equip_item_from(source_gear: Dictionary, adventurer_id: String, item_id: String) -> bool:
	if source_gear.get(item_id, 0) <= 0:
		return false
	var item := get_item_definition(item_id)
	if item.is_empty():
		return false
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false

	var slot: String = item.slot
	var inventory: Array = adventurers[adventurer_index].equipment["%s_inventory" % slot]
	if not inventory.has(item_id):
		source_gear[item_id] -= 1
		inventory.append(item_id)
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


## Switches the active item for `slot` ("weapon" or "armor") to item_id,
## which must already be in that slot's inventory array. No bank
## interaction. Rejects an item not carried in that slot, an unknown slot,
## or an unknown adventurer, mutating nothing.
func activate_carried_item(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	if not inventory.has(item_id):
		return false
	adventurers[adventurer_index].equipment[slot] = item_id
	return true


## Removes item_id from slot's inventory array and returns one unit to
## banked_gear. Rejects (mutates nothing) if item_id is currently that
## slot's active item — a unit can never end up with an empty active slot,
## so the player must activate something else first — if item_id isn't
## carried in that slot at all, for an unknown slot, or for an unknown
## adventurer.
func unequip_to_bank(adventurer_id: String, slot: String, item_id: String) -> bool:
	var adventurer_index := _get_adventurer_index(adventurer_id)
	if adventurer_index == -1:
		return false
	var equipment: Dictionary = adventurers[adventurer_index].equipment
	var inventory_key := "%s_inventory" % slot
	if not equipment.has(inventory_key):
		return false
	var inventory: Array = equipment[inventory_key]
	if not inventory.has(item_id) or equipment.get(slot, "") == item_id:
		return false
	inventory.erase(item_id)
	banked_gear[item_id] = banked_gear.get(item_id, 0) + 1
	return true


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


## Resolves a single bounded delay for a newly opened vacancy via
## vacancy_delay_roll, called once per vacancy (never rerolled while
## ticking -- see _advance_encounter_vacancies()/_advance_recruitment_vacancies()).
## The lower bound is clamped to 1 so a jitter magnitude at or above the base
## can never produce a non-positive or zero-turn wait.
func _resolve_vacancy_delay(base_turns: int, jitter_turns: int) -> int:
	var minimum := maxi(1, base_turns - jitter_turns)
	var maximum := base_turns + jitter_turns
	return vacancy_delay_roll.call(minimum, maximum)


## Distinguishes "no new cooldown starts if already at capacity" (this guard,
## evaluated once at vacancy-open time) from "a clock exists but is capped
## from firing" (the symmetric guard inside _advance_encounter_vacancies).
func _start_encounter_vacancy() -> void:
	if active_encounters.size() >= ENCOUNTER_INSTANCE_CAP:
		return
	var turns_remaining := _resolve_vacancy_delay(ENCOUNTER_VACANCY_TURNS, ENCOUNTER_VACANCY_JITTER_TURNS)
	encounter_vacancies.append({"turns_remaining": turns_remaining})


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


## Weighted-random by star tier, favoring higher tiers as the player's
## power (adventurer count plus Guild Hall level -- see _player_power())
## grows. Only a template with no currently-active instance is eligible,
## so a refill never activates a second live instance of an
## already-active template. Deliberately replaces the old "show every
## template once before reuse" guarantee: at a fresh campaign's first
## refill the Ruined Fortress would otherwise be the only unseen
## template and would always be forced in regardless of power, defeating
## the point of weighting it down for a weak party.
func _player_power() -> int:
	return adventurers.size() + guild_hall_level


func _star_tier_weight(tier: int, power: int) -> int:
	var clamped_tier: int = clampi(tier, 1, 3)
	return maxi(STAR_WEIGHT_MIN, STAR_WEIGHT_BASE[clamped_tier] + STAR_WEIGHT_PER_POWER[clamped_tier] * power)


func _choose_encounter_template() -> String:
	var candidates: Array[String] = []
	for template_id in ENCOUNTER_TEMPLATE_ORDER:
		if not _is_encounter_template_active(template_id):
			candidates.append(template_id)
	if candidates.is_empty():
		return ENCOUNTER_TEMPLATE_ORDER[0]

	var power := _player_power()
	var weights: Array[int] = []
	var total_weight := 0
	for template_id in candidates:
		var weight := _star_tier_weight(EXPEDITIONS[template_id].difficulty, power)
		weights.append(weight)
		total_weight += weight

	var roll: int = star_weight_roll.call(total_weight)
	var cumulative := 0
	for index in candidates.size():
		cumulative += weights[index]
		if roll < cumulative:
			return candidates[index]
	return candidates[-1]


func _is_encounter_template_active(template_id: String) -> bool:
	for instance in active_encounters:
		if instance.template_id == template_id:
			return true
	return false


## Prefers the template's own documented position; only scans for another
## in-bounds, unoccupied, non-settlement tile if that position is already
## occupied by another active instance, OR if template_id has ever been
## spawned before (tracked by _used_encounter_template_ids). The second
## condition matters for a *reused* template: its documented tile is only
## ever occupied by its own instances, so once its earlier instance has been
## cleared (and thus removed from active_encounters), the plain occupancy
## check alone would hand a refill back the exact tile a site was just
## cleared from — visually indistinguishable from "reopening" it, which
## design.md's approved rules explicitly forbid. Reusing
## _used_encounter_template_ids (rather than tracking completed instances'
## positions separately) is sufficient because each template's documented
## position is unique to it.
##
## The scan itself walks the grid far-corner-first (descending y, then
## descending x) rather than row-major from the settlement corner. The Goblin
## Camp and Orc Outpost's own documented tiles — (4, 4) and (4, 0) — already
## sit in that far region, so scanning outward from there keeps fallback
## refills requiring meaningful travel instead of landing 1-2 tiles from
## STARTING_SETTLEMENT_WORLD_POSITION, now at the map's center, which a
## settlement-first scan would otherwise hand out on literally every refill
## (both of those two sites are marked previously-spawned from turn one, per
## reset()). The Ruined Fortress's own documented position, (0, 4), is a
## different corner this far-corner-first reasoning does not cover — but it
## does not need to:
## the Ruined Fortress is never a starting site, so it is NOT marked
## previously-spawned at reset() time, and its own first-ever spawn (always a
## refill) takes the "documented position, not yet occupied, not yet used"
## fast path near the top of this function rather than reaching this scan at
## all. This scan applies to the Ruined Fortress exactly as described above
## once it has been used once (i.e. on its second and later refills). The
## scan also explicitly skips the current template's own documented_position:
## left in, the far-corner-first order would otherwise re-select that exact
## tile whenever it happens to be free (most notably Goblin Camp's, which
## *is* the far corner scanned first), reopening the same "respawns on the
## tile it was just cleared from" problem the template_previously_spawned
## guard above exists to prevent.
func _choose_encounter_position(template_id: String) -> Vector2i:
	var documented_position: Vector2i = EXPEDITIONS[template_id].position
	var template_previously_spawned := _used_encounter_template_ids.has(template_id)
	if not _is_position_occupied(documented_position) and not template_previously_spawned:
		return documented_position
	for y in range(WORLD_GRID_HEIGHT - 1, -1, -1):
		for x in range(WORLD_GRID_WIDTH - 1, -1, -1):
			var candidate := Vector2i(x, y)
			if candidate == documented_position:
				continue
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
	var turns_remaining := _resolve_vacancy_delay(RECRUITMENT_VACANCY_TURNS, RECRUITMENT_VACANCY_JITTER_TURNS)
	recruitment_vacancies.append({"turns_remaining": turns_remaining})


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
			return _seed_adventurer_baseline_stats(template.duplicate(true))

	var overflow_number := adventurers.size() + recruitment_candidates.size() + 1
	var overflow_id := "warrior_%03d" % overflow_number
	while _is_warrior_id_taken(overflow_id):
		overflow_number += 1
		overflow_id = "warrior_%03d" % overflow_number

	var offer: Dictionary = RECRUITMENT_CANDIDATE_TEMPLATES[0].duplicate(true)
	offer.id = overflow_id
	offer.name = "Warrior %d" % overflow_number
	return _seed_adventurer_baseline_stats(offer)


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


## Returns (damage_min, damage_max) from the adventurer's equipped weapon, or
## Vector2i.ZERO for an unknown adventurer or an equipped weapon id that has
## fallen out of WEAPONS (should not happen outside of hand-edited state).
func get_effective_weapon_damage_range(adventurer_id: String) -> Vector2i:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return Vector2i.ZERO
	var weapon: Dictionary = WEAPONS.get(adventurer.equipment.weapon, {})
	if weapon.is_empty():
		return Vector2i.ZERO
	return Vector2i(weapon.damage_min, weapon.damage_max)


func get_effective_weapon_name(adventurer_id: String) -> String:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var weapon: Dictionary = WEAPONS.get(adventurer.equipment.weapon, {})
	return "" if weapon.is_empty() else tr(weapon.name_key)


func get_effective_armor_name(adventurer_id: String) -> String:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return ""
	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
	return "" if armor.is_empty() else tr(armor.name_key)


func get_effective_defense(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
	return 0 if armor.is_empty() else int(armor.defense)


func get_effective_resistance(adventurer_id: String) -> int:
	var adventurer := get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return 0
	var armor: Dictionary = ARMORS.get(adventurer.equipment.armor, {})
	return 0 if armor.is_empty() else int(armor.resistance)


## Exports every durable field this session owns as a versioned, deep-copy-
## safe, JSON-safe Dictionary (see CampaignSnapshot). No disk I/O and no
## reward-banking side effects -- battle_reward/pending_reward are carried
## across exactly as they stand, never merged or deposited.
func export_campaign_snapshot() -> Dictionary:
	var snapshot := CampaignSnapshot.new()
	snapshot.adventurers = adventurers.duplicate(true)
	snapshot.recruitment_candidates = recruitment_candidates.duplicate(true)
	snapshot.recruitment_vacancies = recruitment_vacancies.duplicate(true)
	snapshot.parties = parties.duplicate(true)
	snapshot.selected_party_id = selected_party_id
	snapshot.selected_encounter = selected_encounter
	snapshot.completed_encounters = completed_encounters.duplicate(true)
	snapshot.active_encounters = active_encounters.duplicate(true)
	snapshot.encounter_vacancies = encounter_vacancies.duplicate(true)
	snapshot.used_encounter_template_ids = _used_encounter_template_ids.duplicate(true)
	snapshot.world_turn = world_turn
	snapshot.gold = gold
	snapshot.guild_hall_level = guild_hall_level
	snapshot.pending_reward = pending_reward
	snapshot.mana_crystals = mana_crystals.duplicate(true)
	snapshot.banked_gear = banked_gear.duplicate(true)
	snapshot.pending_mana_crystals = pending_mana_crystals.duplicate(true)
	snapshot.pending_gear = pending_gear.duplicate(true)
	snapshot.battle_reward = battle_reward
	snapshot.battle_mana_crystals = battle_mana_crystals.duplicate(true)
	snapshot.battle_gear = battle_gear.duplicate(true)
	snapshot.has_trading_post = has_trading_post
	snapshot.player_name = player_name
	snapshot.tutorial_progress = tutorial_progress.duplicate(true)
	return snapshot.to_dictionary()


## All-or-nothing import: validates and normalizes data into a separate
## Dictionary (see CampaignSnapshot.from_dictionary()) and only assigns this
## session's own fields once that normalization reports "ok": true, so a
## rejected import never partially lands. Returns the same
## { "ok", "snapshot", "error" } result CampaignSnapshot.from_dictionary()
## produced, for the caller to inspect. Never calls
## merge_battle_loot_into_party() or deposit_pending_reward() -- carried
## rewards are restored exactly as exported, never banked.
##
## Every Array/Dictionary field is duplicated (never assigned directly)
## when copied from result.snapshot onto this session's own fields, so the
## two stay independent objects in both directions: a caller mutating the
## returned result's nested "snapshot" afterward (e.g. for logging) cannot
## reach back into live session state, and this session mutating its own
## fields afterward cannot reach into the returned result.
func import_campaign_snapshot(data: Dictionary) -> Dictionary:
	var result := CampaignSnapshot.from_dictionary(data)
	if not result.ok:
		return result

	var snapshot: Dictionary = result.snapshot
	adventurers = snapshot.adventurers.duplicate(true)
	recruitment_candidates = snapshot.recruitment_candidates.duplicate(true)
	recruitment_vacancies = snapshot.recruitment_vacancies.duplicate(true)
	parties = snapshot.parties.duplicate(true)
	selected_party_id = snapshot.selected_party_id
	selected_encounter = snapshot.selected_encounter
	completed_encounters = snapshot.completed_encounters.duplicate(true)
	active_encounters = snapshot.active_encounters.duplicate(true)
	encounter_vacancies = snapshot.encounter_vacancies.duplicate(true)
	_used_encounter_template_ids = snapshot.used_encounter_template_ids.duplicate(true)
	world_turn = snapshot.world_turn
	gold = snapshot.gold
	guild_hall_level = snapshot.guild_hall_level
	pending_reward = snapshot.pending_reward
	mana_crystals = snapshot.mana_crystals.duplicate(true)
	banked_gear = snapshot.banked_gear.duplicate(true)
	pending_mana_crystals = snapshot.pending_mana_crystals.duplicate(true)
	pending_gear = snapshot.pending_gear.duplicate(true)
	battle_reward = snapshot.battle_reward
	battle_mana_crystals = snapshot.battle_mana_crystals.duplicate(true)
	battle_gear = snapshot.battle_gear.duplicate(true)
	has_trading_post = snapshot.has_trading_post
	player_name = snapshot.player_name
	tutorial_progress = snapshot.tutorial_progress.duplicate(true)
	return result


## Derived, one-shot guide-state query for the first campaign's opening
## reward-to-improvement loop (see docs/plans/2026-08-10-initial-campaign-
## and-automation/04-first-campaign-guidance.md): form a party, deploy it,
## select/commit a route, enter the first site, return home to bank the
## reward, then choose the first affordable improvement. Scans
## CAMPAIGN_GUIDE_SEQUENCE and returns whichever id's contextual trigger
## currently holds and has not already been dismissed via
## record_campaign_guide_dismissal() or retired via
## record_campaign_guide_progress(); "" means nothing is due right now.
##
## A pure read, like every other get_/has_/can_ method in this file --
## calling it never writes tutorial_progress or anything else. When several
## ids are simultaneously triggered, the *latest* one in the sequence wins
## rather than the first (see _compute_campaign_guide_active_id()), but that
## alone only decides what to show *this call*; making a message that was
## actually shown stay retired across later calls is
## record_campaign_guide_progress()'s job, not this one's -- see that
## method's doc for why the split matters.
func get_campaign_guide_state() -> String:
	return _compute_campaign_guide_active_id()


## Pure priority scan: the CAMPAIGN_GUIDE_SEQUENCE entries are visited in
## order, so simply overwriting active_id on every still-triggered, not-yet-
## retired hit naturally leaves the *last* (highest-priority) one standing --
## no index bookkeeping needed to pick "latest wins" over "first wins".
func _compute_campaign_guide_active_id() -> String:
	var active_id := ""
	for guide_id in CAMPAIGN_GUIDE_SEQUENCE:
		if not tutorial_progress.get(guide_id, false) and _is_campaign_guide_triggered(guide_id):
			active_id = guide_id
	return active_id


func _is_campaign_guide_triggered(guide_id: String) -> bool:
	match guide_id:
		CAMPAIGN_GUIDE_FORM_PARTY:
			return parties.is_empty()
		CAMPAIGN_GUIDE_DEPLOY:
			return not parties.is_empty() and not has_deployed_party()
		CAMPAIGN_GUIDE_SELECT_ROUTE:
			return (
				has_deployed_party() and selected_encounter == ""
				and get_deployed_party_route().is_empty()
				and not _campaign_guide_party_on_active_encounter()
			)
		CAMPAIGN_GUIDE_ENTER_SITE:
			return (
				has_deployed_party() and selected_encounter == ""
				and _campaign_guide_party_on_active_encounter()
			)
		CAMPAIGN_GUIDE_RETURN_BANK:
			return has_deployed_party() and selected_encounter == "" and pending_reward > 0
		CAMPAIGN_GUIDE_FIRST_IMPROVEMENT:
			return (
				not has_deployed_party() and gold > 0
				and not _campaign_guide_first_improvement_made()
				and _campaign_guide_has_affordable_improvement()
			)
	return false


## True once the deployed party is standing on a tile that still names a
## live, uncleared active-encounter instance -- mirrors world_map.gd's own
## _expedition_id_at() lookup against GameSession.get_active_encounters().
func _campaign_guide_party_on_active_encounter() -> bool:
	var position := get_deployed_party_position()
	for record in get_active_encounters():
		if record.position == position:
			return true
	return false


## Monotonic proxy for "the player has already made at least one of the
## three improvements the manual verification flow names (recruit,
## equipment, Guild Hall)". Equipment purchases (buy_item()) require
## has_trading_post already being true, so that flag alone also covers the
## equipment case without needing to inspect banked_gear, which loot pickups
## populate too and would otherwise be a false positive.
func _campaign_guide_first_improvement_made() -> bool:
	return guild_hall_level > 1 or has_trading_post or adventurers.size() > 1


func _campaign_guide_has_affordable_improvement() -> bool:
	if can_upgrade_guild_hall() or can_purchase_trading_post():
		return true
	for candidate in recruitment_candidates:
		if gold >= int(candidate.get("cost", 0)):
			return true
	return false


## Explicit player action from the guide banner's Dismiss button (see
## scripts/ui/campaign_guide.gd) -- durably retires guide_id so
## get_campaign_guide_state() never returns it again this campaign,
## independent of whether its trigger condition is still true.
func record_campaign_guide_dismissal(guide_id: String) -> void:
	tutorial_progress[guide_id] = true


## Explicit write called by the guide banner (scripts/ui/campaign_guide.gd's
## refresh()) whenever it actually renders guide_id on screen -- never by
## get_campaign_guide_state() itself, which stays a pure read like every
## other get_ method here. Durably retires every id *earlier* than guide_id
## in CAMPAIGN_GUIDE_SEQUENCE (guide_id itself is left alone -- only
## record_campaign_guide_dismissal() retires the currently-active message).
##
## This is required, not decorative: the deployed party un-deploys again on
## every walk home (see return_deployed_party_to_settlement()), and the
## route/arrival triggers re-arm on every later expedition, so once the
## player has visibly moved on to a later stage, the earlier ones' live
## trigger conditions can and do become true again on their own. Tying
## retirement to an explicit call the UI makes only when it actually
## displayed guide_id -- rather than to a side effect buried in the query --
## means a message can only ever be retired because the player really saw
## something past it, never because some unrelated caller merely asked
## what the current state is.
func record_campaign_guide_progress(guide_id: String) -> void:
	var reached_index := CAMPAIGN_GUIDE_SEQUENCE.find(guide_id)
	if reached_index <= 0:
		return
	for index in reached_index:
		tutorial_progress[CAMPAIGN_GUIDE_SEQUENCE[index]] = true
