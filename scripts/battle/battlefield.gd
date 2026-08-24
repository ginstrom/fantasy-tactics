extends Node2D

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const SIDE_NAME_KEYS := {0: "battle.side.player", 1: "battle.side.enemy"}
const ENEMY_TURN_BEAT_SECONDS := 0.5
## GameSession.CAMPAIGN_OBJECTIVES' final-boss node id (see encampment.gd's
## own CAMPAIGN_OBJECTIVES dict for the same literal) -- no dedicated
## GameSession constant exists for it (unlike GOBLIN_CAMP_ID/ORC_OUTPOST_ID/
## RUINED_FORTRESS_ID), so it is named here the same way encampment.gd
## already references it directly.
const BOSS_ENCOUNTER_ID := "obj_boss_borderlands_ogre"

@onready var hint: Label = %Hint
@onready var status: Label = %Status
@onready var enemy_health: VBoxContainer = %EnemyHealth
@onready var log_list: VBoxContainer = %Log
@onready var log_scroll: ScrollContainer = $HUD/Margin/VBox/BottomPanel/BottomContent/ScrollRow/LogScroll
@onready var battle_title_label: Label = %BattleTitleLabel
@onready var round_label: Label = %RoundLabel
@onready var action_points_label: Label = %ActionPointsLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var retreat_button: Button = %RetreatButton
@onready var move_button: Button = %MoveButton
@onready var attack_button: Button = %AttackButton
@onready var shield_bash_button: Button = %ShieldBashButton
@onready var called_shot_button: Button = %CalledShotButton
@onready var heal_button: Button = %HealButton
@onready var bless_button: Button = %BlessButton
@onready var sleep_button: Button = %SleepButton
@onready var fire_bolt_button: Button = %FireBoltButton
@onready var temporary_guard_button: Button = %TemporaryGuardButton
@onready var mp_label: Label = %MPLabel
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
# Stage 5 D2: dedup guard for Attack-of-Opportunity log lines, mirroring
# _last_logged_attack_result's own is_same()-based pattern -- a reaction is a
# side effect of a move (see grid.last_reaction_results), not the move's own
# primary result, so it needs its own dedup list rather than sharing that var.
var _logged_reaction_results: Array = []
# Stage 5 D4: dedup guard for Chain Blow's own log line, same is_same()-based
# pattern as _last_logged_attack_result -- Chain Blow's bonus second strike
# (see grid.last_chain_blow_result) is a side effect of the primary attack,
# not the primary result itself, so it needs its own var rather than sharing
# _last_logged_attack_result (which would suppress the primary strike's own
# log line the moment both share one Dictionary reference by coincidence).
var _last_logged_chain_blow_result: Dictionary = {}


func _ready() -> void:
	# The encounter never changes over a battle's lifetime, so the header
	# title is computed once here rather than kept in sync every board_
	# changed event (unlike round_label/action_points_label, which do change
	# every turn -- see _on_board_changed()).
	battle_title_label.text = tr("battle.title") % tr(_current_expedition().name_key)
	AudioManager.play_music(_battle_music_track_id())
	grid.enemy_defeated.connect(_award_kill_xp)
	grid.unit_focus_changed.connect(_on_unit_focus_changed)
	grid.action_mode_changed.connect(_on_action_mode_changed)
	grid.retreat_resolved.connect(_on_retreat_resolved)
	level_up.resolved.connect(_on_level_up_resolved)
	portrait_panel.grid = grid
	unit_info_panel.grid = grid
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


func _on_retreat_button_pressed() -> void:
	if _enemy_turn_in_progress or _battle_resolved:
		return
	grid.try_retreat()


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


## Stage 5 D4 (Knight specialization): identical shape to _on_attack_button_
## pressed() above, just its own ActionMode -- try_shield_bash_selected_
## unit() (not this handler) is what actually rejects a non-Knight.
func _on_shield_bash_button_pressed() -> void:
	grid.set_action_mode(BattleControllerScript.ActionMode.SHIELD_BASH)
	_on_action_mode_changed(grid.action_mode)


