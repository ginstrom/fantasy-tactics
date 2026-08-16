extends Node2D

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SIDE_NAME_KEYS := {0: "battle.side.player", 1: "battle.side.enemy"}
const ENEMY_TURN_BEAT_SECONDS := 0.5

@onready var hint: Label = %Hint
@onready var status: Label = %Status
@onready var enemy_health: VBoxContainer = %EnemyHealth
@onready var log_list: VBoxContainer = %Log
@onready var log_scroll: ScrollContainer = $HUD/Margin/VBox/BottomPanel/BottomContent/ScrollRow/LogScroll
@onready var round_label: Label = %RoundLabel
@onready var action_points_label: Label = %ActionPointsLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var move_button: Button = %MoveButton
@onready var attack_button: Button = %AttackButton
@onready var potion_option: OptionButton = %PotionOption
@onready var use_potion_button: Button = %UsePotionButton
@onready var transfer_item_option: OptionButton = %TransferItemOption
@onready var recipient_option: OptionButton = %RecipientOption
@onready var transfer_button: Button = %TransferButton
@onready var grid: Node2D = $Grid
@onready var level_up: Control = $HUD/LevelUp
@onready var portrait_panel: Control = %PortraitPanel
@onready var unit_info_panel: Control = %UnitInfoPanel

var enemy_turn_beat_seconds: float = ENEMY_TURN_BEAT_SECONDS
var round_number: int = 1
var _enemy_turn_in_progress: bool = false
var _battle_resolved: bool = false
# Level-up queue state (see _queue_level_up/_show_next_level_up below). A
# leveled-up party member is queued as {"id": adventurer_id, "health_before":
# int} so the overlay can show the health gained even though GameSession has
# already applied it by the time the entry is queued.
var _level_up_queue: Array[Dictionary] = []
var _level_up_active: bool = false
# Set when a victory's clear-XP award queues at least one level-up: defers
# _finish_victory() (the battle-result scene transition) until every queued
# level-up — kill-triggered or clear-triggered — has resolved.
var _pending_victory_completion: bool = false
# Per-instance award guards (see _award_kill_xp/_award_clear_xp): a
# Battlefield is re-instantiated for every battle, so these cannot leak
# across encounter attempts, but they do stop a repeated event (a duplicate
# board refresh, or a repeated result-timer fire) from awarding XP twice for
# the same kill or the same clear.
# enemy_defeated now fires once per defeated enemy (a battle can field
# multiple enemies), so the kill-XP guard tracks every already-awarded Unit
# by reference rather than a single "already awarded this battle" flag —
# that still blocks a repeated event for the SAME kill while allowing every
# distinct kill in the battle to award XP.
var _kill_xp_awarded_units: Array = []
var _clear_xp_awarded: bool = false
# Populated over the course of the battle for the victory summary screen
# (see _finish_victory()). Keyed by Unit.enemy_type_name (Step 2) rather
# than display_name, since the summary groups "2 Goblins", not "Goblin 1"
# and "Goblin 2" separately -- and a battle only ever fields one enemy
# species (see GameSession.STAR_ENEMY_COMPOSITIONS), so this dict never
# holds more than one key in practice today.
var _kills_by_type: Dictionary = {}
# Every _award_party_xp() call (kill or clear) adds its amount here, so the
# summary can show a true battle total regardless of how many separate
# awards produced it.
var _total_xp_awarded: float = 0.0
# Deduplicated: a member can level up once from a kill-triggered award and
# again from the clear-triggered award in the same battle (each call to
# GameSession.award_party_xp() only reports members who crossed a
# threshold *during that call*), so this must not just concatenate.
var _leveled_up_ids: Array[String] = []
# Identity guard so a repeated board_changed event for the same attack (see
# _on_board_changed()) can't append the same log line twice. Compared with
# is_same() rather than == because try_attack_selected_unit() always
# assigns last_attack_result a brand-new Dictionary literal per attack, so
# reference identity alone already distinguishes "already logged this" from
# "a genuinely new attack" -- no need to compare field-by-field.
var _last_logged_attack_result: Dictionary = {}


