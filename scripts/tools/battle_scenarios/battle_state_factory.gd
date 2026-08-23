class_name BattleStateFactory
extends RefCounted
## Builds battle state directly from one normalized, validated concrete
## scenario case (see scenario_contract.gd/scenario_expander.gd) -- never
## from a scene, F9, or GameSession.selected_encounter. See docs/plans/
## 2026-08-10-initial-campaign-and-automation/05-battle-scenario-contract.md
## and the governing design's "Architectural boundary" section.
##
## build() returns a bare BattleControllerScript instance -- constructed via
## `.new()` and never added to the scene tree, exactly the pattern
## test_battle_controller.gd's own _make_controller() and test_battle_bot.gd
## already use for script-only battle setup. Because it's a real
## BattleController, it comes with the full public action surface BattleBot
## and enemy turns already drive (try_move_selected_unit,
## try_attack_selected_unit, get_legal_moves, run_enemy_turn, end_turn,
## is_battle_won/is_battle_lost) for free -- this file only ever sets
## `grid`, `units`, `_player_adventurer_ids`, `active_side`, `selected_unit`,
## `hit_roll`, `crit_roll`, and `damage_roll`. `_player_adventurer_ids` (player unit ids in
## build order) is required for end_turn()'s own round-start reselection
## (BattleController._first_living_player_unit(), which end_turn() calls
## on the PLAYER side) to work correctly -- without it, end_turn() would
## silently leave selected_unit null every time control returns to the
## player, exactly the gap test_battle_controller.gd's own
## _make_controller()-based tests guard against by assigning it manually
## (see test_end_turn_selects_the_first_living_player_unit_when_a_new_round_
## starts). It never calls BattleController._ready() (which would itself
## read GameSession.selected_encounter/get_selected_party()), and it never
## touches GameConfig or GameSession's mutable campaign fields -- only
## GameSession's balance *constants* (WEAPONS, ARMORS, BASE_*, the enemy
## *_STATS consts) as the default baseline that a unit's explicit
## `modifiers` layer on top of.
##
## Board `blocked` tiles are carried in the scenario contract but not yet
## wired into pathing here: Grid's own get_tile_distances()/get_adjacent()
## only know about tile occupancy, not terrain, and extending Grid is out of
## this task's scope (see the task brief: "Do not modify battle_sim yet",
## and Grid itself is left untouched for the same reason). Blocked tiles are
## still validated for bounds/overlap by scenario_contract.gd so authoring
## one is not silently ignored -- only its runtime effect is deferred.

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")


## Constructs one battle's worth of state from `scenario` (a
## ScenarioContract.normalize()d, ScenarioContract.validate()d Dictionary --
## this function trusts that contract and does not re-validate) and
## `iteration_seed` (one entry of a case's derived iteration_seeds, see
## scenario_expander.gd). The caller owns the returned controller's
## lifetime (free it or autofree() it in tests, same as any other bare
## Node2D built via `.new()`).
static func build(scenario: Dictionary, iteration_seed: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()

	var board: Dictionary = scenario.board
	controller.grid = GridScript.new(int(board.width), int(board.height))
	# Cover terrain (Stage 5 D2): hand-authored per encounter, exactly like
	# board.blocked -- see grid.gd's own cover_tiles doc comment.
	for cover_entry in board.get("cover", []):
		var cover_pos := ScenarioContractScript.position_from_dict(cover_entry.position)
		controller.grid.cover_tiles[cover_pos] = String(cover_entry.tier)

	var rng := RandomNumberGenerator.new()
	rng.seed = iteration_seed
	controller.hit_roll = func() -> float: return rng.randf()
	controller.crit_roll = func() -> float: return rng.randf()
	controller.damage_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)
	# Heal's healing amount (see battle_controller.gd's try_cast_spell()) must
	# draw from this same per-iteration seeded source, or a Cleric's Heal
	# rolls would silently fall back to Godot's global, unseeded RNG and
	# break reproducibility for any scenario that fields one.
	controller.healing_roll = func(min_value: int, max_value: int) -> int: return rng.randi_range(min_value, max_value)
	# Dodge/Parry (Stage 5 D2 tactical primitives): the same requirement as
	# every roll above -- a deterministic scenario must never fall back to
	# Godot's global, unseeded randf() for a new stochastic check either.
	controller.dodge_roll = func() -> float: return rng.randf()
	controller.parry_roll = func() -> float: return rng.randf()

	var units: Array = []
	var player_adventurer_ids: Array[String] = []
	var player_units: Array = scenario.player.units
	for index in player_units.size():
		var unit_spec: Dictionary = player_units[index]
		units.append(_build_player_unit(unit_spec, index))
		player_adventurer_ids.append(String(unit_spec.id))
	var enemy_units: Array = scenario.enemy.units
	for index in enemy_units.size():
		units.append(_build_enemy_unit(enemy_units[index], index))
	controller.units = units
	controller._player_adventurer_ids = player_adventurer_ids

	controller.active_side = BattleControllerScript.Side.PLAYER
	# Reuses BattleController's own reselection method (rather than
	# reimplementing it here) now that _player_adventurer_ids is populated,
	# so round-one's initial selection and every later end_turn() round-start
	# reselection agree by construction instead of by two parallel
	# implementations staying in sync by hand.
	controller.selected_unit = controller._first_living_player_unit()

	return controller