## Stage 5 D4 (Archer specialization): identical shape to _on_shield_bash_
## button_pressed() above, just its own ActionMode -- try_called_shot_
## selected_unit() (not this handler) is what actually rejects a non-Archer.
func _on_called_shot_button_pressed() -> void:
	grid.set_action_mode(BattleControllerScript.ActionMode.CALLED_SHOT)
	_on_action_mode_changed(grid.action_mode)


## Heal/Bless/Sleep all share the same begin_spell_targeting() entry point
## (see BattleController's own doc comment) -- only pending_spell_id differs.
func _on_heal_button_pressed() -> void:
	grid.begin_spell_targeting("heal")
	_on_action_mode_changed(grid.action_mode)


func _on_bless_button_pressed() -> void:
	grid.begin_spell_targeting("bless")
	_on_action_mode_changed(grid.action_mode)


## Stage 5 D3: Sleep's own action-bar entry point, identical shape to Heal/
## Bless above -- try_cast_spell()'s own "sleep" targeting branch is what
## actually restricts the next click to an enemy tile, not this handler.
func _on_sleep_button_pressed() -> void:
	grid.begin_spell_targeting("sleep")
	_on_action_mode_changed(grid.action_mode)


## Stage 5 D4 (Battle Mage specialization): Fire Bolt's own action-bar entry
## point, identical shape to Sleep above (an enemy-only spell) -- try_cast_
## spell()'s own "fire_bolt" targeting branch is what actually restricts the
## next click to an enemy tile, not this handler.
func _on_fire_bolt_button_pressed() -> void:
	grid.begin_spell_targeting("fire_bolt")
	_on_action_mode_changed(grid.action_mode)


## Stage 5 D4 (Battle Mage specialization): Temporary Guard's own action-bar
## entry point -- unlike every other spell/perk button above, it is SELF-CAST
## ONLY (see try_temporary_guard_selected_unit()'s own doc comment): no
## targeting mode, no tile click, just an immediate call mirroring _on_use_
## potion_pressed()'s identical "call try_*, refresh on success" shape.
func _on_temporary_guard_button_pressed() -> void:
	if grid.try_temporary_guard_selected_unit():
		_on_board_changed()


## Only the active-mode highlight lives here -- disabled state is driven
## separately by _update_action_bar(), since it depends on the selected
## unit's AP and the input lock, neither of which action_mode_changed alone
## reflects.
func _on_action_mode_changed(mode: int) -> void:
	move_button.button_pressed = mode == BattleControllerScript.ActionMode.MOVE
	attack_button.button_pressed = mode == BattleControllerScript.ActionMode.ATTACK
	shield_bash_button.button_pressed = mode == BattleControllerScript.ActionMode.SHIELD_BASH
	called_shot_button.button_pressed = mode == BattleControllerScript.ActionMode.CALLED_SHOT
	var spell_mode: bool = mode == BattleControllerScript.ActionMode.SPELL
	heal_button.button_pressed = spell_mode and grid.pending_spell_id == "heal"
	bless_button.button_pressed = spell_mode and grid.pending_spell_id == "bless"
	sleep_button.button_pressed = spell_mode and grid.pending_spell_id == "sleep"
	fire_bolt_button.button_pressed = spell_mode and grid.pending_spell_id == "fire_bolt"