func _ready() -> void:
	grid.enemy_defeated.connect(_award_kill_xp)
	grid.unit_focus_changed.connect(_on_unit_focus_changed)
	grid.action_mode_changed.connect(_on_action_mode_changed)
	level_up.resolved.connect(_on_level_up_resolved)
	portrait_panel.grid = grid
	_on_board_changed()
	# BattleController._ready() already selects the first living party member
	# (selected_unit/inspected_unit), but that happens before this node's own
	# _ready() runs, so the unit_focus_changed connection above didn't exist
	# yet to pick it up. Sync the panel explicitly now, the same way
	# _on_board_changed() is called explicitly above.
	_on_unit_focus_changed(grid.get_focused_unit())
	# Same reasoning as above: _select_unit() already reset action_mode to
	# CONTEXTUAL before this node's own _ready() ran, so the action_mode_
	# changed connection above didn't exist yet to pick it up.
	_on_action_mode_changed(grid.action_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_end_turn_pressed() -> void:
	if _enemy_turn_in_progress or _battle_resolved:
		return
	grid.end_turn()
	_play_enemy_turn()


## set_action_mode() no-ops (and so never re-emits action_mode_changed) when
## the requested mode is already active. But MoveButton/AttackButton use
## Godot's native toggle_mode, which unconditionally flips button_pressed on
## every click regardless of app state -- so a repeat click on the already-
## active button flips its visual state to unpressed with nothing left to
## correct it. Resyncing unconditionally after every press (not just when
## the mode actually changed) keeps the highlight tied to the true
## action_mode instead of Godot's independent toggle bookkeeping.
func _on_move_button_pressed() -> void:
	grid.set_action_mode(BattleControllerScript.ActionMode.MOVE)
	_on_action_mode_changed(grid.action_mode)


func _on_attack_button_pressed() -> void:
	grid.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	_on_action_mode_changed(grid.action_mode)


## Only the active-mode highlight lives here -- disabled state is driven
## separately by _update_action_bar(), since it depends on the selected
## unit's AP and the input lock, neither of which action_mode_changed alone
## reflects.
func _on_action_mode_changed(mode: int) -> void:
	move_button.button_pressed = mode == BattleControllerScript.ActionMode.MOVE
	attack_button.button_pressed = mode == BattleControllerScript.ActionMode.ATTACK


## Move requires at least one AP (its own cost); Attack requires enough AP
## for a basic attack -- so on low AP, Move can stay enabled while Attack
## disables first (Attack's cost is strictly higher). Both disable while
## input is locked (enemy turn / a queued level-up), matching End Turn.
func _update_action_bar() -> void:
	var selected_unit = grid.selected_unit
	var can_act: bool = (
		selected_unit != null
		and selected_unit.side == BattleControllerScript.Side.PLAYER
		and selected_unit.is_alive()
		and not grid.input_locked
	)
	move_button.disabled = not can_act or selected_unit.action_points_remaining < BattleControllerScript.MOVE_ACTION_POINT_COST
	attack_button.disabled = not can_act or selected_unit.action_points_remaining < BattleControllerScript.BASIC_ATTACK_ACTION_POINT_COST


func _play_enemy_turn() -> void:
	_set_enemy_turn_in_progress(true)
	status.text = tr("battle.status.enemy_turn")
	var steps: Array = grid.run_enemy_turn()
	for step in steps:
		grid._draw_units()
		grid._update_highlights()
		status.text = _describe_step(step)
		if step.type == "attack":
			_log_attack(step)
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
		action_points_label.text = ""
		hint.text = tr("battle.hint.select_unit") % side_name
	else:
		action_points_label.text = tr("battle.action_points") % [
			selected_unit.action_points_remaining, selected_unit.max_action_points,
		]
		hint.text = (
			tr("battle.hint.turn_complete") % side_name
			if selected_unit.action_points_remaining <= 0
			else tr("battle.hint.select_destination") % side_name
		)

	round_label.text = tr("battle.round") % round_number
	end_turn_button.tooltip_text = tr("battle.end_turn.reminder")
	_update_health_labels()
	portrait_panel.refresh()
	_refresh_item_actions()
	_update_action_bar()
	if not grid.last_targeting_failure.is_empty():
		status.text = _describe_targeting_failure(grid.last_targeting_failure)
	elif not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)
		if grid.last_attack_result.type == "attack":
			_log_attack(grid.last_attack_result)

	if grid.is_battle_won():
		_resolve_battle(true)


func _on_unit_focus_changed(unit) -> void:
	unit_info_panel.show_unit(unit)


