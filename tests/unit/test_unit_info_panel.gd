extends GutTest

## Wound State Visual Indicators (Technical Design §3, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md) --
## UnitInfoPanel half (the right-hand dual hover/selected inspection panel).
## See test_portrait_panel.gd for the left-hand party-portrait column's own
## coverage of the same concept.

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const UnitInfoPanelScript := preload("res://scripts/battle/unit_info_panel.gd")


func before_each() -> void:
	GameSession.reset()


func _panel(battlefield: Node2D) -> Control:
	return battlefield.unit_info_panel


func _selected_fill(panel: Control) -> ColorRect:
	return panel.get_node("Content/SelectedSection/HealthBar/Fill")


func _selected_badge(panel: Control) -> Label:
	return panel.get_node("Content/SelectedSection/WoundBadge")


func _hovered_fill(panel: Control) -> ColorRect:
	return panel.get_node("Content/HoveredSection/HealthBar/Fill")


func _hovered_badge(panel: Control) -> Label:
	return panel.get_node("Content/HoveredSection/WoundBadge")


func _setup_two_member_party() -> String:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.recruit_adventurer()
	var second_member_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(second_member_id)
	return second_member_id


func test_selected_healthy_player_shows_a_green_bar_and_no_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.health = warrior.max_health

	battlefield.grid._select_unit(warrior)

	var panel := _panel(battlefield)
	assert_eq(_selected_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_HEALTHY])
	assert_false(_selected_badge(panel).visible)


## The Wounded band is 50%-21% HP: exactly 50% is its upper (inclusive)
## edge, and the selected (always player) section shows the exact fraction.
func test_selected_player_at_fifty_percent_health_shows_the_wounded_bar_and_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 10
	warrior.health = 5

	battlefield.grid._select_unit(warrior)

	var panel := _panel(battlefield)
	assert_eq(_selected_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_WOUNDED])
	assert_true(_selected_badge(panel).visible)
	assert_eq(_selected_badge(panel).text, UnitInfoPanelScript.WOUND_BADGE_GLYPHS[UnitInfoPanelScript.TIER_WOUNDED])
	assert_almost_eq(_selected_fill(panel).size.x, UnitInfoPanelScript.HEALTH_BAR_WIDTH * 0.5, 0.01)


## The Critical band is 20%-1% HP: exactly 20% is its upper (inclusive)
## edge, and it additionally starts a looping pulse tween on the bar.
func test_selected_player_at_twenty_percent_health_shows_the_critical_bar_badge_and_starts_pulsing() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 100
	warrior.health = 20

	battlefield.grid._select_unit(warrior)

	var panel := _panel(battlefield)
	assert_eq(_selected_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_CRITICAL])
	assert_true(_selected_badge(panel).visible)
	assert_eq(_selected_badge(panel).text, UnitInfoPanelScript.WOUND_BADGE_GLYPHS[UnitInfoPanelScript.TIER_CRITICAL])
	assert_not_null(panel._selected_pulse_tween, "Critical tier must start a pulse tween on the bar")
	assert_true(is_instance_valid(panel._selected_pulse_tween) and panel._selected_pulse_tween.is_valid())


func test_selected_bar_stops_pulsing_once_healed_back_above_the_critical_band() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 100
	warrior.health = 20
	battlefield.grid._select_unit(warrior)
	assert_not_null(_panel(battlefield)._selected_pulse_tween)

	warrior.health = 100
	battlefield._on_board_changed()

	assert_null(_panel(battlefield)._selected_pulse_tween)


## An enemy's hovered bar must never leak more precision than the existing
## text tier already withholds (_wound_tier_key() only ever says "Healthy"/
## "Wounded"/"Badly Wounded", never a number) -- two different health values
## inside the same tier band must render the identical, coarse bar width.
func test_hovered_enemy_bar_uses_a_fixed_tier_width_not_the_exact_health_fraction() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.max_health = 100

	goblin.health = 60  # Healthy band (>50%)
	battlefield.grid._set_hovered_unit(goblin)
	var width_at_60: float = _hovered_fill(_panel(battlefield)).size.x

	goblin.health = 90  # Still Healthy band
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	var width_at_90: float = _hovered_fill(_panel(battlefield)).size.x

	assert_eq(width_at_60, width_at_90, "Both healths sit in the same tier, so the coarse bar must not distinguish them")
	assert_almost_eq(width_at_60, UnitInfoPanelScript.HEALTH_BAR_WIDTH, 0.01)


func test_hovered_ally_bar_uses_the_exact_health_fraction() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var first_member = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var second_member = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])
	second_member.max_health = 10
	second_member.health = 3

	battlefield.grid._select_unit(first_member)
	battlefield.grid._set_hovered_unit(second_member)

	assert_almost_eq(_hovered_fill(_panel(battlefield)).size.x, UnitInfoPanelScript.HEALTH_BAR_WIDTH * 0.3, 0.01)


func test_hovered_unit_at_zero_health_shows_the_slain_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.health = 0

	battlefield.grid._set_hovered_unit(goblin)

	var badge := _hovered_badge(_panel(battlefield))
	assert_true(badge.visible)
	assert_eq(badge.text, UnitInfoPanelScript.WOUND_BADGE_GLYPHS[UnitInfoPanelScript.TIER_SLAIN])


## Both halves of the panel update immediately on damage/heal -- the same
## "UI updates immediately" contract the plan's own task list calls for
## (mirrors test_battlefield.gd's identically-named HP/wound-tier coverage).
func test_hovered_and_selected_bars_update_immediately_on_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var panel := _panel(battlefield)

	warrior.max_health = 10
	warrior.health = 10
	goblin.max_health = 100
	goblin.health = 100
	battlefield.grid._select_unit(warrior)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(_selected_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_HEALTHY])
	assert_eq(_hovered_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_HEALTHY])

	warrior.health = 1
	goblin.health = 10  # 10% of 100 -- Critical band
	battlefield._on_board_changed()

	assert_eq(_selected_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_CRITICAL])
	assert_eq(_hovered_fill(panel).color, UnitInfoPanelScript.HEALTH_BAR_COLORS[UnitInfoPanelScript.TIER_CRITICAL])
