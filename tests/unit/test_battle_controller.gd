extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")

## Sentinel (an impossible hit-chance cap) rather than -1.0 alone would also
## work, but any negative value signals "no test currently owns a lowered
## cap" -- set only by tests that temporarily override
## GameSession.EFFECTIVE_HIT_CHANCE_CAP, and always restored (then reset back
## to this sentinel) by after_each(), so a mid-test runtime error can never
## leave a lowered cap corrupting every later test's hit-chance math.
var _original_effective_hit_chance_cap: float = -1.0


func before_each() -> void:
	GameSession.reset()
	AudioManager.reset()


func after_each() -> void:
	GameSession.reset_injectable_rolls()
	AudioManager.reset()
	if _original_effective_hit_chance_cap >= 0.0:
		GameSession.EFFECTIVE_HIT_CHANCE_CAP = _original_effective_hit_chance_cap
		_original_effective_hit_chance_cap = -1.0


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


func test_units_start_their_active_side_with_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var enemy = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]

	assert_eq(player.max_action_points, 6)
	assert_eq(player.action_points_remaining, 6)
	controller.end_turn()
	assert_eq(enemy.action_points_remaining, 6)


func test_three_moves_then_an_adjacent_attack_spend_the_full_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_move_selected_unit(Vector2i(3, 0)))
	assert_eq(attacker.action_points_remaining, 3)
	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 0)


func test_two_adjacent_basic_attacks_are_legal_with_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 3)
	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 0)


## --- Unit facing model (docs/plans/2026-08-18-critical-hits-and-flanking) --

func test_unit_facing_defaults_to_right() -> void:
	var unit = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)

	assert_eq(unit.facing, Vector2i.RIGHT)


func test_unit_set_facing_accepts_each_cardinal_direction() -> void:
	var unit = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)

	unit.set_facing(Vector2i.DOWN)
	assert_eq(unit.facing, Vector2i.DOWN)
	unit.set_facing(Vector2i.LEFT)
	assert_eq(unit.facing, Vector2i.LEFT)
	unit.set_facing(Vector2i.UP)
	assert_eq(unit.facing, Vector2i.UP)
	unit.set_facing(Vector2i.RIGHT)
	assert_eq(unit.facing, Vector2i.RIGHT)


func test_unit_set_facing_resolves_a_non_cardinal_vector_to_its_primary_cardinal_direction() -> void:
	var unit = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)

	unit.set_facing(Vector2i(3, 1))
	assert_eq(unit.facing, Vector2i.RIGHT, "A wider x-component resolves to the horizontal cardinal")

	unit.set_facing(Vector2i(1, 3))
	assert_eq(unit.facing, Vector2i.DOWN, "A wider y-component resolves to the vertical cardinal")

	unit.set_facing(Vector2i(-2, 2))
	assert_eq(unit.facing, Vector2i.LEFT, "A tied magnitude resolves toward the x-axis")


func test_unit_set_facing_ignores_a_zero_vector() -> void:
	var unit = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	unit.set_facing(Vector2i.DOWN)

	unit.set_facing(Vector2i.ZERO)

	assert_eq(unit.facing, Vector2i.DOWN, "A zero-length direction must not change the current facing")


## --- Initial facings at battle setup ---------------------------------------

func test_ready_sets_player_units_facing_right_and_enemy_units_facing_left() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_true(controller.units.size() > 0)
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER:
			assert_eq(unit.facing, Vector2i.RIGHT, "Player units must start facing right, toward the enemy spawn")
		else:
			assert_eq(unit.facing, Vector2i.LEFT, "Enemy units must start facing left, toward the player spawn")


## --- Facing updates on movement ---------------------------------------------

func test_wasd_step_down_sets_the_movers_facing_down() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	controller.try_step_selected_unit(Vector2i.DOWN)

	assert_eq(mover.facing, Vector2i.DOWN)


func test_wasd_step_up_sets_the_movers_facing_up() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	mover.facing = Vector2i.DOWN
	controller.units = [mover]
	controller.selected_unit = mover

	controller.try_step_selected_unit(Vector2i.UP)

	assert_eq(mover.facing, Vector2i.UP)


func test_get_legal_moves_never_includes_a_diagonal_tile() -> void:
	var controller := _make_controller(6, 6)
	# A single action point (move_range 1) means only tiles reachable in one
	# cardinal step are legal -- a two-cardinal-step L-shaped route to a
	# diagonal-looking tile like (3, 3) would need move_range 2, so this
	# isolates the "no direct diagonal step" rule from "reachable via a
	# multi-step cardinal path", which (3, 3) would otherwise satisfy.
	var mover = UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [mover]

	var moves: Array[Vector2i] = controller.get_legal_moves(mover)

	assert_false(moves.has(Vector2i(3, 3)), "Diagonal tiles are never legal move destinations")
	assert_true(moves.has(Vector2i(3, 2)), "Cardinal tiles remain legal move destinations")


## Mirrors test_shortest_path_breaks_ties_between_equally_short_routes_using_
## get_adjacents_neighbor_order() in test_grid.gd: of the three equally-short
## routes from (0,0) to (2,1), get_shortest_path()'s down-first tie-break
## makes the route's final edge RIGHT, so try_move_selected_unit() must set
## facing from that edge -- not from some path-agnostic shortcut like
## sign(target - origin).
func test_move_along_an_ambiguous_shortest_path_sets_facing_from_the_paths_final_edge() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	mover.set_facing(Vector2i.UP)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(moved)
	assert_eq(mover.grid_position, Vector2i(2, 1))
	assert_eq(mover.facing, Vector2i.RIGHT)


## --- Diagonal melee, cardinal movement --------------------------------------

func test_range_one_attacker_can_legally_and_successfully_strike_each_diagonal_neighbor() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 12)
	var diagonal_offsets: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for offset in diagonal_offsets:
		var defender = UnitScript.new(
			attacker.grid_position + offset, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10
		)
		controller.units = [attacker, defender]
		controller.selected_unit = attacker
		controller.hit_roll = func() -> float: return 0.0

		assert_true(
			controller.get_legal_attack_targets(attacker).has(defender),
			"Diagonal neighbor %s must be a legal melee target" % [defender.grid_position]
		)
		var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)
		assert_true(attacked, "A range-one attacker must be able to strike a diagonal neighbor")
		assert_eq(attacker.grid_position, Vector2i(2, 2), "A direct diagonal attack must not move the attacker")
		assert_true(defender.health < 10)


func test_ranged_weapon_keeps_using_manhattan_distance_not_diagonal_adjacency() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 2
	# Manhattan distance is 3 (out of the [1, 2] range); Chebyshev distance is
	# only 2. A ranged weapon must keep rejecting this target via the
	# existing Manhattan rule, not the melee adjacency shortcut.
	var defender = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]

	assert_false(controller.get_legal_attack_targets(attacker).has(defender))


## --- Facing updates on attack ------------------------------------------------

func test_attack_directly_below_faces_the_attacker_down() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.facing, Vector2i.DOWN)


func test_attack_to_the_left_faces_the_attacker_left() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.facing, Vector2i.LEFT)


## A bow attack that is mostly-rightward (dx=3, dy=1) must resolve to the
## wider axis, matching Unit.set_facing()'s own tie rule.
func test_ranged_attack_mostly_to_the_right_faces_the_attacker_right() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 5
	var defender = UnitScript.new(Vector2i(4, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.facing, Vector2i.RIGHT)


## --- Enemy AI / BattleBot facing consistency --------------------------------

func test_run_enemy_turn_updates_facing_on_move_and_on_attack() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 3, 1, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0

	controller.run_enemy_turn()

	# Mirrors test_run_enemy_turn_moves_then_attacks_when_movement_closes_the_gap:
	# the goblin moves to (1, 0), then attacks the player directly below it.
	assert_eq(goblin.grid_position, Vector2i(1, 0))
	assert_eq(goblin.facing, Vector2i.DOWN, "Attacking a target directly below must face the attacker south")


## --- Visual facing indicator -------------------------------------------------

## Placeholder sprites (docs/plans/2026-08-20-placeholder-sprites/
## 02-battlefield-sprites.md) replaced the old flat-color "body" ColorRect
## with a catalog-backed Sprite2D; the FacingIndicator is no longer nested
## under it (a Sprite2D's own `scale` would otherwise blow up a nested
## child's size/position too -- see _add_facing_indicator()'s doc comment),
## so it is instead a direct unit_container sibling positioned in tile-space.
## This test keeps the original per-direction geometry assertions, just
## re-expressed against that tile-space anchor instead of a sibling body's
## local `.size`.
func test_draw_units_attaches_a_facing_indicator_positioned_toward_each_units_facing() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	# Battlefield._ready() already populated unit_container once with its own
	# auto-spawned units; those children are queue_free()'d (deferred, not
	# synchronous), so they would still show up in get_children() below
	# alongside our own scenario's bodies unless removed immediately here
	# (see the same workaround in
	# test_update_highlights_renders_two_tier_movement_and_direct_and_indirect_attack_targets_in_precedence_order).
	for stale_child in controller.unit_container.get_children():
		stale_child.free()
	var right_unit = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	right_unit.set_facing(Vector2i.RIGHT)
	var down_unit = UnitScript.new(Vector2i(1, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	down_unit.set_facing(Vector2i.DOWN)
	var left_unit = UnitScript.new(Vector2i(2, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	left_unit.set_facing(Vector2i.LEFT)
	var up_unit = UnitScript.new(Vector2i(3, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	up_unit.set_facing(Vector2i.UP)
	controller.units = [right_unit, down_unit, left_unit, up_unit]

	controller._draw_units()

	var sprites: Array = []
	var indicators: Array = []
	for child in controller.unit_container.get_children():
		if child is Sprite2D:
			sprites.append(child)
		# Godot auto-suffixes sibling nodes that share a literal name (every
		# FacingIndicator here is a unit_container sibling -- see
		# _add_facing_indicator()'s doc comment), so match the stable prefix
		# rather than the exact name.
		elif str(child.name).begins_with("FacingIndicator"):
			indicators.append(child)
	assert_eq(sprites.size(), 4, "One sprite per unit")
	assert_eq(indicators.size(), 4, "One FacingIndicator per unit")
	for indicator in indicators:
		var indicator_center: Vector2 = indicator.position + indicator.size / 2.0
		var grid_pos := Vector2i(floori(indicator_center.x / BattleControllerScript.TILE_SIZE), floori(indicator_center.y / BattleControllerScript.TILE_SIZE))
		var tile_center: Vector2 = (
			Vector2(grid_pos) * BattleControllerScript.TILE_SIZE + Vector2(BattleControllerScript.TILE_SIZE, BattleControllerScript.TILE_SIZE) / 2.0
		)
		match grid_pos:
			Vector2i(0, 0):
				assert_true(
					indicator_center.x > tile_center.x, "RIGHT facing offsets the indicator toward the right edge"
				)
			Vector2i(1, 0):
				assert_true(
					indicator_center.y > tile_center.y, "DOWN facing offsets the indicator toward the bottom edge"
				)
			Vector2i(2, 0):
				assert_true(
					indicator_center.x < tile_center.x, "LEFT facing offsets the indicator toward the left edge"
				)
			Vector2i(3, 0):
				assert_true(indicator_center.y < tile_center.y, "UP facing offsets the indicator toward the top edge")


func test_sharpened_weapon_adds_one_raw_damage_before_resistance() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10, 1, 1, 1.0, "Attack", "", 0, 50)
	attacker.raw_damage_bonus = 1
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 2
	controller.hit_roll = func() -> float: return 0.0
	# Pinned above the base critical chance so this exact-damage assertion
	# can't flake into an amplified critical roll (see the Critical Hits
	# section below).
	controller.crit_roll = func() -> float: return 1.0
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(controller.last_attack_result.damage, 2, "(2 + 1) raw damage rounds to 2 after 50% resistance")


## --- Critical hits (docs/plans/2026-08-18-critical-hits-and-flanking/02-critical-hit-mechanics.md) ---

func test_crit_roll_below_the_base_critical_chance_marks_the_hit_critical() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 0.01

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_true(controller.last_attack_result.critical, "A crit_roll below the 5% base chance must land a critical hit")


func test_crit_roll_at_or_above_the_base_critical_chance_does_not_crit() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 0.50

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_false(controller.last_attack_result.critical, "A crit_roll at or above the 5% base chance must not crit")


func test_a_missed_attack_never_triggers_a_critical_hit() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2, 0.5)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99
	controller.crit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_false(controller.last_attack_result.get("hit", true))
	assert_false(controller.last_attack_result.critical, "A miss must never roll or record a critical hit")


func test_critical_hit_amplifies_raw_damage_by_the_configured_multiplier() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 4, 4)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 20)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 4
	controller.crit_roll = func() -> float: return 1.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(defender.health, 16, "A normal hit deals the raw 4 damage with no resistance")

	defender.health = 20
	controller.selected_unit = attacker
	controller.crit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(controller.last_attack_result.damage, 6, "round(4 * 1.5) = 6 damage on a critical hit")
	assert_eq(defender.health, 14, "The defender's health must reflect the amplified critical damage")


func test_critical_hit_reduces_defender_resistance_by_twenty_points() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 10, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 30, 1, 1, 1.0, "Attack", "", 0, 50)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 10
	controller.crit_roll = func() -> float: return 1.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(controller.last_attack_result.damage, 5, "round(10 * (1 - 0.50)) = 5 damage on a normal hit")

	defender.health = defender.max_health
	controller.selected_unit = attacker
	controller.crit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(
		controller.last_attack_result.damage, 11,
		"Raw damage becomes round(10 * 1.5) = 15; 50% resistance reduced by 20 points to 30%; round(15 * 0.7) = 11"
	)


func test_critical_hit_resistance_reduction_floors_at_zero() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 10, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 30, 1, 1, 1.0, "Attack", "", 0, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 10
	controller.crit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(
		controller.last_attack_result.damage, 15,
		"10% resistance reduced by 20 points floors at 0%; round(15 * 1.0) = 15"
	)


func test_thorn_rune_applies_paralyze_after_a_melee_hit_only_when_its_roll_succeeds() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	defender.rune_id = "thorn"
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.rune_trigger_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_true(controller.has_status(attacker, "paralyzed"))
	assert_true(controller.last_attack_result.get("thorn_triggered", false))
	assert_gt(attacker.health, 0, "Thorn resolves after the hit has already damaged its defender")


func test_thorn_rune_leaves_the_attacker_unaffected_when_the_trigger_roll_fails() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	defender.rune_id = "thorn"
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.rune_trigger_roll = func() -> float: return 1.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_false(controller.has_status(attacker, "paralyzed"))
	assert_false(controller.last_attack_result.get("thorn_triggered", false))


func test_paralyze_blocks_actions_without_spending_action_points_and_expires_at_the_round_boundary() -> void:
	var controller := _make_controller(4, 4)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var enemy = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [player, enemy]
	controller.selected_unit = player
	assert_true(controller.apply_status(player, "paralyzed"))

	assert_false(controller.try_move_selected_unit(Vector2i(1, 2)))
	assert_false(controller.try_attack_selected_unit(enemy.grid_position))
	assert_eq(player.action_points_remaining, 6)
	assert_false(controller.apply_status(player, "paralyzed"), "Paralyze does not refresh while active")
	controller.end_turn()
	controller.end_turn()

	assert_false(controller.has_status(player, "paralyzed"))
	controller.selected_unit = player
	assert_true(controller.try_move_selected_unit(Vector2i(1, 2)))


func test_paralyzed_enemy_turn_ends_without_moving_or_attacking() -> void:
	var controller := _make_controller(4, 4)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var enemy = UnitScript.new(Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [player, enemy]
	assert_true(controller.apply_status(enemy, "paralyzed"))
	controller.end_turn()

	assert_eq(controller.run_enemy_turn(), [])
	assert_eq(enemy.grid_position, Vector2i(3, 1))
	assert_eq(player.health, 10)


func test_paralyze_blocks_potion_use_and_item_transfer_without_mutating_inventory() -> void:
	GameSession.recruit_adventurer()
	var ally_id: String = GameSession.adventurers[-1].id
	GameSession.banked_gear = {"healing_potion": 2}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 4
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", ally_id)
	controller.units = [holder, ally]
	controller.selected_unit = holder
	assert_true(controller.apply_status(holder, "paralyzed"))

	assert_false(controller.try_use_selected_potion("healing_potion"))
	assert_false(controller.try_transfer_selected_item("healing_potion", ally_id))
	assert_eq(holder.action_points_remaining, 6)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 1)
	assert_eq(GameSession.get_carried_item_ids(ally_id).count("healing_potion"), 0)


func test_selected_player_transfers_a_carried_potion_to_an_ally_for_two_action_points() -> void:
	GameSession.recruit_adventurer()
	var ally_id: String = GameSession.adventurers[-1].id
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", ally_id)
	controller.units = [holder, ally]
	controller.selected_unit = holder

	assert_true(controller.try_transfer_selected_item("healing_potion", ally_id))
	assert_eq(holder.action_points_remaining, 4)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0)
	assert_eq(GameSession.get_carried_item_ids(ally_id).count("healing_potion"), 1)


func test_selected_player_uses_a_held_potion_for_two_action_points_and_consumes_it() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 4
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum
	controller.units = [holder]
	controller.selected_unit = holder

	assert_true(controller.try_use_selected_potion("healing_potion"))
	assert_eq(holder.action_points_remaining, 4)
	assert_eq(holder.health, 10, "Healing is capped at the unit maximum")
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0)