func _refresh_item_actions() -> void:
	potion_option.clear()
	transfer_item_option.clear()
	recipient_option.clear()
	var selected_unit = grid.selected_unit
	var can_act: bool = selected_unit != null and selected_unit.side == BattleControllerScript.Side.PLAYER and selected_unit.is_alive()
	if can_act:
		for item_id in GameSession.get_carried_item_ids(selected_unit.adventurer_id):
			var item: Dictionary = GameSession.get_item_definition(item_id)
			if str(item.get("slot", "")) == "potion":
				potion_option.add_item(tr(item.name_key))
				potion_option.set_item_metadata(potion_option.item_count - 1, item_id)
			if str(item.get("slot", "")) == "potion" or GameSession.get_adventurer(selected_unit.adventurer_id).equipment.get(str(item.get("slot", "")), "") != item_id:
				transfer_item_option.add_item(tr(item.name_key))
				transfer_item_option.set_item_metadata(transfer_item_option.item_count - 1, item_id)
		for unit in grid.units:
			if unit != selected_unit and unit.side == BattleControllerScript.Side.PLAYER and unit.is_alive():
				recipient_option.add_item(unit.display_name)
				recipient_option.set_item_metadata(recipient_option.item_count - 1, unit.adventurer_id)
	potion_option.visible = potion_option.item_count > 0
	use_potion_button.visible = potion_option.visible
	use_potion_button.disabled = not can_act or selected_unit.action_points_remaining < 2 or selected_unit.health >= selected_unit.max_health
	transfer_item_option.visible = transfer_item_option.item_count > 0
	recipient_option.visible = recipient_option.item_count > 0
	transfer_button.visible = transfer_item_option.visible and recipient_option.visible
	transfer_button.disabled = not can_act or selected_unit.action_points_remaining < 2


func _on_use_potion_pressed() -> void:
	if potion_option.item_count == 0:
		return
	if grid.try_use_selected_potion(str(potion_option.get_selected_metadata())):
		_on_board_changed()


func _on_transfer_button_pressed() -> void:
	if transfer_item_option.item_count == 0 or recipient_option.item_count == 0:
		return
	if grid.try_transfer_selected_item(
		str(transfer_item_option.get_selected_metadata()), str(recipient_option.get_selected_metadata())
	):
		_on_board_changed()


func _resolve_battle(victory: bool) -> void:
	_show_battle_result(victory)
	await get_tree().create_timer(enemy_turn_beat_seconds).timeout
	_apply_battle_outcome(victory)


func _show_battle_result(victory: bool) -> void:
	_battle_resolved = true
	_set_enemy_turn_in_progress(true)
	status.text = _victory_message() if victory else tr("battle.result.defeat")


func _victory_message() -> String:
	# Captured before _finish_victory() clears selected_encounter.
	var expedition := _current_expedition()
	return tr("battle.result.victory") % tr(expedition.name_key)


## Scene-isolated tests instantiate the battlefield with no selected
## encounter; fall back to the Goblin Camp, matching
## BattleController._get_enemy_stats()'s fallback.
func _current_expedition() -> Dictionary:
	var encounter_id: String = GameSession.selected_encounter
	if encounter_id == "":
		encounter_id = GameSession.GOBLIN_CAMP_ID
	return GameSession.get_expedition(encounter_id)


func _apply_battle_outcome(victory: bool) -> void:
	if victory:
		# Clear XP only on victory, and only while selected_encounter (read by
		# _current_expedition()) is still set — _finish_victory() clears it
		# right after via GameSession.complete_current_encounter().
		_award_clear_xp()
		# _award_clear_xp() may have just queued a level-up (on top of any
		# still-showing kill-triggered one): the summary-screen transition
		# must wait for the whole queue to resolve first.
		if _level_up_active:
			_pending_victory_completion = true
			return
		_finish_victory()
	else:
		_persist_battle_aftermath()
		GameManager.fail_battle()


## Called once per real kill via BattleController's enemy_defeated signal,
## which passes the defeated Unit. Guarded by _kill_xp_awarded_units (keyed
## on that unit's identity) so a repeated event for the same kill cannot
## award it twice, while a battle with multiple enemies still awards kill XP
## for every one of them.
func _award_kill_xp(unit) -> void:
	if _kill_xp_awarded_units.has(unit):
		return
	_kill_xp_awarded_units.append(unit)
	_kills_by_type[unit.enemy_type_name] = _kills_by_type.get(unit.enemy_type_name, 0) + 1
	_award_party_xp(unit.kill_xp)


