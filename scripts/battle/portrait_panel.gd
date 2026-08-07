extends Control

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const PORTRAIT_SIZE := 48
const DEFEATED_MODULATE := Color(1, 1, 1, 0.35)
const SELECTED_MODULATE := Color(1, 1, 1, 1)

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
	var member_ids: Array = GameSession.get_selected_party().get("member_ids", [])
	for index in member_ids.size():
		rows.add_child(_build_row(index, member_ids[index]))


func _build_row(index: int, adventurer_id: String) -> Button:
	var unit = _find_unit(adventurer_id)
	var row := Button.new()
	row.name = "Portrait%d" % index
	row.flat = true
	row.pressed.connect(func() -> void: grid.select_unit_by_adventurer_id(adventurer_id))
	row.modulate = SELECTED_MODULATE if unit != null else DEFEATED_MODULATE

	var hbox := HBoxContainer.new()
	row.add_child(hbox)

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	swatch.color = BattleControllerScript.PLAYER_COLORS[index % BattleControllerScript.PLAYER_COLORS.size()]
	hbox.add_child(swatch)

	var health_label := Label.new()
	health_label.name = "Health"
	health_label.text = (
		"%d/%d" % [unit.health, unit.max_health] if unit != null
		else tr("battle.status.defeated") % GameSession.get_adventurer(adventurer_id).get("name", "")
	)
	hbox.add_child(health_label)

	var ring := ColorRect.new()
	ring.name = "SelectionRing"
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