## Move requires at least one AP (its own cost); Attack requires enough AP
## for a basic attack -- so on low AP, Move can stay enabled while Attack
## disables first (Attack's cost is strictly higher). Both disable while
## input is locked (enemy turn / a queued level-up), matching End Turn.
## Heal/Bless/Sleep (plus the MP readout) show only for a unit that actually
## knows spells at all (Cleric/Mage today, see unit.gd's spells field) --
## every other class keeps its default empty spells array, so this stays
## hidden for them. Stage 5 D3 fix: each button additionally checks its OWN
## spell id is in that unit's spells list -- previously every caster-class
## button showed for ANY caster (a Mage, whose spells == ["sleep"], would
## have shown Cleric's Heal/Bless too), which would have let a Mage cast a
## spell it doesn't know the instant this button existed.
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

	# Shield Bash (Stage 5 D4): shown only for a unit that actually owns the
	# knight_shield_bash perk -- every other unit (including an unpromoted
	# Warrior) keeps this button hidden entirely, the same "don't offer an
	# action this unit doesn't own" rule Heal/Bless/Sleep already follow
	# below for spells.
	var has_shield_bash: bool = selected_unit != null and selected_unit.perks.has(GameSession.KNIGHT_SHIELD_BASH_PERK_ID)
	shield_bash_button.visible = has_shield_bash
	if has_shield_bash:
		shield_bash_button.disabled = (
			not can_act or selected_unit.action_points_remaining < BattleControllerScript.BASIC_ATTACK_ACTION_POINT_COST
		)

	# Called Shot (Stage 5 D4): shown only for a unit that actually owns the
	# archer_called_shot perk -- mirrors Shield Bash's identical "don't offer
	# an action this unit doesn't own" rule immediately above.
	var has_called_shot: bool = selected_unit != null and selected_unit.perks.has(GameSession.ARCHER_CALLED_SHOT_PERK_ID)
	called_shot_button.visible = has_called_shot
	if has_called_shot:
		called_shot_button.disabled = (
			not can_act or selected_unit.action_points_remaining < BattleControllerScript.BASIC_ATTACK_ACTION_POINT_COST
		)

	# Temporary Guard (Stage 5 D4, Battle Mage specialization): shown only for
	# a unit that actually owns the battle_mage_temporary_guard perk, same
	# "don't offer an action this unit doesn't own" rule as Shield Bash/Called
	# Shot above -- but AP/MP costed like a spell cast (see try_temporary_
	# guard_selected_unit()'s own doc comment), not the flat melee attack cost
	# those two use, and additionally disabled while the buff is already
	# active (re-casting would waste AP/MP for no further effect).
	var has_temporary_guard: bool = (
		selected_unit != null and selected_unit.perks.has(GameSession.BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID)
	)
	temporary_guard_button.visible = has_temporary_guard
	if has_temporary_guard:
		temporary_guard_button.disabled = (
			not can_act
			or selected_unit.action_points_remaining < BattleControllerScript.SPELL_ACTION_POINT_COST
			or selected_unit.mp_remaining < BattleControllerScript.SPELL_MP_COST
			or grid.has_status(selected_unit, BattleControllerScript.TEMPORARY_GUARD_STATUS_ID)
		)

	var is_caster: bool = selected_unit != null and not selected_unit.spells.is_empty()
	var knows_heal: bool = is_caster and selected_unit.spells.has("heal")
	var knows_bless: bool = is_caster and selected_unit.spells.has("bless")
	var knows_sleep: bool = is_caster and selected_unit.spells.has("sleep")
	# Fire Bolt (Stage 5 D4, Battle Mage specialization): same "each button
	# additionally checks its OWN spell id" rule Sleep's own Stage 5 D3 fix
	# introduced (see this block's own doc comment on knows_sleep) -- a
	# Battle Mage's spells == ["sleep", "fire_bolt"] shows both dedicated
	# buttons, never a generic "cast any known spell" picker.
	var knows_fire_bolt: bool = is_caster and selected_unit.spells.has("fire_bolt")
	heal_button.visible = knows_heal
	bless_button.visible = knows_bless
	sleep_button.visible = knows_sleep
	fire_bolt_button.visible = knows_fire_bolt
	mp_label.visible = is_caster
	if is_caster:
		mp_label.text = tr("battle.mp") % [selected_unit.mp_remaining, selected_unit.mp_max]
		var can_cast: bool = (
			can_act
			and selected_unit.action_points_remaining >= BattleControllerScript.SPELL_ACTION_POINT_COST
			and selected_unit.mp_remaining >= BattleControllerScript.SPELL_MP_COST
		)
		heal_button.disabled = not can_cast
		bless_button.disabled = not can_cast
		sleep_button.disabled = not can_cast
		fire_bolt_button.disabled = not can_cast


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
	_log_reactions()
	_log_chain_blow()
	# AP spent on a move/attack (and any resulting damage) reaches here via
	# board_changed even though the focused unit itself hasn't changed, so the
	# dual hover/selected panel must resync here too, not only from
	# _on_unit_focus_changed().
	unit_info_panel.update_panel(grid.hovered_unit, grid.selected_unit)
	portrait_panel.refresh()
	_refresh_item_actions()
	_update_action_bar()
	if not grid.last_targeting_failure.is_empty():
		status.text = _describe_targeting_failure(grid.last_targeting_failure)
	elif not grid.last_attack_result.is_empty():
		status.text = _describe_step(grid.last_attack_result)
		if grid.last_attack_result.type == "attack":
			_log_attack(grid.last_attack_result)
		elif grid.last_attack_result.type == "spell":
			_log_spell(grid.last_attack_result)
		elif grid.last_attack_result.type == "perk":
			_log_perk(grid.last_attack_result)

	if grid.is_battle_won():
		_resolve_battle(true)


