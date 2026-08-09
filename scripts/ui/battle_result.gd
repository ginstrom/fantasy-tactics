extends Control

## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot IS part of
## that summary dict ("loot_gold"/"loot_mana_crystals"/"loot_gear"): reading
## GameSession.pending_reward/pending_mana_crystals/pending_gear directly
## would show every encounter a deployed party has cleared so far this
## deployment, not just this battle's own loot, since those fields only
## reset on GameSession.reset()/deposit_pending_reward() -- not per battle.
## _finish_victory() computes a before/after delta around
## GameSession.complete_current_encounter() so this screen shows only what
## this battle actually dropped.

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
	var summary: Dictionary = GameManager.battle_result_summary
	var gold: int = summary.get("loot_gold", 0)
	var mana_crystal_count: int = summary.get("loot_mana_crystals", 0)
	var gear_count: int = summary.get("loot_gear", 0)
	return tr("battle_result.loot") % [gold, mana_crystal_count, gear_count]


func _on_ok_pressed() -> void:
	GameManager.battle_result_summary = {}
	GameManager.go_to_world_map()
