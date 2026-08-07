extends Node
## Plays N full battles headlessly with BattleBot controlling the player
## side, appending one JSON line per battle outcome to a log file. See
## docs/plans/2026-08-07-config-and-automation/04-headless-battle-sim-and-logging.md
## for why this has to auto-resolve level-up modals.

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const ENCOUNTER_IDS := [GameSession.GOBLIN_CAMP_ID, GameSession.ORC_OUTPOST_ID]
# Generous headroom over the handful of rounds a normal battle takes,
# so a genuinely stuck bot (e.g. boxed in with no path to the enemy)
# degrades to a "stalemate" result instead of hanging the whole run.
const MAX_ROUNDS := 30
const MAX_SETTLE_FRAMES := 60


func run(runs: int, log_path: String) -> void:
	var log_file := _open_log(log_path)
	if log_file == null:
		push_error("[battle_sim] could not open log file: %s" % log_path)
		get_tree().quit(1)
		return

	for run_index in runs:
		var encounter_id: String = ENCOUNTER_IDS[run_index % ENCOUNTER_IDS.size()]
		var result: Dictionary = await _play_one_battle(encounter_id)
		log_file.store_line(JSON.stringify(result))
		if result.outcome == "stalemate":
			print("[battle_sim] %d/%d %s -> stalemate (did not resolve within %d rounds)" % [run_index + 1, runs, encounter_id, MAX_ROUNDS])
		else:
			print("[battle_sim] %d/%d %s -> %s" % [run_index + 1, runs, encounter_id, result.outcome])
	log_file.close()
	print("[battle_sim] done: %d battles logged to %s" % [runs, log_path])
	get_tree().quit()


## Opens the log for appending, so repeated `make simulate` runs accumulate
## outcome lines instead of each run discarding the previous one's data.
## FileAccess has no append mode: WRITE truncates, and READ_WRITE preserves
## existing content but fails when the file does not exist yet, so the first
## ever run falls back to WRITE.
func _open_log(log_path: String) -> FileAccess:
	var log_file := FileAccess.open(log_path, FileAccess.READ_WRITE)
	if log_file == null:
		log_file = FileAccess.open(log_path, FileAccess.WRITE)
	if log_file != null:
		log_file.seek_end()
	return log_file


func _play_one_battle(encounter_id: String) -> Dictionary:
	DebugScenarios.apply(encounter_id)
	GameSession.enter_encounter(encounter_id)

	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child(battlefield)
	await get_tree().process_frame

	var damage_dealt := 0
	var kills := 0
	var rounds := 0

	while GameSession.selected_encounter != "" and rounds < MAX_ROUNDS:
		rounds += 1
		for step in BattleBot.take_player_turn(battlefield.grid):
			if step.get("type") == "attack":
				damage_dealt += step.damage
				if step.defeated:
					kills += 1
		await _resolve_round(battlefield)

	var outcome := "stalemate"
	if GameSession.selected_encounter == "":
		outcome = "victory" if battlefield.grid.is_battle_won() else "defeat"

	var result := {
		"encounter_id": encounter_id,
		"outcome": outcome,
		"cleared": outcome == "victory",
		"rounds": rounds,
		"damage_dealt": damage_dealt,
		"kills": kills,
		"gold_earned": GameSession.pending_reward,
	}

	battlefield.queue_free()
	await get_tree().process_frame
	return result


## Resolves any level-up modal the bot's turn just queued, ends the turn,
## then waits for Battlefield's own async resolution chain (end_turn ->
## _play_enemy_turn -> _resolve_battle -> _apply_battle_outcome, which can
## itself queue and show more level-ups on a victorious clear) to settle —
## the same fire-and-forget-coroutine pattern documented in
## docs/dev/testing.md, generalized to run every round instead of once.
##
## `_battle_resolved` is part of the settle condition, not just active_side:
## when the bot's killing blow ends the battle, Battlefield detects the win
## inside grid.end_turn() and _play_enemy_turn() still hands the (now empty)
## enemy turn straight back, so active_side is already PLAYER again while
## _resolve_battle() is still suspended on its result timer. Returning on
## active_side alone would spin the caller's round loop without ever yielding
## a frame, so that timer could never fire and every win would be misreported
## as a stalemate.
func _resolve_round(battlefield: Node) -> void:
	_resolve_level_up(battlefield.level_up)
	battlefield._on_end_turn_pressed()

	var frames := 0
	while frames < MAX_SETTLE_FRAMES:
		_resolve_level_up(battlefield.level_up)
		if GameSession.selected_encounter == "":
			return
		if not battlefield._battle_resolved and battlefield.grid.active_side == BattleControllerScript.Side.PLAYER:
			return
		await get_tree().process_frame
		frames += 1


## Drives the level-up modal exactly the way a human would click through
## it: choose the only available perk if one is pending (the same
## ChooseBonusMoveButton handler in scripts/ui/level_up.gd calls), then
## Continue. Repeats for every queued level-up.
func _resolve_level_up(level_up: Control) -> void:
	while level_up.visible:
		if GameSession.is_perk_choice_pending(level_up.adventurer_id):
			GameSession.choose_perk(level_up.adventurer_id, GameSession.BONUS_MOVE_PERK_ID)
		# _on_continue_pressed() refuses to close while a perk choice is still
		# pending, which would spin here forever; bail out instead of hanging
		# if choose_perk() above could not resolve it.
		if GameSession.is_perk_choice_pending(level_up.adventurer_id):
			push_error("[battle_sim] unresolvable perk choice for %s" % level_up.adventurer_id)
			return
		level_up._on_continue_pressed()
