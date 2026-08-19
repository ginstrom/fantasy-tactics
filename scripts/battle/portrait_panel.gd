extends Control

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const PORTRAIT_SIZE := 48
const DEFEATED_MODULATE := Color(1, 1, 1, 0.35)
const LIVING_MODULATE := Color(1, 1, 1, 1)
const HEALTH_LABEL_HEIGHT := 16
const HEALTH_BACKING_COLOR := Color(0, 0, 0, 0.55)

## Visual wound-tier thresholds (Technical Design §3, docs/plans/2026-08-18-
## core-loop-and-engagement/07-visual-perspective-and-tactical-polish.md):
## Healthy 100-51% HP, Wounded 50-21%, Critical 20-1%, Slain 0.
const WOUND_TIER_HEALTHY := "healthy"
const WOUND_TIER_WOUNDED := "wounded"
const WOUND_TIER_CRITICAL := "critical"
const WOUND_TIER_SLAIN := "slain"
const WOUNDED_HEALTH_FRACTION := 0.50
const CRITICAL_HEALTH_FRACTION := 0.20
const HEALTH_BAR_COLORS := {
	WOUND_TIER_HEALTHY: Color(0.3, 0.8, 0.3),
	WOUND_TIER_WOUNDED: Color(0.9, 0.65, 0.15),
	WOUND_TIER_CRITICAL: Color(0.85, 0.15, 0.15),
}
## Placeholder glyph badges -- see unit_info_panel.gd's identical constant
## for the same reasoning (this step has design latitude on exact
## iconography): a diamond stands in for a blood drop (Wounded), a double
## exclamation for severe trauma (Critical), and a skull for Slain.
const WOUND_BADGE_GLYPHS := {
	WOUND_TIER_WOUNDED: "♦",
	WOUND_TIER_CRITICAL: "‼",
	WOUND_TIER_SLAIN: "☠",
}
const PULSE_MIN_ALPHA := 0.35
const PULSE_DURATION := 0.5

@onready var rows: VBoxContainer = $Rows

var grid: Node2D


func refresh() -> void:
	# remove_child() (not just queue_free()) so a synchronous re-entrant
	# refresh() (e.g. triggered by board_changed while an earlier refresh's
	# queued frees haven't run yet) never sees stale rows still parented
	# under Rows — queue_free() alone only detaches at end of frame, which
	# would leave duplicate same-named rows and make get_node() resolve to
	# the stale one.
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	# Read from the board's own authoritative fielded-unit list rather than
	# re-deriving from GameSession: grid._player_adventurer_ids is what was
	# actually fielded (uncapped; only the separate `units` array is capped
	# by PLAYER_START_POSITIONS.size()), so the row list can never drift
	# from the board. This also means _find_unit() == null can only mean
	# "defeated" here, never "never fielded".
	var member_ids: Array = grid._player_adventurer_ids
	for index in member_ids.size():
		rows.add_child(_build_row(index, member_ids[index]))
	_start_critical_pulses()