## The signal still carries get_focused_unit()'s result (see battle_
## controller.gd's unit_focus_changed doc comment), but the dual panel needs
## both grid.hovered_unit and grid.selected_unit directly rather than that
## single collapsed value -- so the argument itself goes unused here.
func _on_unit_focus_changed(_unit) -> void:
	unit_info_panel.update_panel(grid.hovered_unit, grid.selected_unit)


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


## BattleController.try_retreat()'s exit signal. Retreat is a third battle
## outcome alongside win/loss (see _resolve_battle()) rather than a variant
## of either: it logs each unit's distance-based result, persists aftermath
## the same way a win or loss does (unit permadeath + surviving HP), then
## hands routing off to GameManager.retreat_from_battle(), which alone
## decides World Map vs. Encampment (see its own doc comment).
func _on_retreat_resolved(results: Array) -> void:
	if _battle_resolved:
		return
	_battle_resolved = true
	_set_enemy_turn_in_progress(true)
	status.text = tr("battle.result.retreat")
	for result in results:
		_append_log_line(_describe_retreat_result(result))
	await get_tree().create_timer(enemy_turn_beat_seconds).timeout
	_persist_battle_aftermath()
	GameManager.retreat_from_battle()


func _describe_retreat_result(result: Dictionary) -> String:
	var unit_name: String = result.unit.display_name
	match String(result.get("outcome", "")):
		"death":
			return tr("battle.log.retreat.death") % unit_name
		"no_loss":
			return tr("battle.log.retreat.no_loss") % unit_name
		_:
			return tr("battle.log.retreat.hp_loss") % [unit_name, int(result.get("hp_loss", 0))]


func _resolve_battle(victory: bool) -> void:
	_show_battle_result(victory)
	await get_tree().create_timer(enemy_turn_beat_seconds).timeout
	_apply_battle_outcome(victory)


func _show_battle_result(victory: bool) -> void:
	_battle_resolved = true
	_set_enemy_turn_in_progress(true)
	status.text = _victory_message() if victory else tr("battle.result.defeat")
	AudioManager.play_music("music_victory" if victory else "music_defeat")


func _victory_message() -> String:
	# Captured before _finish_victory() clears selected_encounter.
	var expedition := _current_expedition()
	return tr("battle.result.victory") % tr(expedition.name_key)


## Scene-isolated tests instantiate the battlefield with no selected
## encounter; fall back to the Goblin Camp, matching
## BattleController._get_expedition_for_battle()'s fallback.
func _current_expedition() -> Dictionary:
	var encounter_id: String = GameSession.selected_encounter
	if encounter_id == "":
		encounter_id = GameSession.GOBLIN_CAMP_ID
	return GameSession.get_expedition(encounter_id)


## The Ogre boss fight gets its own climactic loop; every other battle uses
## the shared tactical-combat track. Reads GameSession.selected_encounter
## directly (not _current_expedition(), which resolves through get_expedition()
## and loses the raw id) with the same empty-selection fallback as
## _current_expedition() above.
func _battle_music_track_id() -> String:
	var encounter_id: String = GameSession.selected_encounter
	if encounter_id == "":
		encounter_id = GameSession.GOBLIN_CAMP_ID
	return "music_boss" if encounter_id == BOSS_ENCOUNTER_ID else "music_battle"


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
##
## Defeating the final boss is the one victory that does NOT land on the
## ordinary battle-result summary: complete_current_encounter() completing
## the boss's own authored objective flips GameSession.is_campaign_completed
## true (see complete_campaign_objective()/set_campaign_victory()) --
## detected here by diffing the flag around that call, rather than this
## scene hardcoding the boss's encounter id -- and routes to the dedicated
## Campaign Victory screen instead.
func _finish_victory() -> void:
	_persist_battle_aftermath()
	var was_campaign_completed := GameSession.is_campaign_completed
	GameSession.complete_current_encounter()
	var just_won_campaign: bool = GameSession.is_campaign_completed and not was_campaign_completed

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
	if just_won_campaign:
		GameManager.go_to_victory_screen()
		return
	GameManager.go_to_battle_result(summary)