## The only player archetype defined today mirrors GameSession.
## get_default_warrior()'s authored base stats (see
## scenario_contract.gd's KNOWN_PLAYER_TEMPLATES). Read as GameSession's
## live BASE_* fields -- not a dictionary literal frozen at parse time --
## so a scenario always builds on GameConfig's current tuning, per the
## design's "the normal game configuration remains the default baseline."
static func _read_player_template_base_stats(template_id: String) -> Dictionary:
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(template_id, {})
	return class_def.get("base_stats", {})


## Resolves a named enemy template to GameSession's own *_ENEMY_STATS const
## (see scenario_contract.gd's KNOWN_ENEMY_TEMPLATES) -- the same data
## BattleController._get_enemy_stats() ultimately reads through
## GameSession.EXPEDITIONS/STAR_ENEMY_COMPOSITIONS, resolved here directly
## by name instead of through GameSession.selected_encounter.
static func _read_enemy_template_stats(template_id: String) -> Dictionary:
	match template_id:
		"goblin":
			return GameSession.GOBLIN_ENEMY_STATS
		"orc":
			return GameSession.ORC_ENEMY_STATS
		"kobold":
			return GameSession.KOBOLD_ENEMY_STATS
		"hobgoblin":
			return GameSession.HOBGOBLIN_ENEMY_STATS
		# Authored-ladder additions (see docs/plans/2026-08-18-core-loop-and-
		# engagement/05-authored-encounters-and-final-boss.md).
		"goblin_archer":
			return GameSession.GOBLIN_ARCHER_ENEMY_STATS
		"goblin_shaman":
			return GameSession.GOBLIN_SHAMAN_ENEMY_STATS
		"kobold_slinger":
			return GameSession.KOBOLD_SLINGER_ENEMY_STATS
		"orc_bruiser":
			return GameSession.ORC_BRUISER_ENEMY_STATS
		"hobgoblin_elite":
			return GameSession.HOBGOBLIN_ELITE_ENEMY_STATS
		"hobgoblin_champion":
			return GameSession.HOBGOBLIN_CHAMPION_ENEMY_STATS
		"orc_warlord":
			return GameSession.ORC_WARLORD_ENEMY_STATS
		"ogre":
			return GameSession.OGRE_ENEMY_STATS
		_:
			return {}


