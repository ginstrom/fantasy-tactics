extends Node2D

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SIDE_NAME_KEYS := {0: "battle.side.player", 1: "battle.side.enemy"}
const ENEMY_TURN_BEAT_SECONDS := 0.5

@onready var hint: Label = $HUD/Hint
@onready var status: Label = $HUD/Status
@onready var player_health: Label = $HUD/PlayerHealth
@onready var enemy_health: Label = $HUD/EnemyHealth
@onready var round_label: Label = $HUD/RoundLabel
@onready var end_turn_button: Button = $HUD/EndTurnButton
@onready var grid: Node2D = $Grid

var enemy_turn_beat_seconds: float = ENEMY_TURN_BEAT_SECONDS
var round_number: int = 1
var _enemy_turn_in_progress: bool = false
var _battle_resolved: bool = false


func _ready() -> void:
	_on_board_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_end_turn_pressed() -> void:
	if _enemy_turn_in_progress or _battle_resolved:
		return
	grid.end_turn()
	_play_enemy_turn()


func _play_enemy_turn() -> void:
	_set_enemy_turn_in_progress(true)
	status.text = tr("battle.status.enemy_turn")
	var steps: Array = grid.run_enemy_turn()
	for step in steps:
		grid._draw_units()
		grid._update_highlights()
		status.text = _describe_step(step)
		await get_tree().create_timer(enemy_turn_beat_seconds).timeout

	if grid.is_battle_lost():
		_resolve_battle(false)
		return

	grid.end_turn()
	round_number += 1
	_set_enemy_turn_in_progress(false)
	_on_board_changed()


func _on_board_changed() -> void:
	if _battle_resolved:
		return

	var side_name: String = tr(SIDE_NAME_KEYS[grid.active_side])
	var selected_unit = grid.selected_unit
	if selected_unit == null:
		hint.text = tr("battle.hint.select_unit") % side_name
	elif selected_unit.has_moved and selected_unit.has_acted:
		hint.text = tr("battle.hint.turn_complete") % side_name
	elif selected_unit.has_moved:
		hint.text = tr("battle.hint.already_moved") % side_name
	else:
		hint.text = tr("battle.hint.select_destination") % side_name

	round_label.text = tr("battle.round") % round_number
	_update_health_labels()
	if not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)

	if grid.is_battle_won():
		_resolve_battle(true)


func _resolve_battle(victory: bool) -> void:
	_show_battle_result(victory)
	await get_tree().create_timer(enemy_turn_beat_seconds).timeout
	_apply_battle_outcome(victory)


func _show_battle_result(victory: bool) -> void:
	_battle_resolved = true
	_set_enemy_turn_in_progress(true)
	status.text = _victory_message() if victory else tr("battle.result.defeat")


func _victory_message() -> String:
	# Captured before GameManager.complete_battle() clears selected_encounter.
	# Scene-isolated tests instantiate the battlefield with no selected
	# encounter; fall back to the Goblin Camp, matching
	# BattleController._get_enemy_stats()'s fallback.
	var encounter_id: String = GameSession.selected_encounter
	if encounter_id == "":
		encounter_id = GameSession.GOBLIN_CAMP_ID
	var expedition := GameSession.get_expedition(encounter_id)
	return tr("battle.result.victory") % tr(expedition.name_key)


func _apply_battle_outcome(victory: bool) -> void:
	if victory:
		GameManager.complete_battle()
	else:
		GameManager.fail_battle()


func _set_enemy_turn_in_progress(value: bool) -> void:
	_enemy_turn_in_progress = value
	end_turn_button.disabled = value
	grid.input_locked = value


func _describe_step(step: Dictionary) -> String:
	if step.type == "attack":
		var attacker_name: String = tr(SIDE_NAME_KEYS[step.attacker.side])
		if step.hit:
			return tr("battle.status.hit") % [attacker_name, step.damage]
		return tr("battle.status.miss") % attacker_name

	var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
	return tr("battle.status.enemy_move") % mover_name


func _update_health_labels() -> void:
	player_health.text = _format_health(
		tr("battle.side.player"), _find_unit_by_side(BattleControllerScript.Side.PLAYER)
	)
	enemy_health.text = _format_health(
		tr("battle.side.enemy"), _find_unit_by_side(BattleControllerScript.Side.ENEMY)
	)


func _find_unit_by_side(side: int):
	for unit in grid.units:
		if unit.side == side:
			return unit
	return null


func _format_health(label: String, unit) -> String:
	if unit == null or not unit.is_alive():
		return tr("battle.status.defeated") % label
	return tr("battle.status.health") % [label, unit.health, unit.max_health]