func test_invalid_potion_use_preserves_action_points_and_inventory() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 5
	controller.units = [holder]
	controller.selected_unit = holder

	assert_false(controller.try_use_selected_potion("healing_potion"))
	assert_eq(holder.action_points_remaining, 1)
	assert_eq(holder.health, 5)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 1)


## --- Cleric tactical spells (Step 4) ---

func test_try_cast_spell_heal_deducts_ap_and_mp_and_caps_at_max_health() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal", "bless"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum

	assert_true(controller.try_cast_spell("heal", ally.grid_position))

	assert_eq(caster.action_points_remaining, 3)
	assert_eq(caster.mp_remaining, 2)
	assert_eq(ally.health, 10, "8 HP on top of 4 exceeds max health(10), so it caps there")
	assert_eq(controller.last_attack_result.type, "spell")
	assert_eq(controller.last_attack_result.spell_id, "heal")


func test_heal_on_a_full_health_ally_is_rejected() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	controller.units = [caster, ally]
	controller.selected_unit = caster

	assert_false(controller.try_cast_spell("heal", ally.grid_position))
	assert_eq(caster.action_points_remaining, 6)
	assert_eq(caster.mp_remaining, 3)


func test_heal_on_an_enemy_is_rejected() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var enemy = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	enemy.health = 4
	controller.units = [caster, enemy]
	controller.selected_unit = caster

	assert_false(controller.try_cast_spell("heal", enemy.grid_position))
	assert_eq(enemy.health, 4)
	assert_eq(caster.mp_remaining, 3)


## Bless (see try_attack_selected_unit()): +10 percentage points of final hit
## chance and +10% of final post-resistance damage, composed on top of --
## never bypassing -- the existing hit-cap/resistance formulas.
func test_bless_adds_ten_points_of_hit_chance_and_ten_percent_post_resistance_damage() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 10, 10, 0.5, "Mace"
	)
	var healer = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	healer.spells = ["bless"]
	healer.mp_max = 3
	healer.mp_remaining = 3
	var target = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 20)
	target.resistance = 50
	controller.units = [caster, healer, target]
	controller.selected_unit = healer

	assert_true(controller.try_cast_spell("bless", caster.grid_position))
	assert_eq(healer.action_points_remaining, 3)
	assert_eq(healer.mp_remaining, 2)

	controller.selected_unit = caster
	# 0.55 sits strictly between the unblessed 50% hit chance and the
	# Blessed 60% -- only a hit here proves Bless's +10 points actually
	# applied (and was re-clamped, not just added unconditionally).
	controller.hit_roll = func() -> float: return 0.55
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_min_v: int, _max_v: int) -> int: return 10

	assert_true(controller.try_attack_selected_unit(target.grid_position))
	assert_true(
		controller.last_attack_result.hit,
		"0.55 must hit once Bless adds +10 points to the 50% base hit chance"
	)
	# raw damage 10, 50% resistance -> 5 post-resistance, +10% Bless -> round(5.5) = 6.
	assert_eq(controller.last_attack_result.damage, 6)


func test_bless_cannot_be_reapplied_to_an_already_blessed_ally() -> void:
	var controller := _make_controller(6, 6)
	var healer = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	healer.spells = ["bless"]
	healer.mp_max = 3
	healer.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	controller.units = [healer, ally]
	controller.selected_unit = healer
	assert_true(controller.try_cast_spell("bless", ally.grid_position))

	assert_false(controller.try_cast_spell("bless", ally.grid_position))
	assert_eq(healer.mp_remaining, 2, "A rejected re-bless must not spend a second MP")


func test_spell_is_rejected_beyond_its_range() -> void:
	var controller := _make_controller(8, 8)
	var caster = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(4, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster

	assert_false(controller.try_cast_spell("heal", ally.grid_position))
	assert_eq(controller.last_targeting_failure.get("reason"), "out_of_range")
	assert_eq(caster.mp_remaining, 3)


func test_spell_is_rejected_when_line_of_sight_is_blocked() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var blocker = UnitScript.new(Vector2i(0, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	var ally = UnitScript.new(Vector2i(0, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, blocker, ally]
	controller.selected_unit = caster

	assert_false(controller.try_cast_spell("heal", ally.grid_position))
	assert_eq(controller.last_targeting_failure.get("reason"), "line_of_sight_blocked")


func test_a_unit_without_the_spell_cannot_cast_it() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var ally = UnitScript.new(Vector2i(1, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [warrior, ally]
	controller.selected_unit = warrior

	assert_false(controller.try_cast_spell("heal", ally.grid_position))
	assert_eq(ally.health, 4)


## MP is the "3 per battle, no mid-battle refresh" budget (see Unit.mp_max /
## end_turn() excluding mp_remaining from its per-round reset). This is the
## spell-casting analogue of test_unaffordable_attack_preserves_action_points_
## and_combat_state below, confirming try_cast_spell()'s guard clause
## actually enforces that budget rather than the budget existing unchecked.
func test_spell_cast_is_rejected_when_mp_is_exhausted() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 0
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster

	assert_false(
		controller.try_cast_spell("heal", ally.grid_position),
		"0 MP remaining must reject the cast -- SPELL_MP_COST is 1"
	)
	assert_eq(caster.action_points_remaining, 6, "A rejected cast must not spend Action Points")
	assert_eq(caster.mp_remaining, 0, "A rejected cast must not go negative or otherwise change MP")
	assert_eq(ally.health, 4, "A rejected cast must not heal the target")
	assert_eq(controller.last_attack_result, {})


func test_spell_cast_is_rejected_when_action_points_are_insufficient() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	caster.action_points_remaining = 2
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster

	assert_false(
		controller.try_cast_spell("heal", ally.grid_position),
		"2 AP remaining must reject the cast -- SPELL_ACTION_POINT_COST is 3"
	)
	assert_eq(caster.action_points_remaining, 2, "A rejected cast must not spend the remaining Action Points")
	assert_eq(caster.mp_remaining, 3, "A rejected cast must not spend MP")
	assert_eq(ally.health, 4, "A rejected cast must not heal the target")
	assert_eq(controller.last_attack_result, {})


func test_end_turn_resets_ap_but_never_mp() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	var enemy = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [caster, ally, enemy]
	controller.selected_unit = caster
	assert_true(controller.try_cast_spell("heal", ally.grid_position))
	assert_eq(caster.mp_remaining, 2)

	controller.end_turn()
	controller.end_turn()

	assert_eq(caster.action_points_remaining, 6, "AP resets every round")
	assert_eq(caster.mp_remaining, 2, "MP must never reset mid-battle")


## Real hydration: BattleController._ready() reads GameSession.CLASS_
## DEFINITIONS generically (only Cleric carries "spells" today).
func test_ready_hydrates_mp_and_spells_only_for_a_fielded_cleric() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var warrior_unit = battlefield.grid._get_unit_by_adventurer_id(GameSession.WARRIOR_ID)
	var cleric_unit = battlefield.grid._get_unit_by_adventurer_id("cleric_test")

	assert_eq(warrior_unit.spells, [])
	assert_eq(warrior_unit.mp_max, 0)
	assert_eq(cleric_unit.spells, ["heal", "bless"])
	assert_eq(cleric_unit.mp_max, 3)
	assert_eq(cleric_unit.mp_remaining, 3)


## Core Step 3 behavior change (docs/designs/campaign-loop.md's "Cleric
## current MP is durable adventurer state" paragraph): battle start reads the
## adventurer's own stored current MP -- NOT always full. A Cleric who
## entered this battle already down to 1 of 3 MP (e.g. from an earlier fight,
## or natural recovery not yet catching up) must field a unit that starts at
## 1 MP, not a freshly-topped-off 3.
func test_ready_hydrates_a_fielded_clerics_mp_from_durable_state_not_always_full() -> void:
	GameSession.create_party()
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.set_adventurer_mp("cleric_test", 1)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var cleric_unit = battlefield.grid._get_unit_by_adventurer_id("cleric_test")

	assert_eq(cleric_unit.mp_max, 3)
	assert_eq(cleric_unit.mp_remaining, 1, "Battle start must hydrate from durable current MP, not always full")


func test_unaffordable_attack_preserves_action_points_and_combat_state() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(4, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	assert_true(controller.try_move_selected_unit(Vector2i(4, 0)))
	var health_before: int = defender.health

	assert_false(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 2)
	assert_eq(attacker.grid_position, Vector2i(4, 0))
	assert_eq(defender.health, health_before)
	assert_eq(controller.last_attack_result, {})


func test_end_turn_forfeits_departing_action_points_and_resets_only_the_new_side() -> void:
	var controller := _make_controller(6, 6)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var enemy = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]
	controller.selected_unit = player
	assert_true(controller.try_move_selected_unit(Vector2i(4, 1)))

	controller.end_turn()

	assert_eq(player.action_points_remaining, 3, "The departing side keeps its forfeited remainder until its next turn")
	assert_eq(enemy.action_points_remaining, 6)


func test_unit_moves_to_an_unoccupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(moved, "Move to an empty adjacent tile should succeed")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_unit_cannot_move_onto_an_occupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "Move onto an occupied tile should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1), "Rejected move must not change position")


func test_unit_can_move_to_an_unoccupied_tile_within_its_action_point_budget() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 3))

	assert_true(moved, "Click movement can spend multiple action points at once")
	assert_eq(mover.grid_position, Vector2i(3, 3))


func test_unit_can_move_multiple_tiles_within_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(moved, "Move within the unit's move range should succeed")
	assert_eq(mover.grid_position, Vector2i(4, 1))


func test_unit_cannot_move_beyond_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_false(moved, "Move beyond the move range should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_cannot_move_through_an_occupied_tile() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 1))

	assert_false(moved, "Movement cannot pass through an occupied tile")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_can_click_move_multiple_times_within_the_same_turn_while_points_remain() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var first_moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = mover
	var second_moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(first_moved, "The first move (spending 1 of 3 points) should succeed")
	assert_true(second_moved, "The second move (spending the remaining 2 points) should succeed")
	assert_eq(mover.grid_position, Vector2i(4, 1))
	assert_eq(mover.action_points_remaining, 0, "The full budget has been spent across both moves")


func test_unit_cannot_move_once_its_points_budget_is_exhausted() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.try_move_selected_unit(Vector2i(4, 1))
	controller.selected_unit = mover

	var moved_again: bool = controller.try_move_selected_unit(Vector2i(5, 1))

	assert_false(moved_again, "A unit with no movement points remaining cannot move again")
	assert_eq(mover.grid_position, Vector2i(4, 1))


func test_move_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller.selected_unit = enemy
	controller.active_side = BattleControllerScript.Side.PLAYER

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "A unit cannot move on the opposing side's turn")
	assert_eq(enemy.grid_position, Vector2i(1, 1))


func test_end_turn_switches_the_active_side_and_resets_movement() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_move_selected_unit(Vector2i(2, 1))

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.ENEMY, "End turn hands control to the other side")
	assert_eq(enemy_unit.action_points_remaining, enemy_unit.max_action_points, "The newly active side's units have not acted yet")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "End turn returns control to the first side")
	assert_eq(player_unit.action_points_remaining, player_unit.max_action_points, "The player's unit regains its AP on its next turn")


func test_end_turn_selects_the_first_living_player_unit_when_a_new_round_starts() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	controller.units = [first, second, enemy_unit]
	controller._player_adventurer_ids = ["warrior_001", "warrior_002"] as Array[String]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = second

	controller.end_turn()

	assert_null(controller.selected_unit, "Handing control to the enemy does not select one of its units")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "Control returns to the player")
	assert_eq(
		controller.selected_unit, first, "The first party member should be selected when a new round starts"
	)


func test_end_turn_skips_a_defeated_party_member_when_selecting_at_round_start() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	first.health = 0
	controller.units = [first, second, enemy_unit]
	controller._player_adventurer_ids = ["warrior_001", "warrior_002"] as Array[String]
	controller.active_side = BattleControllerScript.Side.PLAYER

	controller.end_turn()
	controller.end_turn()

	assert_eq(
		controller.selected_unit, second, "A defeated party member cannot be the round-start selection"
	)


func test_ready_spawns_one_unit_per_party_member_in_party_order() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var player_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER:
			player_units.append(unit)

	assert_eq(player_units.size(), 2, "One Unit should be fielded per party member")
	var first = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var second = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])
	assert_not_null(first, "The first party member should spawn at the first player start position")
	assert_eq(first.adventurer_id, GameSession.WARRIOR_ID)
	assert_not_null(second, "The second party member should spawn at the second player start position")
	assert_eq(second.adventurer_id, recruit_id)