static func _build_player_unit(spec: Dictionary, index: int):
	var template_id: String = String(spec.get("template_id", "warrior"))
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(template_id, GameSession.CLASS_DEFINITIONS.warrior)
	var base: Dictionary = class_def.get("base_stats", {})
	var skills_def: Dictionary = class_def.get("skills", {})
	var weapon: Dictionary = GameSession.WEAPONS.get(spec.weapon_id, {})
	var armor: Dictionary = GameSession.ARMORS.get(spec.armor_id, {})
	var modifiers: Dictionary = spec.get("modifiers", {})
	var level: int = int(spec.get("level", 1))
	# Explicit optional perks field (scenario_contract.gd's own doc comment on
	# it, mirroring mp_current's precedent): a scenario-built unit only ever
	# gets a perk's mechanical effect when this list names it -- never from
	# ambient GameSession.get_adventurer(...).progression.perks state. See
	# campaign_sim.gd's _build_player_units(), the only caller that populates
	# this from a real adventurer's own chosen perks.
	var perks: Array = spec.get("perks", [])

	var vitality: int = int(base.get("vitality", 10))
	var max_health: int = vitality * level + int(modifiers.get("max_health", 0))
	# Juggernaut/Devout's max-health percent bonus (see GameSession.compute_
	# effective_max_health()'s own doc comment on why this is a shared static
	# helper): applied on top of the scenario's own level/modifiers-derived
	# base, exactly mirroring get_effective_max_health()'s live-route formula.
	max_health = GameSession.compute_effective_max_health(
		max_health, perks, GameSession.WARRIOR_JUGGERNAUT_HP_PERCENT, GameSession.CLERIC_DEVOUT_HP_PERCENT
	)

	var melee_min_gain: int = int(skills_def.get("melee", {}).get("min_gain", 1))
	var melee: int = int(base.get("melee", 60)) + (level - 1) * melee_min_gain + int(modifiers.get("melee", modifiers.get("attack", 0)))

	var missile_min_gain: int = int(skills_def.get("missile", {}).get("min_gain", 1))
	var missile: int = int(base.get("missile", 60)) + (level - 1) * missile_min_gain + int(modifiers.get("missile", modifiers.get("attack", 0)))

	var guard_min_gain: int = int(skills_def.get("guard", {}).get("min_gain", 1))
	var guard: int = int(base.get("guard", 0)) + (level - 1) * guard_min_gain + int(modifiers.get("guard", 0))

	var might_min_gain: int = int(skills_def.get("might", {}).get("min_gain", 1))
	var might: int = int(base.get("might", 0)) + (level - 1) * might_min_gain + int(modifiers.get("might", 0))

	var category := str(weapon.get("category", ""))
	var raw_hit_stat: float = float(missile) if category == "bow" else float(melee)
	var hit_chance: float = clampf(
		raw_hit_stat / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, 0.0, GameSession.EFFECTIVE_HIT_CHANCE_CAP
	)

	# Bonus Move/Quickdraw's flat AP bonus -- see GameSession.compute_
	# effective_action_points()'s own doc comment.
	var action_points: int = GameSession.compute_effective_action_points(
		BattleControllerScript.BASE_ACTION_POINTS + int(modifiers.get("action_points", 0)), perks, 1, GameSession.SCOUT_QUICKDRAW_ACTION_POINTS
	)
	var damage_min: int = int(weapon.get("damage_min", 0)) + int(modifiers.get("damage_min", 0))
	var damage_max: int = int(weapon.get("damage_max", 0)) + int(modifiers.get("damage_max", 0))
	# Bulwark's flat Guard bonus -- see GameSession.compute_effective_
	# defense()'s own doc comment.
	var defense: int = GameSession.compute_effective_defense(
		int(armor.get("defense", 0)) + guard + int(modifiers.get("defense", 0)), perks, GameSession.WARRIOR_BULWARK_GUARD
	)
	var resistance: int = int(armor.get("resistance", 0)) + int(modifiers.get("resistance", 0))
	# Ranged weapon attack range hydration (Step 4 of docs/plans/2026-08-21-
	# stage-2-party-readiness/04-scout-ranged-and-tier-two-pattern.md): mirrors
	# GameSession.get_effective_weapon_attack_range()'s own min_range/max_range
	# floor exactly, so a scenario-built unit's range always agrees with what
	# the same weapon_id would hydrate to in a real (BattleController._ready())
	# battle. Without this, every scenario-built player unit silently kept
	# unit.gd's melee-only 1/1 default even when the scenario declared a bow.
	var attack_min_range: int = maxi(int(weapon.get("min_range", 1)), 1)
	var attack_max_range: int = maxi(int(weapon.get("max_range", 1)), attack_min_range)

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var color: Color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	var unit := UnitScript.new(
		position, color, BattleControllerScript.Side.PLAYER,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(weapon.get("name_key", "")), String(spec.id), defense, resistance, 0, might
	)
	unit.attack_min_range = attack_min_range
	unit.attack_max_range = attack_max_range
	unit.display_name = String(spec.id)
	unit.facing = ScenarioContractScript.facing_from_string(String(spec.get("facing", "right")))

	# Explicit shared tactical profile (docs/designs/class-system.md's
	# "Shared tactical attributes" section; see unit.gd's melee/missile/
	# guard/spellcasting/magic_resistance doc comment and BattleController.
	# _ready()'s identical assignment for the live-battle route). melee/
	# missile above are the exact same local values already folded into
	# hit_chance, so they can never disagree with the combat math this unit
	# actually resolves against. Guard is `defense` (armor Guard + the
	# guard skill above, already fully resolved a few lines up), NOT the
	# bare `guard` skill-only local -- see class-system.md's own "Guard
	# Stacking" note (base Guard + armor Guard).
	unit.melee = melee
	unit.missile = missile
	unit.guard = defense
	# spellcasting only grows for a class whose skills_def actually owns it
	# (Cleric today) -- mirrors missile_min_gain/melee_min_gain's pattern
	# above, but guarded so a class with no spellcasting skill (Warrior/
	# Scout) never picks up an invented per-level gain from the shared
	# default min_gain fallback those two rely on.
	var spellcasting: int = int(base.get("spellcasting", 0))
	if skills_def.has("spellcasting"):
		var spellcasting_min_gain: int = int(skills_def.spellcasting.get("min_gain", 1))
		spellcasting += (level - 1) * spellcasting_min_gain
	unit.spellcasting = spellcasting + int(modifiers.get("spellcasting", 0))
	# No adventurer stat or armor field grants magic resistance yet (see
	# GameSession.get_effective_magic_resistance()) -- 0 unless a scenario
	# explicitly modifies it.
	unit.magic_resistance = int(modifiers.get("magic_resistance", 0))

	# Mirrors BattleController's own runtime hydration (see that file's
	# _build_player_units()-equivalent code, ~lines 245-255): a class whose
	# CLASS_DEFINITIONS entry declares spells (Cleric today) gets those
	# spells and its class's mp_max; every other class keeps unit.gd's field
	# defaults (spells == [], mp_max == 0, mp_remaining == 0). Reuses the
	# same class_def already resolved above rather than looking template_id
	# back up through GameSession.get_adventurer(), since this factory builds
	# from a scenario spec, not a live adventurer record.
	#
	# Unlike production battle start (which reads the adventurer's own
	# durable current MP -- see BattleController._ready()), a scenario has no
	# adventurer record to read: it hydrates at full MP by default, unless
	# the scenario spec sets an explicit mp_current (see scenario_contract.gd's
	# own doc comment on that field -- -1 means "not specified"), which lets a
	# deterministic test scenario exercise a Cleric who entered battle already
	# short on MP without depending on any ambient GameSession state.
	var spell_ids: Array = class_def.get("spells", [])
	if not spell_ids.is_empty():
		unit.spells = spell_ids.duplicate()
		unit.mp_max = int(class_def.get("mp_max", 0))
		var explicit_mp: int = int(spec.get("mp_current", -1))
		unit.mp_remaining = explicit_mp if explicit_mp >= 0 else unit.mp_max

	return unit


