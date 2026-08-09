extends Control

## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is
## deliberately NOT part of that summary dict: GameSession.pending_reward/
## pending_mana_crystals/pending_gear are already live and current by the
## time this scene loads (GameSession.complete_current_encounter() rolled
## them before Battlefield navigated here), so this screen just reads them
## directly, exactly as information_panel.gd's _refresh_carried_loot()
## already does for the World Map.

@onready var kills_label: Label = $Center/VBox/KillsLabel
@onready var xp_label: Label = $Center/VBox/XpLabel
@onready var level_up_label: Label = $Center/VBox/LevelUpLabel
@onready var loot_label: Label = $Center/VBox/LootLabel
@onready var ok_button: Button = $Center/VBox/OkButton


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var summary: Dictionary = GameManager.battle_result_summary
	kills_label.text = _format_kills(summary.get("kills_by_type", {}))

	var total_xp: float = summary.get("total_xp", 0.0)
	var member_count: int = maxi(summary.get("party_member_count", 1), 1)
	var each_xp: float = total_xp / member_count
	xp_label.text = tr("battle_result.xp") % [int(round(total_xp)), int(round(each_xp))]

	var leveled_up_ids: Array = summary.get("leveled_up_ids", [])
	level_up_label.visible = not leveled_up_ids.is_empty()
	if level_up_label.visible:
		var names: Array = []
		for adventurer_id in leveled_up_ids:
			names.append(GameSession.get_adventurer(adventurer_id).get("name", ""))
		level_up_label.text = tr("battle_result.leveled_up") % ", ".join(names)

	loot_label.text = _format_loot()


func _format_kills(kills_by_type: Dictionary) -> String:
	if kills_by_type.is_empty():
		return tr("battle_result.no_kills")
	var parts: Array = []
	for type_name in kills_by_type:
		parts.append("%s x%d" % [type_name, kills_by_type[type_name]])
	return tr("battle_result.kills") % ", ".join(parts)


func _format_loot() -> String:
	var mana_crystal_count := 0
	for tier in GameSession.pending_mana_crystals:
		mana_crystal_count += GameSession.pending_mana_crystals[tier]
	return tr("battle_result.loot") % [GameSession.pending_reward, mana_crystal_count, GameSession.pending_gear.size()]


func _on_ok_pressed() -> void:
	GameManager.battle_result_summary = {}
	GameManager.go_to_world_map()