## Permadeath resolves before the health write-back, not after: resolve_
## battle_deaths() removes any adventurer id whose reported health is at or
## below 0 from the roster entirely, so apply_battle_aftermath()'s own
## floor-of-one clamp (see its doc comment) never gets a chance to write a
## dead id back to 1 HP -- it simply no-ops for an id that no longer exists.
func _persist_battle_aftermath() -> void:
	var health_by_id: Dictionary = {}
	var mp_by_id: Dictionary = {}
	if grid != null and grid.get("units") != null:
		for unit in grid.units:
			if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
				health_by_id[unit.adventurer_id] = unit.health
				# MP write-back (docs/designs/campaign-loop.md's "battle
				# aftermath writes the surviving Cleric's remaining MP back"):
				# only a caster (mp_max > 0) ever has a durable MP record to
				# write, so a Warrior/Scout's always-zero mp_max keeps it out
				# of this batch entirely rather than writing a spurious 0.
				if unit.mp_max > 0:
					mp_by_id[unit.adventurer_id] = unit.mp_remaining
		# A player unit defeated in real combat (as opposed to a unit whose
		# health a test set directly, or one that survived to battle's end at
		# low HP) is erased from grid.units well before this point -- see
		# BattleController.defeated_player_health_by_id's own doc comment for
		# why its 0 HP must be merged in from there instead. It never
		# contributes to mp_by_id: it is already excluded from grid.units, so
		# apply_battle_mp_aftermath() would have nothing to write for it even
		# if it were a Cleric -- resolve_battle_deaths() below erases the
		# record first, and a dead adventurer owns no persisted MP record.
		for adventurer_id in grid.get("defeated_player_health_by_id"):
			health_by_id[adventurer_id] = grid.defeated_player_health_by_id[adventurer_id]
	GameSession.resolve_battle_deaths(health_by_id)
	GameSession.apply_battle_aftermath(health_by_id)
	GameSession.apply_battle_mp_aftermath(mp_by_id)


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
	retreat_button.disabled = locked
	grid.input_locked = locked
	_update_action_bar()