func test_ready_selects_the_first_party_member_so_round_one_opens_with_a_selection() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_not_null(controller.selected_unit, "Round one should open with a unit already selected")
	assert_eq(controller.selected_unit.adventurer_id, GameSession.WARRIOR_ID)


func test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_eq(controller.units.size(), 2, "One Warrior (fallback) plus one goblin")
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	assert_not_null(warrior, "Warrior should spawn at the first player start position")
	assert_eq(warrior.side, BattleControllerScript.Side.PLAYER)
	assert_eq(warrior.max_health, 10)
	assert_eq(warrior.max_action_points, BattleControllerScript.BASE_ACTION_POINTS)
	assert_eq(warrior.damage_min, 1)
	assert_eq(warrior.damage_max, 8)
	assert_eq(warrior.hit_chance, 0.6)

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin, "A goblin should spawn at the first enemy start position")
	assert_eq(goblin.side, BattleControllerScript.Side.ENEMY)
	assert_eq(goblin.max_health, 13)
	assert_eq(goblin.damage_min, 2)
	assert_eq(goblin.damage_max, 2)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))


func test_ready_builds_one_orc_when_the_orc_outpost_resolves_to_orcs() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The orc-outpost's orc option fields one orc")

	var orc = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(orc)
	assert_eq(orc.side, BattleControllerScript.Side.ENEMY)
	assert_eq(orc.max_health, 22)
	assert_eq(orc.damage_min, 3)
	assert_eq(orc.damage_max, 3)
	assert_eq(orc.hit_chance, 0.5)
	assert_eq(orc.attack_name, tr("battle.enemy.orc.attack"))


func test_ready_builds_two_goblins_when_the_orc_outpost_resolves_to_goblins() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 2, "The orc-outpost's goblins option fields two goblins")

	for index in 2:
		var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[index])
		assert_not_null(goblin)
		assert_eq(goblin.max_health, 13)
		assert_eq(goblin.damage_min, 2)
		assert_eq(goblin.damage_max, 2)
		assert_eq(goblin.hit_chance, 0.3)


func test_ready_builds_one_goblin_when_the_goblin_camp_is_selected() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The goblin camp should field one goblin")

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin)
	assert_eq(goblin.max_health, 13)
	assert_eq(goblin.damage_min, 2)
	assert_eq(goblin.damage_max, 2)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))


## Step 5 (docs/plans/2026-08-21-stage-2-party-readiness/
## 05-shared-tactical-profile-migration.md): the live-battle route
## (BattleController._ready(), exercised here via Battlefield) must hydrate
## the exact same explicit shared tactical profile fields as the scene-free
## BattleStateFactory route -- see test_battle_state_factory.gd's matching
## test_build_derives_the_enemy_units_stats_from_gamesessions_named_template/
## test_build_derives_the_player_units_stats_from_gamesessions_baseline_and_
## default_gear for that route's own coverage of the same parity claim.
func test_ready_hydrates_the_shared_tactical_profile_for_both_player_and_enemy_units() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	assert_eq(warrior.melee, GameSession.CLASS_DEFINITIONS.warrior.base_stats.melee)
	assert_eq(warrior.missile, GameSession.CLASS_DEFINITIONS.warrior.base_stats.missile)
	assert_eq(warrior.guard, warrior.defense)
	assert_eq(warrior.spellcasting, 0)
	assert_eq(warrior.magic_resistance, 0)

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_eq(goblin.melee, GameSession.GOBLIN_ENEMY_STATS.melee)
	assert_eq(goblin.missile, GameSession.GOBLIN_ENEMY_STATS.missile)
	assert_eq(goblin.guard, GameSession.GOBLIN_ENEMY_STATS.guard)
	assert_eq(goblin.guard, goblin.defense, "The legacy defense field and the new guard field must always agree")
	assert_eq(goblin.spellcasting, GameSession.GOBLIN_ENEMY_STATS.spellcasting)
	assert_eq(goblin.magic_resistance, GameSession.GOBLIN_ENEMY_STATS.magic_resistance)
	assert_eq(goblin.max_action_points, GameSession.GOBLIN_ENEMY_STATS.action_points)


## Fix-review finding 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 05-shared-tactical-profile-migration.md's task-1-report.md fix report):
## the live-battle route's melee/missile display hydration must also derive
## a real value for a still-legacy enemy template (GOBLIN_ARCHER_ENEMY_STATS,
## flat hit_chance 0.4, no melee/missile key) -- not just for the four
## migrated monsters -- while leaving hit_chance itself untouched. Mirrors
## test_battle_state_factory.gd's
## test_build_derives_melee_and_missile_display_fields_for_an_unmodified_
## legacy_template for the scene-free route.
func test_ready_derives_melee_and_missile_display_fields_for_a_legacy_enemy_template() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.GOBLIN_ARCHER_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 1
	GameSession.active_encounters.append({
		"id": "legacy_profile_test",
		"template_id": GameSession.RUINED_FORTRESS_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 3,
		"kill_xp": 6,
		"clear_xp": 30,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "legacy_profile_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var archer = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(archer)
	assert_eq(GameSession.GOBLIN_ARCHER_ENEMY_STATS.hit_chance, 0.4, "Guard against this fixture drifting silently")
	assert_eq(archer.melee, 40, "0.4 hit_chance derived to a melee display value, not a misleading 0")
	assert_eq(archer.missile, 40, "0.4 hit_chance derived to a missile display value, not a misleading 0")
	assert_eq(archer.hit_chance, 0.4, "The real resolved hit chance must stay exactly the legacy value, unaffected")


func test_enemy_start_positions_supports_up_to_eight_enemies() -> void:
	assert_eq(BattleControllerScript.ENEMY_START_POSITIONS.size(), 8)


func test_ready_fields_up_to_eight_enemies_when_the_encounter_has_that_many() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.GOBLIN_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 8
	GameSession.active_encounters.append({
		"id": "capacity_test",
		"template_id": GameSession.GOBLIN_CAMP_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		"kill_xp": 5,
		"clear_xp": 10,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "capacity_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 8, "All eight enemy start positions should be usable")

	var seen_positions: Array[Vector2i] = []
	for unit in enemy_units:
		assert_true(controller.grid.is_in_bounds(unit.grid_position), "Every enemy start position must be on the board")
		assert_false(seen_positions.has(unit.grid_position), "No two enemies should share a start tile")
		seen_positions.append(unit.grid_position)


## Task 2: the player Unit is built from the selected party's first member's
## effective (derived) combat stats rather than fixed constants.
func test_ready_builds_the_player_unit_from_the_first_partys_effective_stats() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		warrior.max_health,
		GameSession.get_effective_max_health(GameSession.WARRIOR_ID),
		"The unit's max health must come from GameSession's derived value"
	)
	assert_eq(warrior.max_health, 20, "One level up should have added ten max health")
	assert_eq(warrior.health, 20, "A fresh unit starts at full (derived) health")


func test_ready_builds_the_player_unit_with_its_equipped_weapon_range() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		Vector2i(warrior.attack_min_range, warrior.attack_max_range),
		GameSession.get_effective_weapon_attack_range(GameSession.WARRIOR_ID),
		"Battle range must be copied from the equipped weapon definition"
	)


func test_ready_builds_the_player_unit_with_a_ninety_five_percent_hit_chance_when_raw_attack_reaches_one_hundred() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 140.0)
	GameSession.adventurers[0].stats.melee = 100
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.melee,
		100,
		"Raw Melee itself must not be capped"
	)
	assert_eq(warrior.hit_chance, 0.95, "Raw Attack 100 should cap the unit's hit chance at 0.95")


## Step 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md) retired bonus_move from new choose_perk()
## selections -- an existing holder keeps its effect unchanged, but a fresh
## selection is no longer how a test gets one either, so this simulates a
## legacy holder the same way GameSession's own migration tests do: direct
## progression.perks mutation.
func test_ready_builds_the_player_unit_with_one_extra_move_tile_for_a_legacy_bonus_move_holder() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers[0].progression.perks.append(GameSession.BONUS_MOVE_PERK_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.max_action_points, 7, "The bonus_move perk should add one flexible action point")


func test_ready_falls_back_to_the_default_warrior_when_no_party_is_selected() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.max_health, GameSession.get_effective_max_health(GameSession.WARRIOR_ID))
	assert_eq(warrior.hit_chance, GameSession.get_effective_hit_chance(GameSession.WARRIOR_ID))
	assert_eq(warrior.max_action_points, GameSession.get_effective_action_points(GameSession.WARRIOR_ID))


func test_ready_assigns_the_adventurers_name_as_the_player_units_display_name() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.display_name, "Warrior")
	assert_eq(warrior.enemy_type_name, "", "Player units have no enemy type name")


func test_ready_indexes_even_a_solo_enemy() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	assert_eq(goblin.display_name, "Goblin 1", "Enemies are always indexed, even the only one fielded")
	assert_eq(goblin.enemy_type_name, "Goblin")