func _build_row(index: int, adventurer_id: String) -> Button:
	var unit = _find_unit(adventurer_id)
	var row := Button.new()
	row.name = "Portrait%d" % index
	row.flat = true
	# Without an explicit minimum size, a childless-of-text Button collapses
	# to a few px and its clickable rect no longer matches the swatch/label
	# content the HBoxContainer child paints on top of it.
	row.custom_minimum_size = Vector2(0, PORTRAIT_SIZE)
	row.pressed.connect(func() -> void: grid.select_unit_by_adventurer_id(adventurer_id))
	row.modulate = LIVING_MODULATE if unit != null else DEFEATED_MODULATE

	# Purely decorative children default to MOUSE_FILTER_STOP, which would
	# otherwise claim the click for themselves and never let it reach the
	# Button beneath — set IGNORE so the row itself stays the click target.
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	var swatch_stack := Control.new()
	swatch_stack.name = "SwatchStack"
	swatch_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch_stack.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	hbox.add_child(swatch_stack)

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	swatch.color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	swatch_stack.add_child(swatch)

	var health_backing := ColorRect.new()
	health_backing.name = "HealthBacking"
	health_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_backing.color = HEALTH_BACKING_COLOR
	health_backing.position = Vector2(0, PORTRAIT_SIZE - HEALTH_LABEL_HEIGHT)
	health_backing.size = Vector2(PORTRAIT_SIZE, HEALTH_LABEL_HEIGHT)
	swatch_stack.add_child(health_backing)

	var tier: String = _wound_tier(unit.health, unit.max_health) if unit != null else WOUND_TIER_SLAIN
	var health_fraction: float = (
		clampf(float(unit.health) / float(unit.max_health), 0.0, 1.0)
		if unit != null and unit.max_health > 0 else 0.0
	)
	var health_bar_fill := ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_fill.position = Vector2(0, PORTRAIT_SIZE - HEALTH_LABEL_HEIGHT)
	health_bar_fill.size = Vector2(PORTRAIT_SIZE * health_fraction, HEALTH_LABEL_HEIGHT)
	health_bar_fill.color = HEALTH_BAR_COLORS.get(tier, HEALTH_BAR_COLORS[WOUND_TIER_HEALTHY])
	health_bar_fill.set_meta("pulsing", tier == WOUND_TIER_CRITICAL)
	swatch_stack.add_child(health_bar_fill)

	var health_label := Label.new()
	health_label.name = "Health"
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.position = Vector2(0, PORTRAIT_SIZE - HEALTH_LABEL_HEIGHT)
	health_label.size = Vector2(PORTRAIT_SIZE, HEALTH_LABEL_HEIGHT)
	health_label.text = (
		"%d/%d" % [unit.health, unit.max_health] if unit != null
		else tr("battle.status.defeated") % GameSession.get_adventurer(adventurer_id).get("name", "")
	)
	swatch_stack.add_child(health_label)

	var wound_badge := Label.new()
	wound_badge.name = "WoundBadge"
	wound_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wound_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wound_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wound_badge.position = Vector2(PORTRAIT_SIZE - 16, 0)
	wound_badge.size = Vector2(16, 16)
	wound_badge.add_theme_font_size_override("font_size", 14)
	wound_badge.visible = tier != WOUND_TIER_HEALTHY
	wound_badge.text = WOUND_BADGE_GLYPHS.get(tier, "")
	swatch_stack.add_child(wound_badge)

	var ring := ColorRect.new()
	ring.name = "SelectionRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.custom_minimum_size = Vector2(4, PORTRAIT_SIZE)
	ring.color = Color.WHITE
	ring.visible = unit != null and grid.selected_unit == unit
	hbox.add_child(ring)

	return row


func _find_unit(adventurer_id: String):
	for unit in grid.units:
		if unit.adventurer_id == adventurer_id:
			return unit
	return null


func _wound_tier(health: int, max_health: int) -> String:
	if health <= 0:
		return WOUND_TIER_SLAIN
	if max_health <= 0:
		return WOUND_TIER_CRITICAL
	var fraction: float = float(health) / float(max_health)
	if fraction <= CRITICAL_HEALTH_FRACTION:
		return WOUND_TIER_CRITICAL
	if fraction <= WOUNDED_HEALTH_FRACTION:
		return WOUND_TIER_WOUNDED
	return WOUND_TIER_HEALTHY


## Tween creation needs the node inside the SceneTree, which a row built in
## _build_row() isn't yet (it's parented afterward, in refresh()) -- so
## pulsing starts in a second pass over the now-parented rows instead of
## inline in _build_row().
func _start_critical_pulses() -> void:
	for row in rows.get_children():
		var fill: ColorRect = row.find_child("HealthBarFill", true, false)
		if fill != null and fill.get_meta("pulsing", false):
			_pulse(fill)


func _pulse(node: ColorRect) -> void:
	if not node.is_inside_tree():
		return
	var tween := node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION)
	tween.tween_property(node, "modulate:a", 1.0, PULSE_DURATION)