func _describe_step(step: Dictionary) -> String:
	if step.get("thorn_triggered", false):
		return tr("battle.status.thorn_trigger") % step.attacker.display_name
	if step.type == "attack":
		var attacker_name: String = tr(SIDE_NAME_KEYS[step.attacker.side])
		var line: String
		if step.hit:
			line = (
				tr("battle.status.critical_hit") % [attacker_name, step.damage] if step.get("critical", false)
				else tr("battle.status.hit") % [attacker_name, step.damage]
			)
			# Shield Bash (Stage 5 D4): a landed hit that also off-balanced the
			# target gets its own distinct clause, never colour-only feedback
			# (Stage 4's accessibility carryover) -- see BattleController.
			# _execute_direct_attack()'s "off_balance_applied" field.
			if step.get("off_balance_applied", false):
				line += " " + tr("battle.status.off_balance_applied") % tr(SIDE_NAME_KEYS[step.defender.side])
		# Dodge/Parry (Stage 5 D2) are a distinct outcome from a plain
		# Guard-driven miss -- distinct text, never colour-only feedback
		# (Stage 4's accessibility carryover).
		elif step.get("dodged", false):
			line = tr("battle.status.dodged") % tr(SIDE_NAME_KEYS[step.defender.side])
		elif step.get("parried", false):
			line = tr("battle.status.parried") % tr(SIDE_NAME_KEYS[step.defender.side])
		else:
			line = tr("battle.status.miss") % attacker_name
		# Called Shot/Lock On (Stage 5 D4, Archer specialization): appended
		# regardless of the roll's own outcome (hit, miss, dodge, or parry) --
		# see BattleController._execute_direct_attack()'s own doc comment on
		# why these are attempt-level facts (the bonus/penalty already factors
		# into the roll above), not hit-only effects like off-balance above.
		if step.get("called_shot", false):
			line += " " + tr("battle.status.called_shot_applied")
		if step.get("lock_on_applied", false):
			line += " " + tr("battle.status.lock_on_applied")
		return line

	if step.type == "potion":
		return tr("battle.status.potion") % [step.unit.display_name, tr(GameSession.get_item_definition(step.potion_id).name_key), step.healing]
	if step.type == "item_transfer":
		return tr("battle.status.item_transfer") % [step.from.display_name, tr(GameSession.get_item_definition(step.item_id).name_key), step.to.display_name]
	if step.type == "spell":
		if step.spell_id == "sleep":
			return _describe_sleep_entry(step, "battle.status.spell_sleep_applied", "battle.status.spell_sleep_resisted")
		if step.spell_id == "fire_bolt":
			return _describe_fire_bolt_entry(step, "battle.status.spell_fire_bolt", "battle.status.spell_fire_bolt_resisted")
		# Paladin's doubled Bless (Stage 5 D4): step.doubled is only ever set
		# true by try_cast_spell()'s "bless" match arm when the CASTER is a
		# promoted Paladin (see BattleController._unit_is_paladin()) -- its own
		# distinct status line, never colour-only feedback (Stage 4's
		# accessibility carryover), so a player can tell the promotion
		# mattered without inspecting the caster's class.
		if step.spell_id == "bless" and step.get("doubled", false):
			return _describe_spell_entry(step, "battle.status.spell_heal", "battle.status.spell_bless_paladin")
		return _describe_spell_entry(step, "battle.status.spell_heal", "battle.status.spell_bless")
	# Temporary Guard (Stage 5 D4, Battle Mage specialization): a perk action,
	# not a spell -- see try_temporary_guard_selected_unit()'s own doc
	# comment on why it carries type "perk" rather than "spell".
	if step.type == "perk":
		return tr("battle.status.temporary_guard_applied") % step.caster.display_name
	var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
	return tr("battle.status.enemy_move") % mover_name


## Shared by _describe_step() (the transient status line) and
## _describe_spell_log_entry() (the persistent combat log) -- only the two
## translation keys differ between the two surfaces.
func _describe_spell_entry(step: Dictionary, heal_key: String, bless_key: String) -> String:
	var caster_name: String = step.caster.display_name
	var target_name: String = step.target.display_name
	if step.spell_id == "heal":
		return tr(heal_key) % [caster_name, target_name, step.healing]
	return tr(bless_key) % [caster_name, target_name]


## Sleep's own log/status line (Stage 5 D3): distinct from _describe_spell_
## entry() above -- Sleep targets an enemy, not an ally, and has no
## "healing" field, and must distinguish an applied cast from a resisted one
## (readable text, never colour-only feedback, per Stage 4's accessibility
## carryover) -- see try_cast_spell()'s "sleep" match arm, which is the only
## place that ever sets step.resisted.
func _describe_sleep_entry(step: Dictionary, applied_key: String, resisted_key: String) -> String:
	var caster_name: String = step.caster.display_name
	var target_name: String = step.target.display_name
	if step.get("resisted", false):
		return tr(resisted_key) % [caster_name, target_name]
	return tr(applied_key) % [caster_name, target_name]


## Fire Bolt's own log/status line (Stage 5 D4, Battle Mage specialization):
## distinct from _describe_sleep_entry() above -- unlike Sleep's binary
## negate, a resisted Fire Bolt still deals (halved) damage, so both the
## landed and resisted variants carry a damage number (see try_cast_spell()'s
## "fire_bolt" match arm, the only place that ever sets step.damage/resisted
## for this spell_id).
func _describe_fire_bolt_entry(step: Dictionary, hit_key: String, resisted_key: String) -> String:
	var caster_name: String = step.caster.display_name
	var target_name: String = step.target.display_name
	var line: String = (
		tr(resisted_key) % [caster_name, target_name, step.damage] if step.get("resisted", false)
		else tr(hit_key) % [caster_name, target_name, step.damage]
	)
	# Unlike Heal/Bless/Sleep, Fire Bolt can kill -- see BattleController.
	# try_cast_spell()'s "fire_bolt" match arm, which is what actually sets
	# step.defeated. Mirrors _describe_log_entry()'s identical "defeated" line
	# for a plain attack.
	if step.get("defeated", false):
		line += " " + tr("battle.log.defeated") % target_name
	return line


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
		"spell_invalid_target":
			return tr("battle.feedback.spell_invalid_target")
		_:
			return tr("battle.feedback.out_of_range")