func test_ready_assigns_stable_indexed_display_names_to_same_type_enemies() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.KOBOLD_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 3
	GameSession.active_encounters.append({
		"id": "capacity_test",
		"template_id": GameSession.RUINED_FORTRESS_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 3,
		"kill_xp": 3,
		"clear_xp": 30,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "capacity_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var names: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			names.append(unit.display_name)
			assert_eq(unit.enemy_type_name, "Kobold")
	names.sort()
	assert_eq(names, ["Kobold 1", "Kobold 2", "Kobold 3"])


## --- Presentation: visual_key hydration (docs/plans/2026-08-20-placeholder-sprites/02-battlefield-sprites.md) ---
## visual_key is presentation-only (see Unit.visual_key's doc comment): these
## tests only check the string BattleController assigns, never anything that
## could affect action legality, saved state, simulation output, or RNG.

func test_ready_assigns_player_visual_keys_from_each_adventurers_class_id() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_eq(controller._get_unit_by_adventurer_id(GameSession.WARRIOR_ID).visual_key, "player_warrior")
	assert_eq(controller._get_unit_by_adventurer_id("cleric_test").visual_key, "player_cleric")
	assert_eq(controller._get_unit_by_adventurer_id("scout_test").visual_key, "player_scout")


## The Goblin Camp's own legacy sandbox expedition (see EXPEDITIONS'
## "goblin_camp" entry) carries no "id" and no "loot_id" on its inline
## "enemy" spec -- only "name_key": "battle.enemy.goblin". Hydration must
## still resolve a correct family from that untranslated key rather than
## leaving every such enemy on the catalog's generic goblin fallback by
## accident, so this specifically exercises the name_key fallback path.
func test_ready_assigns_enemy_visual_key_for_the_goblin_camps_untagged_enemy_spec() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	assert_eq(goblin.visual_key, "enemy_goblin")


## The Ruined Fortress's inline "enemy" spec is the same untagged shape as
## the Goblin Camp's, but for a different family (Kobold) -- this is the
## regression case that would render every Ruined Fortress enemy as a
## Goblin if hydration only ever consulted "id"/"loot_id".
func test_ready_assigns_enemy_visual_key_for_the_ruined_fortresss_untagged_kobold_spec() -> void:
	GameSession.enter_encounter(GameSession.RUINED_FORTRESS_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var kobold = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	assert_eq(kobold.visual_key, "enemy_kobold")


## Direct coverage of the private family-normalization helper (BattleController.
## _visual_family_for_enemy()) across every raw-data shape it must handle:
## a tagged variant "id" (normalized down to its bare family), a bare
## "loot_id" with no "id", and the name_key-only fallback the two tests above
## already exercise end-to-end.
func test_visual_family_for_enemy_normalizes_every_raw_data_shape_to_a_catalog_family() -> void:
	var controller := _make_controller(6, 6)

	assert_eq(
		controller._visual_family_for_enemy({"id": "hobgoblin_elite", "loot_id": "hobgoblin"}), "hobgoblin",
		"A tagged variant id must normalize down to its bare family"
	)
	assert_eq(
		controller._visual_family_for_enemy({"id": "ogre"}), "ogre", "An id with no variant suffix is already a family"
	)
	assert_eq(
		controller._visual_family_for_enemy({"loot_id": "orc"}), "orc", "loot_id is used whenever id is absent"
	)
	assert_eq(
		controller._visual_family_for_enemy({"name_key": "battle.enemy.kobold"}), "kobold",
		"name_key (untranslated) is the final fallback when neither id nor loot_id is present"
	)


func test_attack_hits_and_deals_damage_when_the_roll_is_below_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 1, "A hit applies the attacker's fixed damage")
	assert_eq(attacker.action_points_remaining, 0)


func test_attack_misses_and_deals_no_damage_when_the_roll_is_at_or_above_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 3, "A miss must not change the defender's health")


func test_attack_defeats_and_removes_the_target_when_health_reaches_zero() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 1, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller.try_attack_selected_unit(defender.grid_position)

	assert_false(defender.is_alive())
	assert_eq(controller.units, [attacker], "A defeated unit is removed from the board")
	assert_null(controller.get_unit_at(defender.grid_position))


func test_attack_is_rejected_against_a_non_adjacent_target() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)
	assert_eq(defender.health, defender.max_health)


func test_two_attacks_are_allowed_when_the_unit_can_afford_both() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 5)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker

	var attacked_again: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked_again, "A unit can spend its remaining AP on a second attack")


func test_attack_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.PLAYER

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)


func test_unit_can_move_then_attack_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = attacker
	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(moved)
	assert_true(attacked)


func test_unit_can_attack_then_move_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker
	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(attacked, "Attacking first must still be legal")
	assert_true(moved, "Moving after attacking must still be legal - order does not matter")


## --- Step 2: automated pathfinding move-and-attack targeting -------------


func test_find_best_move_and_attack_tile_returns_the_cheapest_los_valid_candidate() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var target = UnitScript.new(Vector2i(4, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, target]

	var best_tile = controller.find_best_move_and_attack_tile(attacker, target)

	assert_eq(best_tile, Vector2i(3, 0), "The only green-range tile adjacent to the target should win")


func test_move_and_attack_two_tiles_away_spends_one_move_and_three_attack_ap() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(attacker.grid_position, Vector2i(1, 0), "The unit steps into melee range before attacking")
	assert_eq(attacker.action_points_remaining, 2, "6 AP - 1 move - 3 attack = 2 remaining")
	assert_true(controller.last_attack_result.get("hit", false))


func test_move_and_attack_four_tiles_away_spends_the_full_action_point_budget() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(4, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(attacker.grid_position, Vector2i(3, 0), "The unit moves 3 tiles to the adjacent square")
	assert_eq(attacker.action_points_remaining, 0, "6 AP - 3 move - 3 attack = 0 remaining")


func test_move_and_attack_five_tiles_away_is_rejected_as_insufficient_ap() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(5, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	var health_before: int = defender.health

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked, "4 move + 3 attack = 7 AP exceeds the 6 AP budget")
	assert_eq(attacker.grid_position, Vector2i(0, 0))
	assert_eq(attacker.action_points_remaining, 6)
	assert_eq(controller.last_attack_result, {})
	assert_eq(defender.health, health_before)
	assert_eq(controller.last_targeting_failure.get("reason", ""), "insufficient_ap")


func test_ranged_unit_steps_around_a_blocked_line_of_sight_to_attack() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 3
	var blocker = UnitScript.new(Vector2i(0, 1), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(0, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, blocker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked, "The unit should reposition to a tile with clear line-of-sight and attack")
	assert_ne(attacker.grid_position, Vector2i(0, 0), "The unit must have moved off its blocked origin")
	var new_distance: int = controller.grid.get_manhattan_distance(attacker.grid_position, defender.grid_position)
	assert_true(new_distance >= 1 and new_distance <= 3, "The new position must be within weapon range")
	assert_true(defender.health < 10, "The attack must have landed")


func test_move_and_attack_out_of_range_target_is_rejected_without_movement() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)
	assert_eq(controller.last_targeting_failure.get("reason", ""), "out_of_range")
	assert_eq(attacker.grid_position, Vector2i(0, 0))
	assert_eq(attacker.action_points_remaining, 6)


func test_move_and_attack_prioritizes_insufficient_ap_over_a_closer_blocked_but_affordable_tile() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 3
	var blocker = UnitScript.new(Vector2i(0, 4), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(0, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, blocker, defender]
	controller.selected_unit = attacker
	var health_before: int = defender.health

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	# (0,2) and (0,3) are affordable in-range tiles, both LOS-blocked by the
	# unit at (0,4). But (1,5) is also in range (distance 1, clear line to
	# the target) -- it just costs 6 move + 3 attack = 9 AP, more than the
	# 6 AP available. A legal-but-unaffordable tile like that one takes
	# precedence over affordable-but-blocked ones: no amount of clever
	# repositioning helps a unit that cannot afford to reach any legal tile.
	assert_false(attacked, "The only fully legal (range + clear LOS) tile is unaffordable")
	assert_eq(controller.last_targeting_failure.get("reason", ""), "insufficient_ap")
	assert_eq(attacker.grid_position, Vector2i(0, 0), "A rejected move-and-attack must not move the unit")
	assert_eq(attacker.action_points_remaining, 6, "A rejected move-and-attack must not spend AP")
	assert_eq(defender.health, health_before)


func test_move_and_attack_rejects_a_target_whose_only_in_range_tiles_are_all_los_blocked() -> void:
	# A single-column board removes every diagonal escape route, so the only
	# two tiles in weapon range of the target are the two directly blocked by
	# the unit at (0,4) -- there is no legal-but-unaffordable tile anywhere
	# else on the board to trigger insufficient_ap instead (see the
	# precedence test above), so line_of_sight_blocked is the correct reason.
	var controller := _make_controller(1, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 2
	attacker.attack_max_range = 3
	var blocker = UnitScript.new(Vector2i(0, 4), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(0, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, blocker, defender]
	controller.selected_unit = attacker
	var health_before: int = defender.health

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked, "Every in-range tile's line to the target is blocked")
	assert_eq(controller.last_targeting_failure.get("reason", ""), "line_of_sight_blocked")
	assert_eq(attacker.grid_position, Vector2i(0, 0), "A rejected move-and-attack must not move the unit")
	assert_eq(attacker.action_points_remaining, 6, "A rejected move-and-attack must not spend AP")
	assert_eq(defender.health, health_before)


func test_attack_on_an_already_in_range_target_does_not_move_the_unit() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(attacker.grid_position, Vector2i(1, 1), "An in-range target is attacked without moving")
	assert_eq(attacker.action_points_remaining, 3, "Only the attack AP cost is spent, no movement cost")


func test_end_turn_resets_action_points_for_the_newly_active_side() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy_unit = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_attack_selected_unit(enemy_unit.grid_position)

	controller.end_turn()
	controller.end_turn()

	assert_eq(player_unit.action_points_remaining, player_unit.max_action_points, "The player's unit regains its AP on its next turn")


func test_is_battle_won_when_no_living_enemies_remain() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [player_unit]

	assert_true(controller.is_battle_won())
	assert_false(controller.is_battle_lost())


func test_is_battle_lost_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy_unit]

	assert_true(controller.is_battle_lost())
	assert_false(controller.is_battle_won())


func test_run_enemy_turn_moves_the_goblin_toward_the_nearest_player_unit() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")
	assert_eq(
		goblin.grid_position,
		Vector2i(4, 3),
		"Of the four adjacent tiles, (4,3) and (3,4) tie for closest to (1,1); reading order picks the smaller y"
	)


func test_run_enemy_turn_attacks_without_moving_when_already_adjacent() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_true(steps[0].hit)
	assert_eq(steps[0].damage, 1)
	assert_eq(player_unit.health, 2)
	assert_eq(goblin.grid_position, Vector2i(1, 2), "An already-adjacent goblin should not move")


func test_run_enemy_turn_moves_then_attacks_when_movement_closes_the_gap() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 3, 1, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 2)
	assert_eq(steps[0].type, "move")
	assert_eq(
		goblin.grid_position,
		Vector2i(1, 0),
		"The goblin uses its full move range to reach the closest legal tile, then attacks from adjacent range"
	)
	assert_eq(steps[1].type, "attack")
	assert_eq(player_unit.health, 2)


func test_run_enemy_turn_breaks_target_ties_using_reading_order() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(3, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_a = UnitScript.new(Vector2i(0, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	var player_b = UnitScript.new(Vector2i(3, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_a, player_b]
	controller.active_side = BattleControllerScript.Side.ENEMY

	controller.run_enemy_turn()

	assert_eq(
		goblin.grid_position,
		Vector2i(3, 2),
		"Both player units are 3 tiles away; reading order (top-to-bottom) must pick player_b at (3, 0)"
	)


func test_run_enemy_turn_returns_no_steps_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [goblin]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps, [])
	assert_eq(goblin.grid_position, Vector2i(4, 4))


func test_locked_input_is_ignored_by_handle_tile_click() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.input_locked = true

	controller._handle_tile_click(Vector2i(1, 1))

	assert_null(controller.selected_unit, "A locked board must ignore clicks")


func test_apply_super_power_maxes_out_player_units_only() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6
	)
	var goblin = UnitScript.new(
		Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3
	)
	controller.units = [warrior, goblin]

	controller.apply_super_power()

	assert_eq(warrior.max_action_points, BattleControllerScript.SUPER_POWER_ACTION_POINTS)
	assert_eq(warrior.damage_min, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
	assert_eq(warrior.damage_max, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
	assert_eq(warrior.hit_chance, BattleControllerScript.SUPER_POWER_HIT_CHANCE)
	assert_eq(goblin.max_action_points, 3, "Super Power must not affect enemy units")
	assert_eq(goblin.damage_min, 1, "Super Power must not affect enemy units")
	assert_eq(goblin.damage_max, 1, "Super Power must not affect enemy units")
	assert_eq(goblin.hit_chance, 0.3, "Super Power must not affect enemy units")


## --- Step 3: action modes and action bar ------------------------------


func test_action_mode_defaults_to_contextual() -> void:
	var controller := _make_controller(4, 4)

	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL)


func test_set_action_mode_switches_to_move() -> void:
	var controller := _make_controller(4, 4)

	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.MOVE)


func test_set_action_mode_switches_to_attack() -> void:
	var controller := _make_controller(4, 4)

	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)

	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.ATTACK)


func test_set_action_mode_emits_the_action_mode_changed_signal() -> void:
	var controller := _make_controller(4, 4)
	watch_signals(controller)

	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	assert_signal_emitted_with_parameters(controller, "action_mode_changed", [BattleControllerScript.ActionMode.MOVE])


func test_key_m_does_not_change_action_mode() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true

	controller._handle_key_input(event)

	assert_eq(
		controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL,
		"There is no keyboard shortcut for action modes; KEY_M must be a no-op"
	)


func test_key_a_does_not_toggle_action_mode_when_the_step_is_blocked() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var blocker = UnitScript.new(Vector2i(0, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover, blocker]
	controller.selected_unit = mover
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	var event := InputEventKey.new()
	event.keycode = KEY_A
	event.pressed = true

	controller._handle_key_input(event)

	assert_eq(mover.grid_position, Vector2i(1, 1), "The step onto a friendly unit's tile must still be rejected")
	assert_eq(
		controller.action_mode, BattleControllerScript.ActionMode.ATTACK,
		"KEY_A must never itself act as a mode-toggle shortcut"
	)


func test_wasd_and_number_keys_retain_existing_behavior_regardless_of_action_mode() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.recruit_adventurer()
	var second_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(second_id)
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(3, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", second_id
	)
	controller.units = [first, second]
	controller._player_adventurer_ids = ["warrior_001", second_id] as Array[String]
	controller.selected_unit = first
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)

	var down_event := InputEventKey.new()
	down_event.keycode = KEY_S
	down_event.pressed = true
	controller._handle_key_input(down_event)

	assert_eq(first.grid_position, Vector2i(1, 2), "KEY_S must still step the unit down")

	var number_event := InputEventKey.new()
	number_event.keycode = KEY_2
	number_event.pressed = true
	controller._handle_key_input(number_event)

	assert_eq(controller.selected_unit, second, "Number keys must still select by party slot")


func test_contextual_mode_click_on_enemy_attacks_automatically() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL, "Sanity check: default mode")

	controller._handle_tile_click(defender.grid_position)

	assert_eq(attacker.grid_position, Vector2i(1, 0), "Contextual mode must still auto move-and-attack")
	assert_true(controller.last_attack_result.get("hit", false))


func test_move_mode_click_on_empty_tile_moves_the_unit() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	controller._handle_tile_click(Vector2i(2, 1))

	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_move_mode_click_on_enemy_does_not_attack_and_reports_move_mode_feedback() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [mover, enemy]
	controller.selected_unit = mover
	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)
	var health_before: int = enemy.health

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(mover.grid_position, Vector2i(1, 1), "The selected unit must not move")
	assert_eq(mover.action_points_remaining, 3, "No AP should be spent")
	assert_eq(enemy.health, health_before, "The enemy must be untouched")
	assert_eq(controller.last_targeting_failure.get("reason", ""), "move_mode_no_attack")


