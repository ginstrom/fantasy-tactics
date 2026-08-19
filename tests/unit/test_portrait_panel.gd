extends GutTest

## Wound State Visual Indicators (Technical Design §3, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md) --
## PortraitPanel half (the left party-portrait column). See
## test_unit_info_panel.gd for the right-hand dual inspection panel's own
## coverage of the same concept.

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const PortraitPanelScript := preload("res://scripts/battle/portrait_panel.gd")


func before_each() -> void:
	GameSession.reset()


func _first_row(battlefield: Node2D) -> Control:
	return battlefield.portrait_panel.get_node("Rows/Portrait0")


func _fill(row: Control) -> ColorRect:
	return row.find_child("HealthBarFill", true, false)


func _badge(row: Control) -> Label:
	return row.find_child("WoundBadge", true, false)


func test_a_healthy_member_shows_a_green_bar_and_no_wound_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.health = warrior.max_health
	battlefield.portrait_panel.refresh()

	var row := _first_row(battlefield)
	assert_eq(_fill(row).color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_HEALTHY])
	assert_false(_badge(row).visible)


## The Wounded band is 50%-21% HP (Technical Design §3): exactly 50% is its
## upper (inclusive) edge.
func test_a_member_at_exactly_fifty_percent_health_shows_the_wounded_bar_and_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 10
	warrior.health = 5

	battlefield.portrait_panel.refresh()

	var row := _first_row(battlefield)
	assert_eq(_fill(row).color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_WOUNDED])
	assert_true(_badge(row).visible)
	assert_eq(_badge(row).text, WoundVisuals.WOUND_BADGE_GLYPHS[WoundVisuals.TIER_WOUNDED])


## 51% must stay Healthy -- confirms the Wounded band's inclusive edge is
## exactly 50%, not "51% and below" or some other off-by-one.
func test_a_member_at_fifty_one_percent_health_stays_in_the_healthy_band() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 100
	warrior.health = 51

	battlefield.portrait_panel.refresh()

	var row := _first_row(battlefield)
	assert_eq(_fill(row).color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_HEALTHY])
	assert_false(_badge(row).visible)


## The Critical band is 20%-1% HP: exactly 20% is its upper (inclusive) edge,
## and a Critical bar is additionally flagged for the pulse animation.
func test_a_member_at_twenty_percent_health_shows_the_critical_bar_badge_and_pulse_flag() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 100
	warrior.health = 20

	battlefield.portrait_panel.refresh()

	var row := _first_row(battlefield)
	var fill := _fill(row)
	assert_eq(fill.color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_CRITICAL])
	assert_true(_badge(row).visible)
	assert_eq(_badge(row).text, WoundVisuals.WOUND_BADGE_GLYPHS[WoundVisuals.TIER_CRITICAL])
	assert_true(fill.get_meta("pulsing", false), "A Critical-tier bar must be flagged for the pulse animation")


func test_a_defeated_member_shows_the_slain_badge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	battlefield.grid.units.erase(warrior)

	battlefield.portrait_panel.refresh()

	var badge := _badge(_first_row(battlefield))
	assert_true(badge.visible)
	assert_eq(badge.text, WoundVisuals.WOUND_BADGE_GLYPHS[WoundVisuals.TIER_SLAIN])


## Damage applied mid-battle must be reflected immediately once the panel is
## refreshed, the same "UI updates immediately" contract the plan's own task
## list calls for.
func test_refresh_updates_the_bar_and_badge_immediately_after_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.max_health = 10
	warrior.health = 10
	battlefield.portrait_panel.refresh()
	assert_eq(_fill(_first_row(battlefield)).color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_HEALTHY])

	warrior.health = 1
	battlefield.portrait_panel.refresh()

	assert_eq(_fill(_first_row(battlefield)).color, WoundVisuals.HEALTH_BAR_COLORS[WoundVisuals.TIER_CRITICAL])