func _log_attack(step: Dictionary) -> void:
	if is_same(_last_logged_attack_result, step):
		return
	_last_logged_attack_result = step
	_append_log_line(_describe_log_entry(step))


## Combat-log counterpart to _log_attack() -- same dedup guard (shared
## _last_logged_attack_result var; is_same() alone already distinguishes any
## two distinct result Dictionaries regardless of type), a persistent line
## for Heal/Bless casts rather than only the transient status text
## _describe_step() already provides.
## Attacks of Opportunity (Stage 5 D2): logs every reaction the most recent
## move action triggered (see BattleController.last_reaction_results), each
## exactly once. A reaction is a side effect of a move, not the move's own
## primary result -- unlike _log_attack()/_log_spell(), which key off the
## single last_attack_result, this drains a whole array and keeps its own
## dedup list (is_same() per entry) since more than one reaction can follow
## a single move.
func _log_reactions() -> void:
	for reaction in grid.last_reaction_results:
		var already_logged := false
		for logged in _logged_reaction_results:
			if is_same(logged, reaction):
				already_logged = true
				break
		if already_logged:
			continue
		_logged_reaction_results.append(reaction)
		_append_log_line(_describe_reaction_entry(reaction))


func _describe_reaction_entry(reaction: Dictionary) -> String:
	var reactor_name: String = reaction.reactor.display_name
	var mover_name: String = reaction.mover.display_name
	if reaction.get("dodged", false):
		return tr("battle.log.reaction.dodged") % [reactor_name, mover_name, mover_name]
	if reaction.get("parried", false):
		return tr("battle.log.reaction.parried") % [reactor_name, mover_name, mover_name]
	if not reaction.hit:
		return tr("battle.log.reaction.miss") % [reactor_name, mover_name]
	var line: String = (
		tr("battle.log.reaction.critical_hit") % [reactor_name, mover_name, reaction.damage]
		if reaction.get("critical", false)
		else tr("battle.log.reaction.hit") % [reactor_name, mover_name, reaction.damage]
	)
	if reaction.defeated:
		line += " " + tr("battle.log.defeated") % mover_name
	return line


## Chain Blow's own log line (Stage 5 D4), mirroring _log_reactions()'s
## dedup-and-append shape -- a Chain Blow strike is a side effect of the
## primary attack action, not that action's own primary result, so it gets
## its own persistent log line rather than overwriting the primary strike's.
## No status-line treatment (unlike a primary attack): Attacks of Opportunity
## set the same precedent -- see _describe_step()'s own doc comment, which
## never renders a reaction as the transient status text either.
func _log_chain_blow() -> void:
	var result: Dictionary = grid.last_chain_blow_result
	if result.is_empty() or is_same(_last_logged_chain_blow_result, result):
		return
	_last_logged_chain_blow_result = result
	_append_log_line(_describe_chain_blow_entry(result))


func _describe_chain_blow_entry(result: Dictionary) -> String:
	var attacker_name: String = result.attacker.display_name
	var defender_name: String = result.defender.display_name
	if not result.hit:
		if result.get("dodged", false):
			return tr("battle.log.chain_blow.dodged") % [attacker_name, defender_name, defender_name]
		if result.get("parried", false):
			return tr("battle.log.chain_blow.parried") % [attacker_name, defender_name, defender_name]
		return tr("battle.log.chain_blow.miss") % [attacker_name, defender_name]
	var line: String = (
		tr("battle.log.chain_blow.critical_hit") % [attacker_name, defender_name, result.damage]
		if result.get("critical", false)
		else tr("battle.log.chain_blow.hit") % [attacker_name, defender_name, result.damage]
	)
	if result.defeated:
		line += " " + tr("battle.log.defeated") % defender_name
	return line