func test_move_mode_click_on_a_friendly_unit_selects_it() -> void:
	var controller := _make_controller(4, 4)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	controller.units = [first, second]
	controller.selected_unit = first
	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	controller._handle_tile_click(second.grid_position)

	assert_eq(controller.selected_unit, second)
	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL, "Selecting resets to contextual")


func test_attack_mode_click_on_enemy_attacks_with_move_and_attack() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(2, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	controller.hit_roll = func() -> float: return 0.0

	controller._handle_tile_click(defender.grid_position)

	assert_eq(attacker.grid_position, Vector2i(1, 0), "Attack mode should move-and-attack automatically")
	assert_true(controller.last_attack_result.get("hit", false))


func test_attack_mode_click_on_empty_tile_does_not_move_and_reports_attack_mode_feedback() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)

	controller._handle_tile_click(Vector2i(2, 1))

	assert_eq(mover.grid_position, Vector2i(1, 1), "The selected unit must not move")
	assert_eq(mover.action_points_remaining, 3, "No AP should be spent")
	assert_eq(controller.last_targeting_failure.get("reason", ""), "attack_mode_no_target")


func test_selecting_a_player_unit_resets_action_mode_to_contextual() -> void:
	var controller := _make_controller(4, 4)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	controller.units = [first, second]
	controller._player_adventurer_ids = ["warrior_001", "warrior_002"] as Array[String]
	controller.selected_unit = first
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)

	controller.select_unit_by_adventurer_id("warrior_002")

	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL)


func test_end_turn_returning_control_to_the_player_resets_action_mode_to_contextual() -> void:
	var controller := _make_controller(4, 4)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy_unit = UnitScript.new(Vector2i(3, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	controller.end_turn()  # Hands control to the enemy.
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	controller.end_turn()  # Returns control to the player.

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER)
	assert_eq(controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL)


func test_resolving_a_move_resets_action_mode_to_contextual() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	controller._handle_tile_click(Vector2i(2, 1))

	assert_eq(
		controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL,
		"Resolving a move must reset to contextual"
	)


func test_resolving_an_attack_resets_action_mode_to_contextual() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	controller.hit_roll = func() -> float: return 0.0

	controller._handle_tile_click(defender.grid_position)

	assert_eq(
		controller.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL,
		"Resolving an attack must reset to contextual"
	)


func test_wasd_step_moves_one_tile_and_spends_one_movement_point() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(stepped, "A step onto an empty adjacent tile should succeed")
	assert_eq(mover.grid_position, Vector2i(2, 1))
	assert_eq(mover.action_points_remaining, 2, "A single step spends exactly one action point")


func test_wasd_step_is_rejected_once_movement_points_are_exhausted() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [mover]
	controller.selected_unit = mover

	var first_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	controller.selected_unit = mover
	var second_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(first_step, "The first step (spending the only movement point) should succeed")
	assert_false(second_step, "A unit with no movement points remaining cannot step again")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_wasd_step_onto_an_enemy_tile_attacks_instead_of_moving() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(stepped, "Stepping into an enemy-occupied tile should succeed as an attack")
	assert_eq(defender.health, 1, "The step-attack applies the attacker's fixed damage")
	assert_eq(attacker.action_points_remaining, 0)
	assert_eq(attacker.grid_position, Vector2i(1, 1), "An attacking step must not move the attacker")


func test_wasd_step_is_rejected_while_input_is_locked() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.input_locked = true

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_false(stepped, "A locked board must ignore WASD steps")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_wasd_step_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller.selected_unit = enemy
	controller.active_side = BattleControllerScript.Side.PLAYER

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_false(stepped, "A unit cannot step on the opposing side's turn")
	assert_eq(enemy.grid_position, Vector2i(1, 1))


func test_wasd_step_is_rejected_for_a_target_outside_the_grid() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.UP)

	assert_false(stepped, "A step off the edge of the grid should be rejected")
	assert_eq(mover.grid_position, Vector2i(0, 0))


func _motion_event_over(controller: Node2D, grid_pos: Vector2i) -> InputEventMouseMotion:
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = (
		controller.global_position + Vector2(grid_pos) * BattleControllerScript.TILE_SIZE + Vector2(32, 32)
	)
	return motion_event


func test_hovering_a_tile_with_a_unit_sets_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.hovered_unit, enemy)


func test_hovering_empty_ground_clears_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(0, 0)))

	assert_null(controller.hovered_unit)


func test_clicking_an_out_of_range_enemy_pins_it_without_attacking() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(controller.inspected_unit, enemy)
	assert_true(enemy.is_alive(), "Clicking an out-of-range enemy must not attack it")


func test_clicking_an_attackable_enemy_still_attacks_instead_of_pinning() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(attacker.action_points_remaining, 0, "An in-range click must still resolve as an attack")


func test_selecting_a_unit_pins_it_as_the_inspected_unit() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [warrior]

	controller._select_unit(warrior)

	assert_eq(controller.inspected_unit, warrior)


func test_get_focused_unit_prefers_the_live_hover_over_the_pinned_click() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [warrior, enemy]
	controller._select_unit(warrior)
	assert_eq(controller.get_focused_unit(), warrior, "With nothing hovered, the pinned selection shows")

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.get_focused_unit(), enemy, "A live hover must take priority over the pinned click")


func test_unit_focus_changed_emits_when_the_focused_unit_changes() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	var received: Array = []
	controller.unit_focus_changed.connect(func(unit) -> void: received.append(unit))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(received, [enemy])


func test_wasd_step_and_a_click_move_share_the_same_movement_budget_in_one_turn() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	assert_eq(mover.grid_position, Vector2i(2, 1))
	assert_eq(mover.action_points_remaining, 2)
	controller.selected_unit = mover
	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(stepped, "The WASD step should succeed")
	assert_true(moved, "The remaining budget should cover the multi-tile click move")
	assert_eq(mover.grid_position, Vector2i(4, 1))
	assert_eq(mover.action_points_remaining, 0, "The full budget has been spent across the step and the click move")

	controller.selected_unit = mover
	var further_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	controller.selected_unit = mover
	var further_move: bool = controller.try_move_selected_unit(Vector2i(5, 1))

	assert_false(further_step, "No movement points remain for a further step")
	assert_false(further_move, "No movement points remain for a further click move")


func test_select_unit_by_adventurer_id_selects_a_living_player_unit() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [warrior]

	var selected: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_true(selected, "A living player unit should be selectable by its adventurer id")
	assert_eq(controller.selected_unit, warrior)


func test_select_unit_by_adventurer_id_is_a_no_op_for_a_defeated_or_unknown_member() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	warrior.health = 0
	controller.units = [warrior]

	var selected_defeated: bool = controller.select_unit_by_adventurer_id("warrior_001")
	var selected_unknown: bool = controller.select_unit_by_adventurer_id("no_such_id")

	assert_false(selected_defeated, "A defeated party member cannot be selected")
	assert_false(selected_unknown, "An id with no matching unit cannot be selected")
	assert_null(controller.selected_unit)


func test_select_unit_by_adventurer_id_is_a_no_op_during_the_enemy_turn_or_while_locked() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [warrior]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var selected_during_enemy_turn: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_false(selected_during_enemy_turn, "Selection is blocked during the enemy's turn")
	assert_null(controller.selected_unit)

	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.input_locked = true
	var selected_while_locked: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_false(selected_while_locked, "Selection is blocked while input is locked")
	assert_null(controller.selected_unit)


func test_select_unit_by_number_key_maps_one_based_keys_to_party_order() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	controller.units = [first, second]
	var adventurer_ids: Array[String] = ["warrior_001", "warrior_002"]
	controller._player_adventurer_ids = adventurer_ids

	var selected_first: bool = controller.select_unit_by_number_key(1)
	assert_true(selected_first)
	assert_eq(controller.selected_unit, first)

	var selected_second: bool = controller.select_unit_by_number_key(2)
	assert_true(selected_second)
	assert_eq(controller.selected_unit, second)


func test_select_unit_by_number_key_is_a_no_op_for_a_slot_beyond_the_fielded_party() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [first]
	var adventurer_ids: Array[String] = ["warrior_001"]
	controller._player_adventurer_ids = adventurer_ids

	var selected: bool = controller.select_unit_by_number_key(5)

	assert_false(selected, "A number key beyond the fielded party's size should be a no-op")
	assert_null(controller.selected_unit)


func test_wasd_key_input_steps_the_selected_unit_one_tile() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	controller.selected_unit = warrior

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_D
	controller._unhandled_input(key_event)

	assert_eq(
		warrior.grid_position,
		BattleControllerScript.PLAYER_START_POSITIONS[0] + Vector2i.RIGHT,
		"KEY_D should step the selected unit one tile to the right"
	)


## Regression test for the same bug class fixed in world_map.gd: reading
## get_local_mouse_position() (the Viewport's tracked cursor position,
## refreshed only by MouseMotion events, and offset by this node's own
## global_position since BattleController itself -- not a separate Board
## child -- is the CanvasItem) instead of the click event's own .position
## meant a click could resolve to the wrong tile if the mouse hadn't
## physically moved since a scene transition. The first player unit is
## auto-selected at battle start (_select_unit_after_action's turn-start
## call), so this test deliberately clicks a SECOND unit -- selection must
## change to it, which only happens if the click resolves to the correct
## tile; the buggy code's wildly-out-of-bounds tile_pos would leave the
## auto-selected first unit untouched instead.
func test_a_real_click_event_selects_the_correct_unit_even_when_the_tracked_cursor_position_is_stale() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var recruit = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])
	assert_eq(controller.selected_unit, warrior, "sanity check: the first player unit auto-selects at battle start")

	# InputEventMouseButton.position is in viewport (screen) space, so the
	# controller's own on-screen offset (battlefield.tscn centers the Grid
	# node, not at the origin) must be added -- exactly what a real click
	# reports and what make_input_local() expects to convert back from.
	var recruit_pixel_center := (
		controller.global_position
		+ Vector2(BattleControllerScript.PLAYER_START_POSITIONS[1]) * BattleControllerScript.TILE_SIZE
		+ Vector2(32, 32)
	)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = recruit_pixel_center

	controller._unhandled_input(click_event)

	assert_eq(
		controller.selected_unit, recruit,
		"a real click event carrying its own position must select the unit under it, regardless of the Viewport's separately-tracked (possibly stale) cursor position -- the buggy code leaves the auto-selected warrior selected instead"
	)


func test_number_key_input_selects_the_matching_fielded_party_member() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_2
	controller._unhandled_input(key_event)

	assert_not_null(controller.selected_unit, "KEY_2 should select the second fielded party member")
	assert_eq(controller.selected_unit.adventurer_id, recruit_id)