## Guarded by _clear_xp_awarded so a repeated call (e.g. a repeated
## result-timer fire) cannot award it twice. Gold's own pending-reward flow
## is untouched; this only concerns XP.
func _award_clear_xp() -> void:
	if _clear_xp_awarded:
		return
	_clear_xp_awarded = true
	_award_party_xp(_current_expedition().get("clear_xp", 0))


func _award_party_xp(amount: float) -> void:
	if amount <= 0:
		return
	_total_xp_awarded += amount
	# Captured before GameSession.award_party_xp() mutates anything, so each
	# leveled member's health-gain can be shown later even though GameSession
	# already applies the increase as part of this same call.
	var health_before: Dictionary = {}
	for member_id in GameSession.get_party(GameSession.selected_party_id).get("member_ids", []):
		health_before[member_id] = GameSession.get_effective_max_health(member_id)

	var leveled_up: Array[String] = GameSession.award_party_xp(GameSession.selected_party_id, amount)
	for adventurer_id in leveled_up:
		_refresh_unit_health(adventurer_id)
		_queue_level_up(adventurer_id, health_before.get(adventurer_id, 0))
		if not _leveled_up_ids.has(adventurer_id):
			_leveled_up_ids.append(adventurer_id)


## Applies a mid-battle level-up's health increase to the matching on-field
## unit immediately (design doc: "It applies the health increase to both the
## persistent adventurer and the active unit").
func _refresh_unit_health(adventurer_id: String) -> void:
	for unit in grid.units:
		if unit.adventurer_id != adventurer_id:
			continue
		var new_max_health: int = GameSession.get_effective_max_health(adventurer_id)
		var health_gain: int = new_max_health - unit.max_health
		unit.max_health = new_max_health
		unit.health += health_gain


## Appends to the level-up queue and starts showing it immediately if nothing
## is currently showing. Multiple leveled party members are always shown one
## at a time, in the stable order GameSession.award_party_xp() returned them
## (party member order) — never all at once, never out of order.
func _queue_level_up(adventurer_id: String, adventurer_health_before: int) -> void:
	_level_up_queue.append({"id": adventurer_id, "health_before": adventurer_health_before})
	if not _level_up_active:
		_show_next_level_up()


func _show_next_level_up() -> void:
	if _level_up_queue.is_empty():
		_set_level_up_in_progress(false)
		_on_level_up_queue_drained()
		return
	_set_level_up_in_progress(true)
	var entry: Dictionary = _level_up_queue.pop_front()
	level_up.show_for_adventurer(entry.id, entry.health_before)


func _on_level_up_resolved() -> void:
	_show_next_level_up()


## Only fires once the whole queue is empty (not merely once the current
## modal closes), so a victory whose clear XP queued a level-up still waits
## for every queued member before completing the battle.
func _on_level_up_queue_drained() -> void:
	if not _pending_victory_completion:
		return
	_pending_victory_completion = false
	_finish_victory()


## Rolls this battle's loot into GameSession's battle_* store (see
## GameSession.complete_current_encounter() -> _roll_and_queue_loot()) and
## routes to the victory summary screen with everything this battle
## accumulated. The battle store stays separate from the party's own
## pending_* store until the player leaves this summary screen for the
## World Map (see GameManager.go_to_world_map() -> GameSession.merge_
## battle_loot_into_party()) -- including via GameManager.complete_battle()
## (still used by scripts/tools/screenshot_tour.gd to skip straight to the
## World Map), which also routes through go_to_world_map() and so also
## merges correctly.
func _finish_victory() -> void:
	_persist_battle_aftermath()
	GameSession.complete_current_encounter()

	var party := GameSession.get_party(GameSession.selected_party_id)
	var summary := {
		"kills_by_type": _kills_by_type,
		"total_xp": _total_xp_awarded,
		"party_member_count": maxi(party.get("member_ids", []).size(), 1),
		"leveled_up_ids": _leveled_up_ids,
		# Read straight from the battle store -- this battle's own loot only,
		# never merged into the party's full running totals until the player
		# leaves this screen (see the docstring above).
		"loot_gold": GameSession.battle_reward,
		"loot_mana_crystal_counts": GameSession.battle_mana_crystals.duplicate(),
		"loot_gear_counts": GameSession.battle_gear.duplicate(),
	}
	GameManager.go_to_battle_result(summary)