func _log_spell(step: Dictionary) -> void:
	if is_same(_last_logged_attack_result, step):
		return
	_last_logged_attack_result = step
	if step.spell_id == "sleep":
		_append_log_line(_describe_sleep_entry(step, "battle.log.spell.sleep_applied", "battle.log.spell.sleep_resisted"))
		return
	if step.spell_id == "fire_bolt":
		_append_log_line(_describe_fire_bolt_entry(step, "battle.log.spell.fire_bolt", "battle.log.spell.fire_bolt_resisted"))
		return
	# Paladin's doubled Bless (Stage 5 D4): mirrors _describe_step()'s own
	# identical "doubled" branch above, for the persistent combat log instead
	# of the transient status line.
	if step.spell_id == "bless" and step.get("doubled", false):
		_append_log_line(_describe_spell_entry(step, "battle.log.spell.heal", "battle.log.spell.bless_paladin"))
		return
	_append_log_line(_describe_spell_entry(step, "battle.log.spell.heal", "battle.log.spell.bless"))


## Temporary Guard's own log line (Stage 5 D4, Battle Mage specialization):
## mirrors _log_spell()'s identical dedup-and-append shape (same shared
## _last_logged_attack_result guard -- is_same() alone already distinguishes
## this Dictionary from any prior attack/spell/perk result regardless of
## type), for a perk action rather than a spell cast.
func _log_perk(step: Dictionary) -> void:
	if is_same(_last_logged_attack_result, step):
		return
	_last_logged_attack_result = step
	_append_log_line(tr("battle.log.temporary_guard_applied") % step.caster.display_name)


## Step 3 of docs/plans/2026-08-18-critical-hits-and-flanking: a side or rear
## flank (see battle_controller.gd's get_flank_type()/try_attack_selected_
## unit()) gets its own log line naming the angle of attack, crossed with
## whether it landed a critical hit -- a front attack (the common case) keeps
## the plain hit/critical_hit lines untouched.
func _describe_log_entry(step: Dictionary) -> String:
	var attacker_name: String = step.attacker.display_name
	var defender_name: String = step.defender.display_name
	var line: String
	if not step.hit:
		# Dodge/Parry (Stage 5 D2) get their own log line, distinct from a
		# plain Guard-driven miss -- see last_attack_result's "outcome" field
		# (battle_controller.gd's _outcome_for()), which already distinguishes
		# "blocked"/"dodged"/"parried" the same way this log line does.
		if step.get("dodged", false):
			line = tr("battle.log.dodged") % [attacker_name, defender_name, defender_name]
		elif step.get("parried", false):
			line = tr("battle.log.parried") % [attacker_name, defender_name, defender_name]
		else:
			line = tr("battle.log.miss") % [attacker_name, defender_name]
	else:
		var critical: bool = step.get("critical", false)
		var line_key: String = _log_key_for_flank(String(step.get("flank", "front")), critical)
		line = tr(line_key) % [attacker_name, defender_name, step.damage]
		if step.defeated:
			line += " " + tr("battle.log.defeated") % defender_name
		# Shield Bash (Stage 5 D4): see _describe_step()'s identical clause.
		if step.get("off_balance_applied", false):
			line += " " + tr("battle.log.off_balance_applied") % defender_name
	# Called Shot/Lock On (Stage 5 D4, Archer specialization): appended
	# regardless of the roll's own outcome -- see _describe_step()'s identical
	# clause and BattleController._execute_direct_attack()'s own doc comment.
	if step.get("called_shot", false):
		line += " " + tr("battle.log.called_shot_applied")
	if step.get("lock_on_applied", false):
		line += " " + tr("battle.log.lock_on_applied")
	return line


func _log_key_for_flank(flank: String, critical: bool) -> String:
	match flank:
		"side":
			return "battle.log.flank.side_crit" if critical else "battle.log.flank.side"
		"rear":
			return "battle.log.flank.rear_crit" if critical else "battle.log.flank.rear"
		_:
			return "battle.log.critical_hit" if critical else "battle.log.hit"


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