## Guard-rail: nothing else enforces that the fielding cluster (start
## positions/colors one player Unit is spawned into, see _ready()) can seat
## every member of a party at the Guild Hall's maximum size. If
## PLAYER_START_POSITIONS ever shrank below GUILD_HALL_LEVEL_3_PARTY_CAP,
## _ready()'s `mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size())`
## would silently field fewer units than the party actually has members,
## with no error — this test exists so that regression fails loudly instead.
## Must reference GUILD_HALL_LEVEL_3_PARTY_CAP (5), not the level-2 cap (4):
## the level-3 cap is the true max, and PLAYER_START_POSITIONS.size() == 5
## would otherwise clear a weaker bound without ever exercising the real one.
func test_player_start_positions_can_seat_a_full_max_size_party() -> void:
	assert_true(
		BattleControllerScript.PLAYER_START_POSITIONS.size() >= GameSession.GUILD_HALL_LEVEL_3_PARTY_CAP,
		"The fielding cluster must have at least as many start positions as the max Guild Hall party cap"
	)


func test_select_unit_by_adventurer_id_rejects_a_non_player_unit() -> void:
	var controller := _make_controller(4, 4)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Claw")
	enemy.adventurer_id = "not_really_an_adventurer"
	controller.units = [enemy]

	var selected: bool = controller.select_unit_by_adventurer_id("not_really_an_adventurer")

	assert_false(selected)
	assert_null(controller.selected_unit)


func test_attack_damage_is_rolled_between_the_attackers_min_and_max() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 8, 0.6, "Longsword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(min_value: int, max_value: int) -> int:
		assert_eq(min_value, 2)
		assert_eq(max_value, 8)
		return 5

	controller.try_attack_selected_unit(defender.grid_position)

	assert_eq(defender.health, 15, "A rolled damage of 5 with no resistance should apply in full")


func test_attack_applies_the_defenders_resistance_rounded_to_the_nearest_integer() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 10, 10, 0.6, "Longsword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 10
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_min_value: int, _max_value: int) -> int: return 10

	controller.try_attack_selected_unit(defender.grid_position)

	assert_eq(defender.health, 11, "10% resistance turns 10 damage into 9 (round(10 * 0.9) = 9)")


func test_attack_hit_chance_is_reduced_by_the_defenders_defense_but_floors_at_the_minimum() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.3, "Dagger"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 0
	)
	defender.defense = 50
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	var observed_threshold := 0.0
	controller.hit_roll = func() -> float:
		observed_threshold = 0.1
		return observed_threshold

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(
		defender.health,
		20,
		"0.3 hit chance minus 50 defense floors at 0.05; a 0.1 roll clears the floor and must still miss"
	)


func test_handle_tile_click_records_targeting_failure_and_emits_board_changed() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 1
	# Far enough that even automated move-and-attack (see
	# find_best_move_and_attack_tile()) cannot reach it within the unit's
	# full 6 AP budget -- this test now exercises a genuine out_of_range
	# rejection rather than a distance move-and-attack would resolve.
	var enemy = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	watch_signals(controller)

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(controller.last_targeting_failure.get("reason", ""), "out_of_range")
	assert_eq(controller.last_targeting_failure.get("attacker"), attacker)
	assert_eq(controller.last_targeting_failure.get("target"), enemy)
	assert_signal_emitted(controller, "board_changed")


func test_get_attackable_tiles_for_unit_returns_ranged_tiles_within_los() -> void:
	var controller := _make_controller(6, 6)
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var obstacle = UnitScript.new(Vector2i(0, 1), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	controller.units = [scout, obstacle]

	var tiles: Array[Vector2i] = controller.get_attackable_tiles_for_unit(scout)

	assert_true(tiles.has(Vector2i(1, 0)))
	assert_true(tiles.has(Vector2i(2, 0)))
	assert_true(tiles.has(Vector2i(3, 0)))
	assert_true(tiles.has(Vector2i(0, 1)), "Target on occupied tile is attackable")
	assert_false(tiles.has(Vector2i(0, 2)), "Tiles behind obstacle are blocked by LoS")
	assert_false(tiles.has(Vector2i(4, 0)), "Tiles beyond max range 3 are excluded")


func test_update_highlights_renders_attack_and_target_highlights_when_unit_has_sufficient_ap() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var enemy_in_range = UnitScript.new(Vector2i(0, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, enemy_in_range]
	controller._select_unit(scout)

	var has_target_highlight := false
	for child in controller.highlight_container.get_children():
		if child is ColorRect and child.position == Vector2(0, 2) * BattleControllerScript.TILE_SIZE:
			if child.color == BattleControllerScript.TARGET_ATTACK_COLOR:
				has_target_highlight = true

	assert_true(has_target_highlight, "Target enemy tile must be highlighted with TARGET_ATTACK_COLOR")


func test_update_highlights_omits_attack_highlights_when_unit_has_insufficient_ap() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var enemy_in_range = UnitScript.new(Vector2i(0, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, enemy_in_range]
	controller._select_unit(scout)

	var has_target_highlight := false
	for child in controller.highlight_container.get_children():
		if child is ColorRect and child.color == BattleControllerScript.TARGET_ATTACK_COLOR:
			has_target_highlight = true

	assert_false(has_target_highlight, "Target highlight must not be shown when AP < 3")


## Step 1 of the battle-screen redesign (docs/plans/2026-08-16-battle-screen-redesign):
## two-tier green/yellow movement range highlights.
func test_get_move_and_attack_and_dash_tiles_partition_by_distance_for_six_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)

	for tile in move_and_attack_tiles:
		var distance: int = controller.grid.get_manhattan_distance(mover.grid_position, tile)
		assert_true(distance <= 3, "Move-and-attack tiles must leave at least 3 AP (the attack cost) after moving")
	for tile in dash_tiles:
		var distance: int = controller.grid.get_manhattan_distance(mover.grid_position, tile)
		assert_true(distance >= 4 and distance <= 6, "Dash tiles must be reachable but leave too little AP to attack")
	assert_true(move_and_attack_tiles.has(Vector2i(3, 0)), "A distance-3 move (3 AP) leaves exactly 3 AP, enough to attack")
	assert_false(move_and_attack_tiles.has(Vector2i(4, 0)), "A distance-4 move leaves only 2 AP, not enough to attack")
	assert_true(dash_tiles.has(Vector2i(4, 0)), "A distance-4 tile is reachable but leaves too little AP to attack")
	assert_true(dash_tiles.has(Vector2i(6, 0)), "A distance-6 move spends the entire 6 AP budget on movement alone")
	assert_false(dash_tiles.has(Vector2i(7, 0)), "A distance-7 tile exceeds the unit's total AP budget")
	assert_false(move_and_attack_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")
	assert_false(dash_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")


func test_get_move_and_attack_tiles_is_empty_and_dash_tiles_cover_every_reachable_tile_for_three_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)

	assert_eq(move_and_attack_tiles, [] as Array[Vector2i], "3 AP exactly covers the attack cost, leaving nothing for movement first")
	assert_true(dash_tiles.has(Vector2i(1, 0)))
	assert_true(dash_tiles.has(Vector2i(2, 0)))
	assert_true(dash_tiles.has(Vector2i(3, 0)))
	assert_false(dash_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")


func test_get_move_and_attack_tiles_is_empty_and_all_reachable_tiles_are_dash_for_two_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)
	var legal_moves: Array[Vector2i] = controller.get_legal_moves(mover)

	assert_eq(move_and_attack_tiles, [] as Array[Vector2i], "2 AP cannot leave 3 AP remaining for an attack no matter the distance")
	assert_eq(dash_tiles.size(), legal_moves.size(), "Every reachable tile must fall into the dash tier")
	for tile in legal_moves:
		assert_true(dash_tiles.has(tile))


func test_update_highlights_renders_two_tier_movement_and_direct_and_indirect_attack_targets_in_precedence_order() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	# Battlefield._ready() auto-selects a default unit and already populated
	# highlight_container once; those children were queue_free()'d (deferred,
	# not synchronous), so they would still show up in get_children() below
	# alongside our own scenario's highlights unless removed immediately here.
	for stale_child in controller.highlight_container.get_children():
		stale_child.free()

	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 1
	# Directly attackable now: adjacent to the scout's current position. Placed
	# off the (0, y) column so it does not block the path to the green tile
	# the indirect target below is reached through.
	var direct_target = UnitScript.new(Vector2i(1, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	# Only attackable after moving: too far to hit from the origin (distance 4 > max
	# range 1), but adjacent to (0, 3), which is a green move-and-attack tile
	# (distance 3, leaving exactly 3 AP to attack).
	var indirect_target = UnitScript.new(Vector2i(0, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, direct_target, indirect_target]

	controller._select_unit(scout)

	var green_tile := Vector2(0, 3) * BattleControllerScript.TILE_SIZE
	var yellow_tile := Vector2(2, 0) * BattleControllerScript.TILE_SIZE
	var origin_tile := Vector2(0, 0) * BattleControllerScript.TILE_SIZE
	var red_target_tile := Vector2(1, 0) * BattleControllerScript.TILE_SIZE
	var orange_target_tile := Vector2(0, 4) * BattleControllerScript.TILE_SIZE

	var children: Array = controller.highlight_container.get_children()
	var green_index := -1
	var yellow_index := -1
	var red_index := -1
	var orange_index := -1
	for index in children.size():
		var child = children[index]
		if not (child is ColorRect):
			continue
		if child.color == BattleControllerScript.LEGAL_MOVE_AND_ATTACK_COLOR and child.position == green_tile:
			green_index = index
		elif child.color == BattleControllerScript.DASH_MOVE_COLOR and child.position == yellow_tile:
			yellow_index = index
		elif child.color == BattleControllerScript.TARGET_ATTACK_COLOR and child.position == red_target_tile:
			red_index = index
		elif child.color == BattleControllerScript.MOVE_AND_ATTACK_TARGET_COLOR and child.position == orange_target_tile:
			orange_index = index
		assert_false(
			(
				child.color == BattleControllerScript.LEGAL_MOVE_AND_ATTACK_COLOR
				or child.color == BattleControllerScript.DASH_MOVE_COLOR
			) and child.position == origin_tile,
			"The origin tile must never receive a movement fill; the selection ring already represents it"
		)

	assert_true(green_index >= 0, "Distance-3 tiles must render as move-and-attack (green) highlights")
	assert_true(yellow_index >= 0, "Distance-4 tiles must render as dash (yellow) highlights")
	assert_true(red_index >= 0, "An enemy directly attackable now must render a red target highlight")
	assert_true(orange_index >= 0, "An enemy attackable only after moving into green range must render an orange target highlight")
	assert_true(red_index > green_index, "Target overlays must render after movement fills so they remain visible on top")
	assert_true(orange_index > green_index, "Target overlays must render after movement fills so they remain visible on top")


## --- Flanking geometry classification (docs/plans/2026-08-18-critical-hits-
## and-flanking/03-flanking-tactics-and-combat-resolution.md) ---
##
## Truth table verified relative to a defender at (0, 0); every case below
## restates it relative to a non-origin defender position to also prove
## get_flank_type() is translation-invariant.

func test_get_flank_type_classifies_all_eight_neighbors_for_a_defender_facing_left() -> void:
	var controller := _make_controller(6, 6)
	var defender_pos := Vector2i(3, 3)

	for offset in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.LEFT), "front", "offset %s" % offset)
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.LEFT), "side", "offset %s" % offset)
	assert_eq(controller.get_flank_type(defender_pos + Vector2i(1, 0), defender_pos, Vector2i.LEFT), "rear")


func test_get_flank_type_classifies_all_eight_neighbors_for_a_defender_facing_up() -> void:
	var controller := _make_controller(6, 6)
	var defender_pos := Vector2i(3, 3)

	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.UP), "front", "offset %s" % offset)
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.UP), "side", "offset %s" % offset)
	assert_eq(controller.get_flank_type(defender_pos + Vector2i(0, 1), defender_pos, Vector2i.UP), "rear")


func test_get_flank_type_classifies_all_eight_neighbors_for_a_defender_facing_right() -> void:
	var controller := _make_controller(6, 6)
	var defender_pos := Vector2i(3, 3)

	for offset in [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.RIGHT), "front", "offset %s" % offset)
	for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(-1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.RIGHT), "side", "offset %s" % offset)
	assert_eq(controller.get_flank_type(defender_pos + Vector2i(-1, 0), defender_pos, Vector2i.RIGHT), "rear")


func test_get_flank_type_classifies_all_eight_neighbors_for_a_defender_facing_down() -> void:
	var controller := _make_controller(6, 6)
	var defender_pos := Vector2i(3, 3)

	for offset in [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.DOWN), "front", "offset %s" % offset)
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
		assert_eq(controller.get_flank_type(defender_pos + offset, defender_pos, Vector2i.DOWN), "side", "offset %s" % offset)
	assert_eq(controller.get_flank_type(defender_pos + Vector2i(0, -1), defender_pos, Vector2i.DOWN), "rear")


## A non-adjacent ranged attacker straight behind a north-facing defender is
## still a rear flank -- get_flank_type() is pure geometry with no adjacency
## requirement of its own (see try_attack_selected_unit(), which is what
## actually restricts range).
func test_get_flank_type_classifies_a_non_adjacent_ranged_position_as_rear() -> void:
	var controller := _make_controller(6, 6)

	assert_eq(controller.get_flank_type(Vector2i(0, 4), Vector2i(0, 2), Vector2i.UP), "rear")