## Enemy hit chance/Guard are authored directly on the template (see
## GameSession.*_ENEMY_STATS) rather than derived from an Attack stat --
## enemies are not migrated onto the weapon/armor/attack system (see
## unit.gd's own defense/resistance doc comment). A Step 5-migrated template
## (GOBLIN_ENEMY_STATS/ORC_ENEMY_STATS/KOBOLD_ENEMY_STATS/HOBGOBLIN_ENEMY_
## STATS) authors explicit melee/missile/guard directly; every other,
## still-legacy template authors a flat hit_chance/defense instead -- see
## GameSession.get_enemy_profile_hit_chance()/get_enemy_profile_guard(),
## the single adapter both this function and BattleController._ready() call
## to normalize either shape identically (see this step's design note about
## a single adapter avoiding duplicate formula derivation). A `hit_chance`/
## `defense` scenario modifier is still a direct delta on top of either
## shape's resolved value, unlike a player's `attack` modifier.
static func _build_enemy_unit(spec: Dictionary, index: int):
	var base := _read_enemy_template_stats(spec.template_id)
	var modifiers: Dictionary = spec.get("modifiers", {})

	var max_health: int = int(base.get("max_health", 0)) + int(modifiers.get("max_health", 0))
	# A ranged template (see GOBLIN_ARCHER_ENEMY_STATS/KOBOLD_SLINGER_ENEMY_
	# STATS/GOBLIN_SHAMAN_ENEMY_STATS/OGRE_ENEMY_STATS) authors its own
	# damage_min/damage_max range directly; a fixed-damage melee template
	# only authors "attack_damage", falling back to it for both ends of the
	# range -- the same fallback BattleController._ready() applies for a
	# live battle (see its own damage_min/damage_max reads).
	var base_damage_min: int = int(base.get("damage_min", int(base.get("attack_damage", 0))))
	var base_damage_max: int = int(base.get("damage_max", int(base.get("attack_damage", 0))))
	var damage_min: int = base_damage_min + int(modifiers.get("damage_min", 0))
	var damage_max: int = base_damage_max + int(modifiers.get("damage_max", 0))
	# get_enemy_profile_melee()/get_enemy_profile_missile() (not a bare
	# base.get("melee", 0)) so a modifier against a still-legacy template
	# (no "melee"/"missile" key -- e.g. GOBLIN_ARCHER_ENEMY_STATS, hit_chance
	# 0.4) adjusts its real, hit_chance-derived accuracy (40 + modifier) --
	# not a modifier applied on top of a 0 floor (0 + modifier), which would
	# silently discard the template's actual accuracy. See those two
	# functions' own doc comment.
	var melee: int = GameSession.get_enemy_profile_melee(base) + int(modifiers.get("melee", 0))
	var missile: int = GameSession.get_enemy_profile_missile(base) + int(modifiers.get("missile", 0))
	# get_enemy_profile_hit_chance() normalizes a template dict, so a melee/
	# missile modifier must be folded in *before* calling it (a "melee"
	# scenario modifier on a migrated template must move hit_chance, exactly
	# like a player's "melee"/"attack" modifier already moves theirs) --
	# hence resolving against this merged copy rather than `base` directly.
	# Only overridden when either side actually supplies melee/missile, so a
	# purely legacy template with neither still resolves through the
	# adapter's flat "hit_chance" branch exactly as before (unaffected by
	# melee/missile now defaulting to a real derived value instead of 0,
	# since this branch is skipped entirely when neither is present).
	var profile_for_hit_chance: Dictionary = base
	if base.has("melee") or base.has("missile") or modifiers.has("melee") or modifiers.has("missile"):
		profile_for_hit_chance = base.duplicate()
		profile_for_hit_chance["melee"] = melee
		profile_for_hit_chance["missile"] = missile
	var hit_chance: float = clampf(
		GameSession.get_enemy_profile_hit_chance(profile_for_hit_chance) + float(modifiers.get("hit_chance", 0.0)), 0.0, 1.0
	)
	# An armored/elite template (see ORC_BRUISER_ENEMY_STATS/HOBGOBLIN_ELITE_
	# ENEMY_STATS/HOBGOBLIN_CHAMPION_ENEMY_STATS/ORC_WARLORD_ENEMY_STATS/
	# OGRE_ENEMY_STATS) authors its own defense/resistance directly, same
	# additive-modifier-on-top-of-base pattern as max_health/hit_chance
	# above -- an enemy with none (every original species) keeps the prior
	# modifiers-only behavior since base.get(...) then defaults to 0. A
	# "guard" modifier is the new-vocabulary alias for the same legacy
	# "defense" modifier key -- both add onto the same resolved Guard value.
	var guard: int = GameSession.get_enemy_profile_guard(base) + int(modifiers.get("guard", modifiers.get("defense", 0)))
	var resistance: int = int(base.get("resistance", 0)) + int(modifiers.get("resistance", 0))
	var action_points: int = (
		int(base.get("action_points", BattleControllerScript.BASE_ACTION_POINTS)) + int(modifiers.get("action_points", 0))
	)
	var kill_xp: int = int(base.get("kill_xp", 0))
	var spellcasting: int = int(base.get("spellcasting", 0)) + int(modifiers.get("spellcasting", 0))
	var magic_resistance: int = int(base.get("magic_resistance", 0)) + int(modifiers.get("magic_resistance", 0))
	var might: int = int(base.get("might", 0)) + int(modifiers.get("might", 0))

	var position := ScenarioContractScript.position_from_dict(spec.position)
	var unit := UnitScript.new(
		position, BattleControllerScript.ENEMY_COLOR, BattleControllerScript.Side.ENEMY,
		action_points, max_health, damage_min, damage_max, hit_chance,
		TranslationServer.translate(base.get("attack_name_key", "")), "", guard, resistance, kill_xp, might
	)
	unit.attack_min_range = int(base.get("attack_min_range", 1))
	unit.attack_max_range = int(base.get("attack_max_range", 1))
	unit.display_name = String(spec.id)
	unit.enemy_type_name = TranslationServer.translate(base.get("name_key", ""))
	unit.facing = ScenarioContractScript.facing_from_string(String(spec.get("facing", "left")))
	# Explicit shared tactical profile -- see _build_player_unit()'s identical
	# doc comment and BattleController._ready()'s matching enemy-side
	# assignment for the live-battle route (both must hydrate the same
	# profile from the same template -- see this step's own parity tests).
	unit.melee = melee
	unit.missile = missile
	unit.guard = guard
	unit.spellcasting = spellcasting
	unit.magic_resistance = magic_resistance
	return unit