func _persist_battle_aftermath() -> void:
	var health_by_id: Dictionary = {}
	if grid != null and grid.get("units") != null:
		for unit in grid.units:
			if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
				health_by_id[unit.adventurer_id] = unit.health
	GameSession.apply_battle_aftermath(health_by_id)


func _set_enemy_turn_in_progress(value: bool) -> void:
	_enemy_turn_in_progress = value
	_update_input_lock()


## Board input and the End Turn button stay locked while either the enemy is
## acting or any level-up modal is queued or showing, and unlock only once
## both conditions clear — see _set_enemy_turn_in_progress()/
## _set_level_up_in_progress(), the two flags this combines.
func _set_level_up_in_progress(value: bool) -> void:
	_level_up_active = value
	_update_input_lock()


func _update_input_lock() -> void:
	var locked := _enemy_turn_in_progress or _level_up_active
	end_turn_button.disabled = locked
	grid.input_locked = locked
	_update_action_bar()


func _describe_step(step: Dictionary) -> String:
	if step.get("thorn_triggered", false):
		return tr("battle.status.thorn_trigger") % step.attacker.display_name
	if step.type == "attack":
		var attacker_name: String = tr(SIDE_NAME_KEYS[step.attacker.side])
		if step.hit:
			return tr("battle.status.hit") % [attacker_name, step.damage]
		return tr("battle.status.miss") % attacker_name

	if step.type == "potion":
		return tr("battle.status.potion") % [step.unit.display_name, tr(GameSession.get_item_definition(step.potion_id).name_key), step.healing]
	if step.type == "item_transfer":
		return tr("battle.status.item_transfer") % [step.from.display_name, tr(GameSession.get_item_definition(step.item_id).name_key), step.to.display_name]
	var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
	return tr("battle.status.enemy_move") % mover_name


func _describe_targeting_failure(failure: Dictionary) -> String:
	var reason: String = failure.get("reason", "")
	match reason:
		"out_of_range":
			return tr("battle.feedback.out_of_range")
		"insufficient_ap":
			return tr("battle.feedback.not_enough_ap") % BattleControllerScript.BASIC_ATTACK_ACTION_POINT_COST
		"line_of_sight_blocked":
			return tr("battle.feedback.line_of_sight_blocked")
		"paralyzed":
			var attacker_name: String = failure.attacker.display_name if failure.has("attacker") and failure.attacker != null else tr(SIDE_NAME_KEYS[BattleControllerScript.Side.PLAYER])
			return tr("battle.feedback.paralyzed") % attacker_name
		"move_mode_no_attack":
			return tr("battle.feedback.move_mode")
		"attack_mode_no_target":
			return tr("battle.feedback.attack_mode")
		_:
			return tr("battle.feedback.out_of_range")


func _log_attack(step: Dictionary) -> void:
	if is_same(_last_logged_attack_result, step):
		return
	_last_logged_attack_result = step
	_append_log_line(_describe_log_entry(step))


func _describe_log_entry(step: Dictionary) -> String:
	var attacker_name: String = step.attacker.display_name
	var defender_name: String = step.defender.display_name
	if not step.hit:
		return tr("battle.log.miss") % [attacker_name, defender_name]
	var line: String = tr("battle.log.hit") % [attacker_name, defender_name, step.damage]
	if step.defeated:
		line += " " + tr("battle.log.defeated") % defender_name
	return line


func _append_log_line(text: String) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	log_list.add_child(label)
	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _update_health_labels() -> void:
	# remove_child() (not just queue_free()) so a synchronous re-call (e.g.
	# a test calling this twice back-to-back with no frame in between, or
	# two board_changed events firing in the same frame) never counts stale
	# labels still parented under enemy_health — queue_free() alone only
	# detaches at end of frame.
	for child in enemy_health.get_children():
		enemy_health.remove_child(child)
		child.queue_free()
	for unit in grid.units:
		if unit.side != BattleControllerScript.Side.ENEMY:
			continue
		var label := Label.new()
		label.text = tr("battle.status.health") % [tr("battle.side.enemy"), unit.health, unit.max_health]
		enemy_health.add_child(label)