## Proves the classifier and combat resolution agree on legal (diagonal-
## inclusive) melee geometry, not just in isolation -- a classifier that
## labels a diagonal cell correctly but that combat never lets an attacker
## reach would still pass the pure get_flank_type() tests above.
func test_try_attack_selected_unit_records_the_classified_flank_for_a_defender_facing_left() -> void:
	var defender_pos := Vector2i(3, 3)
	var expected_flank_by_offset := {
		Vector2i(-1, -1): "front", Vector2i(-1, 0): "front", Vector2i(-1, 1): "front",
		Vector2i(0, -1): "side", Vector2i(0, 1): "side", Vector2i(1, -1): "side", Vector2i(1, 1): "side",
		Vector2i(1, 0): "rear",
	}

	for offset in expected_flank_by_offset:
		var controller := _make_controller(6, 6)
		var attacker = UnitScript.new(defender_pos + offset, Color.CORNFLOWER_BLUE)
		var defender = UnitScript.new(defender_pos, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
		defender.facing = Vector2i.LEFT
		controller.units = [attacker, defender]
		controller.selected_unit = attacker

		assert_true(
			controller.try_attack_selected_unit(defender.grid_position),
			"An attack from offset %s must be a legal melee target (diagonals included)" % offset
		)
		assert_eq(
			controller.last_attack_result.flank, expected_flank_by_offset[offset],
			"Attack from offset %s must record flank \"%s\"" % [offset, expected_flank_by_offset[offset]]
		)


## --- Flanking guard reduction and hit-chance modifiers ---

## defender_facing is always LEFT here; attacker_offset selects which arc of
## that facing the case exercises (front/side/rear), matching the classifier
## tests above.
func _flank_hit_chance_setup(attacker_offset: Vector2i) -> Dictionary:
	var defender_pos := Vector2i(3, 3)
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(defender_pos + attacker_offset, Color.CORNFLOWER_BLUE, 0, 6, 10, 1, 1, 0.70)
	var defender = UnitScript.new(defender_pos, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10, 1, 1, 1.0, "Attack", "", 40)
	defender.facing = Vector2i.LEFT
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	return {"controller": controller, "defender": defender}


func test_front_attack_applies_the_defenders_full_guard_to_effective_hit_chance() -> void:
	var setup := _flank_hit_chance_setup(Vector2i(-1, 0))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "front")
	assert_eq(setup.controller.last_attack_result.effective_defense, 40)
	assert_almost_eq(setup.controller.last_attack_result.effective_hit_chance, 0.30, 0.0001)


func test_side_attack_reduces_guard_by_the_configured_side_penalty() -> void:
	var setup := _flank_hit_chance_setup(Vector2i(0, -1))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "side")
	assert_eq(setup.controller.last_attack_result.effective_defense, 20, "40 - the configured 20-point side penalty")
	assert_almost_eq(setup.controller.last_attack_result.effective_hit_chance, 0.50, 0.0001)


func test_rear_attack_reduces_guard_by_the_configured_rear_penalty_floored_at_zero() -> void:
	var setup := _flank_hit_chance_setup(Vector2i(1, 0))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "rear")
	assert_eq(setup.controller.last_attack_result.effective_defense, 0, "max(0, 40 - the configured 50-point rear penalty)")
	assert_almost_eq(setup.controller.last_attack_result.effective_hit_chance, 0.70, 0.0001)


func test_flank_effective_hit_chance_still_honors_a_lowered_configured_cap() -> void:
	_original_effective_hit_chance_cap = GameSession.EFFECTIVE_HIT_CHANCE_CAP
	GameSession.EFFECTIVE_HIT_CHANCE_CAP = 0.5

	var defender_pos := Vector2i(3, 3)
	var controller := _make_controller(6, 6)
	# Front attack (attacker directly west of an east-facing defender) with a
	# near-100% attacker hit chance and zero defender guard, so the raw
	# hit-chance math alone would exceed the lowered cap and only the cap
	# clamp can explain the recorded value.
	var attacker = UnitScript.new(defender_pos + Vector2i(-1, 0), Color.CORNFLOWER_BLUE, 0, 6, 10, 1, 1, 0.99)
	var defender = UnitScript.new(defender_pos, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	defender.facing = Vector2i.RIGHT
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_almost_eq(
		controller.last_attack_result.effective_hit_chance, 0.5, 0.0001,
		"A configured EFFECTIVE_HIT_CHANCE_CAP below 0.95 must still cap flank-adjusted hit chance"
	)


## --- Flanking critical hit chance bonuses ---

func _flank_crit_setup(attacker_offset: Vector2i) -> Dictionary:
	var defender_pos := Vector2i(3, 3)
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(defender_pos + attacker_offset, Color.CORNFLOWER_BLUE, 0, 6, 10, 1, 1, 1.0)
	var defender = UnitScript.new(defender_pos, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	defender.facing = Vector2i.LEFT
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 0.40
	return {"controller": controller, "defender": defender}


func test_front_attack_uses_the_base_five_percent_critical_threshold() -> void:
	var setup := _flank_crit_setup(Vector2i(-1, 0))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "front")
	assert_almost_eq(setup.controller.last_attack_result.effective_crit_chance, 0.05, 0.0001)
	assert_false(setup.controller.last_attack_result.critical, "An injected 0.40 roll must not crit at the 5% front threshold")


func test_side_attack_adds_the_configured_side_critical_bonus() -> void:
	var setup := _flank_crit_setup(Vector2i(0, -1))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "side")
	assert_almost_eq(setup.controller.last_attack_result.effective_crit_chance, 0.25, 0.0001)
	assert_false(setup.controller.last_attack_result.critical, "An injected 0.40 roll must not crit at the 25% side threshold")


func test_rear_attack_adds_the_configured_rear_critical_bonus_and_lands_a_crit() -> void:
	var setup := _flank_crit_setup(Vector2i(1, 0))

	assert_true(setup.controller.try_attack_selected_unit(setup.defender.grid_position))
	assert_eq(setup.controller.last_attack_result.flank, "rear")
	assert_almost_eq(setup.controller.last_attack_result.effective_crit_chance, 0.55, 0.0001)
	assert_true(setup.controller.last_attack_result.critical, "An injected 0.40 roll must crit at the 55% rear threshold")


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: a player unit
## defeated in real combat is erased from `units` immediately (freeing its
## tile), the same way a defeated enemy already was -- but its final (0)
## health must still be recoverable at battle resolution so permadeath can
## run. See defeated_player_health_by_id's own doc comment.
func test_a_player_unit_defeated_in_combat_is_erased_but_recorded_for_aftermath() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10, 20, 20, 1.0)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 5)
	defender.adventurer_id = "warrior_001"
	controller.units = [attacker, defender]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_false(controller.units.has(defender), "The defeated unit is erased so its tile frees up")
	assert_eq(controller.defeated_player_health_by_id.get("warrior_001", -1), 0)


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: Tactical Retreat.

func _make_retreat_scene(distance: int, health: int = 10) -> Dictionary:
	var controller := _make_controller(20, 20)
	var player = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, health)
	player.adventurer_id = "warrior_001"
	var enemy = UnitScript.new(Vector2i(distance, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]
	controller.active_side = BattleControllerScript.Side.PLAYER
	return {"controller": controller, "player": player, "enemy": enemy}


func test_nearest_enemy_distance_uses_chebyshev_not_manhattan_distance() -> void:
	var controller := _make_controller(20, 20)
	var player = UnitScript.new(Vector2i(5, 5), Color.CORNFLOWER_BLUE)
	var enemy = UnitScript.new(Vector2i(7, 6), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]

	# Chebyshev: max(|7-5|, |6-5|) = 2. Manhattan (the wrong measure) would be 3.
	assert_eq(controller._nearest_enemy_distance(player.grid_position), 2)


func test_retreat_distance_bucket_matches_the_locked_roadmap_ranges() -> void:
	var controller := _make_controller(20, 20)
	assert_eq(controller._retreat_distance_bucket(1), "near")
	assert_eq(controller._retreat_distance_bucket(3), "near")
	assert_eq(controller._retreat_distance_bucket(4), "mid")
	assert_eq(controller._retreat_distance_bucket(6), "mid")
	assert_eq(controller._retreat_distance_bucket(7), "far")
	assert_eq(controller._retreat_distance_bucket(20), "far")


## Distance 1-3 ("near"): 10% no-loss / 30% 10%-loss / 30% 50%-loss / 30% death.
func test_retreat_near_distance_outcome_distribution() -> void:
	var scene := _make_retreat_scene(2, 10)
	scene.controller.retreat_roll = func() -> float: return 0.0
	var results: Array[Dictionary] = scene.controller.try_retreat()
	assert_eq(results[0].distance, 2)
	assert_eq(results[0].outcome, "no_loss")
	assert_eq(results[0].hp_loss, 0)
	assert_eq(scene.player.health, 10)

	scene = _make_retreat_scene(2, 10)
	scene.controller.retreat_roll = func() -> float: return 0.10
	results = scene.controller.try_retreat()
	assert_eq(results[0].outcome, "ten_percent")
	assert_eq(results[0].hp_loss, 1, "ceil(10 * 0.10)")
	assert_eq(scene.player.health, 9)

	scene = _make_retreat_scene(2, 10)
	scene.controller.retreat_roll = func() -> float: return 0.40
	results = scene.controller.try_retreat()
	assert_eq(results[0].outcome, "fifty_percent")
	assert_eq(results[0].hp_loss, 5, "ceil(10 * 0.50)")
	assert_eq(scene.player.health, 5)

	scene = _make_retreat_scene(2, 10)
	scene.controller.retreat_roll = func() -> float: return 0.70
	results = scene.controller.try_retreat()
	assert_eq(results[0].outcome, "death")
	assert_eq(results[0].hp_loss, 10)
	assert_eq(scene.player.health, 0)
	assert_true(results[0].died)


## The step doc's TDD list is explicit that the percentage is "10% max HP
## loss" / "50% max HP loss" -- of max_health, not current/remaining health
## (even though the roadmap table's column header, "No remaining-HP loss",
## could be misread as applying to every column). A wounded unit's loss must
## scale off its max, not its already-reduced current health.
func test_retreat_hp_loss_percentage_is_based_on_max_health_not_current_health() -> void:
	var scene := _make_retreat_scene(2, 10)
	scene.player.health = 4
	scene.controller.retreat_roll = func() -> float: return 0.10

	var results: Array[Dictionary] = scene.controller.try_retreat()

	assert_eq(results[0].outcome, "ten_percent")
	assert_eq(results[0].hp_loss, 1, "10% of max health (10), not current health (4)")
	assert_eq(scene.player.health, 3)


## Distance 4-6 ("mid"): 20% no-loss / 50% 10%-loss / 10% 50%-loss / 10% death.
func test_retreat_mid_distance_outcome_distribution() -> void:
	var scene := _make_retreat_scene(5, 10)
	scene.controller.retreat_roll = func() -> float: return 0.0
	assert_eq(scene.controller.try_retreat()[0].outcome, "no_loss")

	scene = _make_retreat_scene(5, 10)
	scene.controller.retreat_roll = func() -> float: return 0.20
	assert_eq(scene.controller.try_retreat()[0].outcome, "ten_percent")

	scene = _make_retreat_scene(5, 10)
	scene.controller.retreat_roll = func() -> float: return 0.70
	assert_eq(scene.controller.try_retreat()[0].outcome, "fifty_percent")

	scene = _make_retreat_scene(5, 10)
	scene.controller.retreat_roll = func() -> float: return 0.80
	assert_eq(scene.controller.try_retreat()[0].outcome, "death")


## Distance 7+ ("far"): 50% no-loss / 30% 10%-loss / 10% 50%-loss / 10% death.
func test_retreat_far_distance_outcome_distribution() -> void:
	var scene := _make_retreat_scene(9, 10)
	scene.controller.retreat_roll = func() -> float: return 0.0
	assert_eq(scene.controller.try_retreat()[0].outcome, "no_loss")

	scene = _make_retreat_scene(9, 10)
	scene.controller.retreat_roll = func() -> float: return 0.50
	assert_eq(scene.controller.try_retreat()[0].outcome, "ten_percent")

	scene = _make_retreat_scene(9, 10)
	scene.controller.retreat_roll = func() -> float: return 0.80
	assert_eq(scene.controller.try_retreat()[0].outcome, "fifty_percent")

	scene = _make_retreat_scene(9, 10)
	scene.controller.retreat_roll = func() -> float: return 0.90
	assert_eq(scene.controller.try_retreat()[0].outcome, "death")


func test_try_retreat_discards_unbanked_battle_loot_and_emits_retreat_resolved() -> void:
	GameSession.reset()
	GameSession.battle_reward = 5
	GameSession.battle_gear = {"dagger_iron": 1}
	GameSession.battle_mana_crystals = {1: 1}
	var scene := _make_retreat_scene(2, 10)
	scene.controller.retreat_roll = func() -> float: return 0.0
	var emitted: Array = []
	scene.controller.retreat_resolved.connect(func(results: Array) -> void: emitted.append(results))

	var results: Array[Dictionary] = scene.controller.try_retreat()

	assert_eq(GameSession.battle_reward, 0)
	assert_eq(GameSession.battle_gear, {})
	assert_eq(GameSession.battle_mana_crystals, {})
	assert_eq(emitted.size(), 1, "retreat_resolved must fire exactly once")
	assert_eq(emitted[0], results)


func test_try_retreat_is_a_no_op_outside_the_players_active_turn() -> void:
	var scene := _make_retreat_scene(2, 10)
	scene.controller.active_side = BattleControllerScript.Side.ENEMY

	var results: Array[Dictionary] = scene.controller.try_retreat()

	assert_eq(results, [] as Array[Dictionary])
	assert_eq(scene.player.health, 10, "A rejected retreat must not roll or apply any consequence")


func test_try_retreat_only_rolls_for_living_player_units() -> void:
	var scene := _make_retreat_scene(2, 10)
	var dead_ally = UnitScript.new(Vector2i(0, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	dead_ally.health = 0
	scene.controller.units.append(dead_ally)
	# An Array, not a plain int counter: GDScript lambdas capture an outer
	# local by value, so mutating a captured int inside the lambda would
	# never be visible out here -- but a captured Array/Dictionary still
	# refers to the same underlying object, so appending to it is.
	var roll_log: Array = []
	scene.controller.retreat_roll = func() -> float:
		roll_log.append(true)
		return 0.0

	var results: Array[Dictionary] = scene.controller.try_retreat()

	assert_eq(results.size(), 1, "Only the living unit produces a result")
	assert_eq(roll_log.size(), 1, "A dead unit must not consume a roll")


## --- Step 5: Final Boss (Ogre) ----------------------------------------------
## (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md)


## The Ogre encounter hydrates through the real production path (Battle-
## Controller._ready() reading GameSession.selected_encounter, same as
## test_ready_fields_up_to_eight_enemies_when_the_encounter_has_that_many())
## and fields exactly one Ogre unit whose stats match OGRE_ENEMY_STATS
## exactly -- no bespoke ability, cleave, or phase field exists anywhere on
## Unit, so "spells is empty" is the only assertion needed to prove it
## resolves through only standard monster action resolution.
func test_ogre_encounter_fields_exactly_one_ogre_via_standard_resolution() -> void:
	GameSession.selected_encounter = "obj_boss_borderlands_ogre"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)

	assert_eq(enemy_units.size(), 1, "The Ogre encounter fields exactly one boss unit")
	var ogre = enemy_units[0]
	assert_eq(ogre.max_health, GameSession.OGRE_ENEMY_STATS.max_health)
	assert_eq(ogre.damage_min, GameSession.OGRE_ENEMY_STATS.damage_min)
	assert_eq(ogre.damage_max, GameSession.OGRE_ENEMY_STATS.damage_max)
	assert_eq(ogre.hit_chance, GameSession.OGRE_ENEMY_STATS.hit_chance)
	assert_eq(ogre.defense, GameSession.OGRE_ENEMY_STATS.defense)
	assert_eq(ogre.resistance, GameSession.OGRE_ENEMY_STATS.resistance)
	assert_eq(ogre.spells, [] as Array, "The Ogre has no bespoke spells/abilities -- only standard monster action resolution")


## Builds a bare ScenarioContract fixture (default-geared, default-armed
## level-1 Warriors -- the exact calibration baseline docs/designs/
## monster-manual.md's own table uses) via BattleStateFactory, seeds it
## deterministically, and drives a full multi-round fight using the same
## BattleBot/run_enemy_turn()/end_turn() loop battle_sim.gd and test_battle_
## bot.gd already use for headless simulation.
func _build_four_warriors_vs_ogre_controller(root_seed: int) -> Node2D:
	var scenario := ScenarioContract.normalize({
		"scenario_id": "ogre_benchmark",
		"board": {"width": 6, "height": 6},
		"player": {"template_id": "warrior", "count": 4},
		"enemy": {"units": [{"id": "ogre", "template_id": "ogre", "position": {"x": 5, "y": 5}}]},
		"rules": {"round_limit": 40},
		"randomness": {"root_seed": root_seed, "iterations": 1},
	})
	var seed := ScenarioContract.derive_iteration_seed(root_seed, scenario.scenario_id, 0)
	return BattleStateFactory.build(scenario, seed)


## Runs full rounds (player turn, then enemy turn) until one side is wiped
## or MAX_ROUNDS is hit, returning the round count actually taken.
func _run_to_resolution(controller: Node2D, max_rounds: int) -> int:
	var rounds := 0
	while not controller.is_battle_won() and not controller.is_battle_lost() and rounds < max_rounds:
		rounds += 1
		BattleBot.take_player_turn(controller)
		controller.end_turn()
		if controller.is_battle_lost():
			break
		controller.run_enemy_turn()
		controller.end_turn()
	return rounds


## Derivation (see OGRE_ENEMY_STATS' own doc comment): a level-1 Warrior's
## default gear gives ~1.62 expected damage per landed swing against the
## Ogre's defense/resistance, and the Ogre's own attack deals ~3.44 expected
## damage per landed swing against a 10-HP Warrior -- a multi-round fight
## that is genuinely dangerous for four fresh Warriors, not a one-round
## curbstomp in either direction. Several independent seeds are checked so
## the power band is evidence about the tuning, not one lucky roll sequence.
##
## Regression for the Step 5 review's Finding 3: this test previously only
## asserted the fight resolves within a loose 2-20 round window, never
## checking WHO wins -- a regression that halved or doubled the Ogre's
## stats would still have passed. Instrumenting the real outcome (done while
## fixing this finding) shows all 5 of the seeds below resolve as an Ogre
## victory: this bare, ungeared four-Warrior baseline (the Monster Manual's
## own calibration convention -- explicitly NOT the real endgame party that
## actually fights this boss, see OGRE_ENEMY_STATS' doc comment) never wins
## the fight, though only after grinding the Ogre down to a fraction of its
## health (12-46 of 90 across these 5 seeds) -- a hard-fought multi-round
## loss, not an untouched stomp. Whether a bare 4-Warrior baseline should
## legitimately win some fraction of the time is a tuning call for Step 6's
## balance harness (or an explicit design decision) to make, not something
## to silently resolve here by retuning OGRE_ENEMY_STATS underneath this
## fix. What this test pins instead is today's actual power band: every
## seed must still be a real, hard-fought loss -- neither an untouched
## curbstomp (Ogre ends near full health) nor a near-miss (Ogre ends almost
## dead) -- so a future regression that trivializes the Ogre, or one that
## makes it unbeatably dominant, is caught either way.
func test_ogre_seeded_four_warrior_benchmark_falls_within_the_agreed_power_band() -> void:
	for root_seed in [1001, 2002, 3003, 4004, 5005]:
		var controller := _build_four_warriors_vs_ogre_controller(root_seed)
		autofree(controller)

		var rounds := _run_to_resolution(controller, 40)

		assert_true(
			controller.is_battle_won() or controller.is_battle_lost(),
			"seed %d: the benchmark must resolve, not stalemate at the round cap" % root_seed
		)
		assert_true(
			rounds >= 8 and rounds <= 12,
			(
				"seed %d: the fight must resolve within the actually-observed 8-12 round band, not the old loose 2-20 (took %d rounds)"
				% [root_seed, rounds]
			)
		)
		assert_true(
			controller.is_battle_lost(),
			(
				"seed %d: today's tuning has the bare 4-Warrior calibration baseline losing every seed -- a flip to a Warrior win here is itself a tuning change worth reviewing deliberately, not one that should silently start passing"
				% root_seed
			)
		)
		var ogre_health := -1
		for unit in controller.units:
			if unit.side == BattleControllerScript.Side.ENEMY:
				ogre_health = int(unit.health)
		assert_true(
			ogre_health >= 5 and ogre_health <= 60,
			(
				"seed %d: the Ogre must end the fight meaningfully damaged (ruling out an untouched curbstomp) but still clearly standing (ruling out a near-miss loss), ended at %d/90 HP"
				% [root_seed, ogre_health]
			)
		)


## Defeating the final boss must complete its authored objective -- flipping
## campaign victory -- exactly once, even if this were somehow reached
## again (it cannot be, in real play, since a completed authored encounter
## never reopens -- see can_enter_encounter()).
func test_defeating_the_ogre_triggers_campaign_victory_once() -> void:
	GameSession.unlocked_authored_encounters.assign(GameSession.CAMPAIGN_OBJECTIVES.keys())
	GameSession.completed_objectives.assign(GameSession.CAMPAIGN_OBJECTIVES.keys())
	GameSession.completed_objectives.erase("obj_boss_borderlands_ogre")
	GameSession.campaign_objective_id = "obj_boss_borderlands_ogre"
	GameSession.selected_encounter = "obj_boss_borderlands_ogre"
	watch_signals(GameSession)

	GameSession.complete_current_encounter()

	assert_signal_emit_count(GameSession, "campaign_victory", 1)
	assert_true(GameSession.is_campaign_completed)
	assert_true(GameSession.is_free_play_active)

	# A repeated call (selected_encounter is already cleared, matching the
	# real post-victory state) must never emit a second time.
	GameSession.selected_encounter = "obj_boss_borderlands_ogre"
	GameSession.complete_current_encounter()

	assert_signal_emit_count(GameSession, "campaign_victory", 1)




## --- Floating Combat Text (Technical Design §2, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md) ---
## combat_text_spawned is asserted directly against a bare (non-tree)
## controller, the same _make_controller() pattern every other test in this
## file uses -- _spawn_combat_text() emits the signal unconditionally and
## only additionally drives a pooled FloatingText node when is_inside_tree()
## (see battle_controller.gd's own doc comment on that guard), so a bare
## controller is sufficient to prove the presentation hook fires with the
## right position/text/type.

func test_a_landed_hit_spawns_red_damage_text_over_the_defender() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 2
	watch_signals(controller)

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	var expected_pos: Vector2 = controller._floating_text_anchor(defender)
	assert_signal_emitted_with_parameters(
		controller, "combat_text_spawned",
		[expected_pos, tr("battle.floating.damage") % controller.last_attack_result.damage, "damage"]
	)


func test_a_critical_hit_spawns_golden_crit_text() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 4, 4)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 20)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 0.0
	watch_signals(controller)

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_true(controller.last_attack_result.critical)
	var expected_pos: Vector2 = controller._floating_text_anchor(defender)
	assert_signal_emitted_with_parameters(
		controller, "combat_text_spawned",
		[expected_pos, tr("battle.floating.critical") % controller.last_attack_result.damage, "critical"]
	)


func test_a_missed_attack_spawns_gray_miss_text() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2, 0.5)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99
	watch_signals(controller)

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_false(controller.last_attack_result.get("hit", true))
	var expected_pos: Vector2 = controller._floating_text_anchor(defender)
	assert_signal_emitted_with_parameters(
		controller, "combat_text_spawned", [expected_pos, tr("battle.floating.miss"), "miss"]
	)


func test_using_a_healing_potion_spawns_green_heal_text_over_the_user() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID
	)
	holder.health = 4
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum
	controller.units = [holder]
	controller.selected_unit = holder
	watch_signals(controller)

	assert_true(controller.try_use_selected_potion("healing_potion"))

	var expected_pos: Vector2 = controller._floating_text_anchor(holder)
	assert_signal_emitted_with_parameters(
		controller, "combat_text_spawned", [expected_pos, tr("battle.floating.heal") % 6, "heal"]
	)


func test_casting_heal_spawns_green_heal_text_over_the_target() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum
	watch_signals(controller)

	assert_true(controller.try_cast_spell("heal", ally.grid_position))

	var expected_pos: Vector2 = controller._floating_text_anchor(ally)
	assert_signal_emitted_with_parameters(
		controller, "combat_text_spawned", [expected_pos, tr("battle.floating.heal") % 8, "heal"]
	)


## --- Sound Effect Triggers (Task 2, docs/plans/2026-08-18-core-loop-and-
## engagement/08-audio-system-and-soundscape.md) --- every combat-feedback
## event that spawns floating text also plays a matching SFX via the same
## _spawn_combat_text() entry point (see COMBAT_TEXT_SFX_IDS); unit death is
## its own hook right where try_attack_selected_unit() detects it. A bare
## (non-tree) controller is sufficient here too -- AudioManager is a real
## autoload, reachable regardless of whether the controller itself is
## inside a scene tree.

func test_a_landed_hit_plays_the_hit_impact_sfx() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 2

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_eq(AudioManager.last_sfx_id, "sfx_hit_impact")


func test_a_critical_hit_plays_the_crit_impact_sfx() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 4, 4)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 20)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_eq(AudioManager.last_sfx_id, "sfx_crit_impact")


func test_a_missed_attack_plays_the_miss_sfx() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2, 0.5)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_eq(AudioManager.last_sfx_id, "sfx_miss")


func test_casting_heal_plays_the_spell_heal_sfx() -> void:
	var controller := _make_controller(6, 6)
	var caster = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	caster.spells = ["heal"]
	caster.mp_max = 3
	caster.mp_remaining = 3
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	ally.health = 4
	controller.units = [caster, ally]
	controller.selected_unit = caster
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum

	assert_true(controller.try_cast_spell("heal", ally.grid_position))

	assert_eq(AudioManager.last_sfx_id, "sfx_spell_heal")


func test_a_kill_plays_the_unit_death_sfx() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 20, 100, 100)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 1)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.crit_roll = func() -> float: return 1.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))

	assert_true(controller.last_attack_result.defeated)
	assert_eq(AudioManager.last_sfx_id, "sfx_unit_death")
